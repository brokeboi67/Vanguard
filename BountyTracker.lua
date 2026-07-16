-- BountyTracker.lua v2.51.2
-- Tracks bounty by periodically polling PlayerGui for Bounty Alert / Bounty Claimed
-- popups. NO DescendantAdded hooks, NO GetDescendants — shallow scan only to avoid
-- triggering the game's namecallInstance/indexEnum AC detectors (Error 267).
--
-- "Bounty Alert"  body: "solo0141: $1078"        → add/update
-- "Bounty Claimed" body: "forevergreater's $579 bounty was claimed." → remove

local BountyTracker = {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local LP = Players.LocalPlayer

-- name(lower) → { name, display, amount, userId, isLP }
local tracked = {}
-- weak set of already-processed TextLabel text blobs (string keys)
local seenSigs = {}
local rows = {}
local ACC = Color3.fromRGB(235, 90, 90)
local dirty = true
local hbConn = nil
local lastPoll = 0
local lastRender = 0
local POLL_INTERVAL = 0.2
local RENDER_INTERVAL = 0.5

local function parseAmount(s)
	if type(s) == "number" then return s end
	if type(s) ~= "string" then return nil end
	local digits = s:gsub("[^%d]", "")
	return #digits > 0 and tonumber(digits) or nil
end

local function fmtMoney(n)
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "$" .. s
end

local function resolvePlayer(rawName)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == rawName:lower()
			or (p.DisplayName and p.DisplayName:lower() == rawName:lower()) then
			return p
		end
	end
	return nil
end

local function setBounty(rawName, amount)
	local p = resolvePlayer(rawName)
	local key = string.lower((p and p.Name) or rawName)
	tracked[key] = {
		name    = (p and p.Name)        or rawName,
		display = (p and p.DisplayName) or rawName,
		amount  = amount,
		userId  = p and p.UserId or nil,
		isLP    = (p == LP),
	}
	dirty = true
end

local function clearBounty(rawName)
	local p = resolvePlayer(rawName)
	local key = string.lower((p and p.Name) or rawName)
	if tracked[key] then
		tracked[key] = nil
		dirty = true
	end
end

-- Try to parse a pair of texts (title + body) as a bounty popup.
-- Returns true if something was done.
local function parseTexts(t1, t2)
	local l1 = type(t1) == "string" and string.lower(t1) or ""
	local l2 = type(t2) == "string" and string.lower(t2) or ""
	local combined = l1 .. "\n" .. l2

	-- Bounty Alert: title has "bounty alert", body has "Name: $1234"
	if combined:find("bounty alert", 1, true) then
		-- body like "solo0141: $1078" or "solo0141: 1078"
		local rawBody = (l1:find("bounty alert") and t2) or t1
		local name, amtStr = tostring(rawBody):match("([%w_]+)%s*:%s*%$?([%d,]+)")
		if name and amtStr then
			local n = parseAmount(amtStr)
			if n and n > 0 then
				setBounty(name, n)
				return true
			end
		end
		-- Try combined blob as fallback
		local name2, amtStr2 = combined:match("([%w_%d]+)%s*:%s*%$?([%d,]+)")
		if name2 and amtStr2 and not name2:find("bounty") then
			local n = parseAmount(amtStr2)
			if n and n > 0 then setBounty(name2, n); return true end
		end
		return false
	end

	-- Bounty Claimed: title has "bounty claimed", body "Name's $X bounty was claimed."
	if combined:find("bounty claimed", 1, true) then
		local rawBody = (l1:find("bounty claimed") and t2) or t1
		local name = tostring(rawBody):match("([%w_%d]+)'s%s*%$?[%d,]+%s*bounty%s+was%s+claimed")
			or tostring(rawBody):match("([%w_%d]+)'s%s+bounty%s+was%s+claimed")
		if not name then
			name = combined:match("([%w_%d]+)'s%s*%$?[%d,]+%s*bounty%s+was%s+claimed")
				or combined:match("([%w_%d]+)'s%s+bounty%s+was%s+claimed")
		end
		if name then
			clearBounty(name)
			return true
		end
		return false
	end

	return false
end

-- Shallow scan: only walk 2 levels into PlayerGui children.
-- PlayerGui → ScreenGui/Frame → children TextLabels
-- This keeps call depth tiny and avoids GetDescendants entirely.
local function shallowScan(pg)
	if not pg then return end
	-- Level 1: direct children of PlayerGui
	for _, child in ipairs(pg:GetChildren()) do
		-- Only inspect GUI containers
		if child:IsA("ScreenGui") or child:IsA("Frame") then
			local childTexts = {}
			-- Level 2: children of that container
			for _, cc in ipairs(child:GetChildren()) do
				if cc:IsA("TextLabel") or cc:IsA("TextButton") or cc:IsA("TextBox") then
					local t = cc.Text
					if type(t) == "string" and #t > 0 then
						childTexts[#childTexts + 1] = t
					end
				elseif cc:IsA("Frame") or cc:IsA("ImageLabel") then
					-- One more level for nested popup frames
					for _, gcc in ipairs(cc:GetChildren()) do
						if gcc:IsA("TextLabel") or gcc:IsA("TextButton") then
							local t = gcc.Text
							if type(t) == "string" and #t > 0 then
								childTexts[#childTexts + 1] = t
							end
						end
					end
				end
			end
			if #childTexts == 0 then continue end
			-- Deduplicate by signature to avoid re-processing
			local sig = table.concat(childTexts, "|")
			if seenSigs[sig] then continue end
			-- Only process if looks relevant (fast string check before full parse)
			local sigL = string.lower(sig)
			if sigL:find("bounty", 1, true) then
				seenSigs[sig] = true
				-- Try all pairs of texts
				for i = 1, #childTexts do
					for j = i, #childTexts do
						if parseTexts(childTexts[i], childTexts[j]) then break end
					end
				end
			end
		end
	end
end

-- ── Rendering ─────────────────────────────────────────────────────────────────

local function ensureRow(list, i)
	if rows[i] and rows[i].Parent == list then return rows[i] end
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	row.BorderSizePixel = 0
	row.LayoutOrder = i
	row.ZIndex = 7
	row.Name = "BountyRow" .. i
	row.Parent = list
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = row

	local rank = Instance.new("TextLabel")
	rank.Name = "Rank"
	rank.Size = UDim2.new(0, 26, 1, 0)
	rank.Position = UDim2.new(0, 6, 0, 0)
	rank.BackgroundTransparency = 1
	rank.Font = Enum.Font.GothamBold
	rank.TextSize = 11
	rank.TextColor3 = Color3.fromRGB(120, 120, 130)
	rank.TextXAlignment = Enum.TextXAlignment.Left
	rank.ZIndex = 8
	rank.Parent = row

	local nameL = Instance.new("TextLabel")
	nameL.Name = "PName"
	nameL.Size = UDim2.new(1, -140, 1, 0)
	nameL.Position = UDim2.new(0, 34, 0, 0)
	nameL.BackgroundTransparency = 1
	nameL.Font = Enum.Font.GothamMedium
	nameL.TextSize = 11
	nameL.TextColor3 = Color3.fromRGB(220, 220, 228)
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	nameL.TextTruncate = Enum.TextTruncate.AtEnd
	nameL.ZIndex = 8
	nameL.Parent = row

	local amt = Instance.new("TextLabel")
	amt.Name = "Amount"
	amt.Size = UDim2.new(0, 96, 1, 0)
	amt.Position = UDim2.new(1, -102, 0, 0)
	amt.BackgroundTransparency = 1
	amt.Font = Enum.Font.GothamBold
	amt.TextSize = 12
	amt.TextColor3 = ACC
	amt.TextXAlignment = Enum.TextXAlignment.Right
	amt.ZIndex = 8
	amt.Parent = row

	rows[i] = row
	return row
end

local function render(list, hdr)
	-- Remove entries for players who have left
	for key, entry in pairs(tracked) do
		if entry.userId then
			local found = false
			for _, p in ipairs(Players:GetPlayers()) do
				if p.UserId == entry.userId then found = true; break end
			end
			if not found then tracked[key] = nil end
		end
	end

	local data = {}
	for _, e in pairs(tracked) do data[#data + 1] = e end
	table.sort(data, function(a, b) return a.amount > b.amount end)

	for i, entry in ipairs(data) do
		local row = ensureRow(list, i)
		row.Visible = true
		row.Rank.Text = "#" .. i
		local disp = entry.display or entry.name
		if entry.name and entry.display and entry.name ~= entry.display then
			disp = disp .. "  (@" .. entry.name .. ")"
		end
		if entry.isLP then
			disp = disp .. "  •"
			row.PName.TextColor3 = Color3.fromRGB(120, 200, 255)
		else
			row.PName.TextColor3 = Color3.fromRGB(220, 220, 228)
		end
		row.PName.Text = disp
		row.Amount.Text = fmtMoney(entry.amount)
	end
	for i = #data + 1, #rows do
		if rows[i] then rows[i].Visible = false end
	end
	if hdr then
		hdr.Text = #data == 0
			and "Brak alertów (czekam na Bounty Alert…)"
			or  string.format("%d aktywnych bounty", #data)
	end
	dirty = false
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function BountyTracker.Init(S)
	if hbConn then return end

	Players.PlayerRemoving:Connect(function(p)
		local key = string.lower(p.Name)
		if tracked[key] then tracked[key] = nil; dirty = true end
	end)

	hbConn = RS.Heartbeat:Connect(function()
		if not S.CrimBountyTracker then return end
		local now = tick()

		-- Poll PlayerGui
		if now - lastPoll >= POLL_INTERVAL then
			lastPoll = now
			local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
			if pg then pcall(shallowScan, pg) end
		end

		-- Render list
		local list = _G.__VG_BountyList
		if not list or not list.Parent then return end
		if dirty or (now - lastRender >= RENDER_INTERVAL) then
			lastRender = now
			pcall(render, list, _G.__VG_BountyHeader)
		end
	end)
end

function BountyTracker.Stop()
	if hbConn then hbConn:Disconnect(); hbConn = nil end
	table.clear(tracked)
	table.clear(seenSigs)
	for _, r in ipairs(rows) do if r then r.Visible = false end end
end

return BountyTracker
