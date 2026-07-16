-- BountyTracker.lua v2.51.3
-- Scrapes Criminality's CUSTOM bounty popup (not Roblox SetCore notifications).
-- Popup looks like: title "Bounty Alert" + body "Nick: $1065" + Close button,
-- with white corner brackets. Lives deep in PlayerGui under obfuscated ScreenGuis.
--
-- Safe scan: depth-limited BFS via GetChildren ONLY.
-- No DescendantAdded, no GetDescendants → avoids namecallInstance / indexEnum kicks.

local BountyTracker = {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local LP = Players.LocalPlayer

local tracked = {}   -- nameLower → { name, display, amount, userId, isLP }
local seenSigs = {}  -- text-signature → true (already processed)
local rows = {}
local ACC = Color3.fromRGB(235, 90, 90)
local dirty = true
local hbConn = nil
local lastPoll = 0
local lastRender = 0

local POLL_INTERVAL = 0.15
local RENDER_INTERVAL = 0.5
local MAX_DEPTH = 14

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

-- Collect TextLabel/TextButton Text from a root and its children (depth-limited).
local function collectTexts(root, maxDepth)
	local out = {}
	local queue = { { root, 0 } }
	local qi = 1
	while qi <= #queue do
		local node, depth = queue[qi][1], queue[qi][2]
		qi = qi + 1
		if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then
			local t = node.Text
			if type(t) == "string" and #t > 0 and t ~= "Close" then
				out[#out + 1] = t
			end
		end
		if depth < maxDepth then
			local ok, kids = pcall(function() return node:GetChildren() end)
			if ok then
				for _, ch in ipairs(kids) do
					queue[#queue + 1] = { ch, depth + 1 }
				end
			end
		end
	end
	return out
end

-- Parse a bag of texts that belong to one popup frame.
local function parsePopupBag(texts)
	if #texts == 0 then return false end
	local joined = table.concat(texts, "\n")
	local low = string.lower(joined)
	local sig = low
	if seenSigs[sig] then return false end

	local isAlert = low:find("bounty alert", 1, true) ~= nil
	local isClaim = low:find("bounty claimed", 1, true) ~= nil
	if not isAlert and not isClaim then return false end

	seenSigs[sig] = true

	if isAlert then
		-- Prefer exact "Name: $1234" lines
		for _, t in ipairs(texts) do
			local name, amt = t:match("^%s*([%w_]+)%s*:%s*%$?([%d,]+)%s*$")
			if name and amt and not string.lower(name):find("bounty") then
				local n = parseAmount(amt)
				if n and n > 0 then
					setBounty(name, n)
					return true
				end
			end
		end
		-- Fallback: anywhere in blob
		local name, amt = joined:match("([%w_]+)%s*:%s*%$?([%d,]+)")
		if name and amt and not string.lower(name):find("bounty") then
			local n = parseAmount(amt)
			if n and n > 0 then
				setBounty(name, n)
				return true
			end
		end
		return false
	end

	-- Claimed → remove from list
	for _, t in ipairs(texts) do
		local name = t:match("([%w_]+)'s%s*%$?[%d,]+%s*bounty%s+was%s+claimed")
			or t:match("([%w_]+)'s%s+bounty%s+was%s+claimed")
		if name then
			clearBounty(name)
			return true
		end
	end
	local name = joined:match("([%w_]+)'s%s*%$?[%d,]+%s*bounty%s+was%s+claimed")
		or joined:match("([%w_]+)'s%s+bounty%s+was%s+claimed")
	if name then
		clearBounty(name)
		return true
	end
	return false
end

-- Walk PlayerGui looking for title labels, then parse their popup parent.
local function scanPlayerGui(pg)
	if not pg then return end

	-- BFS whole PlayerGui (GetChildren only), looking for title TextLabels
	local queue = { { pg, 0 } }
	local qi = 1
	local foundTitles = {}

	while qi <= #queue do
		local node, depth = queue[qi][1], queue[qi][2]
		qi = qi + 1

		if (node:IsA("TextLabel") or node:IsA("TextButton")) then
			local t = node.Text
			if type(t) == "string" then
				local low = string.lower(t)
				if low == "bounty alert" or low == "bounty claimed"
					or low:find("bounty alert", 1, true)
					or low:find("bounty claimed", 1, true) then
					foundTitles[#foundTitles + 1] = node
				end
			end
		end

		if depth < MAX_DEPTH then
			local ok, kids = pcall(function() return node:GetChildren() end)
			if ok then
				for _, ch in ipairs(kids) do
					-- Skip our own Vanguard GUI to save work / avoid self-match
					local n = ch.Name
					if type(n) == "string" and (n:find("^VG_") or n:find("Vanguard")) then
						-- skip
					else
						queue[#queue + 1] = { ch, depth + 1 }
					end
				end
			end
		end
	end

	for _, titleLbl in ipairs(foundTitles) do
		-- Climb a few parents to reach the popup root frame
		local root = titleLbl
		for _ = 1, 6 do
			local p = root.Parent
			if not p or p == pg then break end
			root = p
			-- Prefer a Frame/ScreenGui that also has a "Close" button child somewhere
			if root:IsA("Frame") or root:IsA("ScreenGui") then
				local texts = collectTexts(root, 8)
				if parsePopupBag(texts) then
					break
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
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

	local function mk(name, props)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.ZIndex = 8
		for k, v in pairs(props) do l[k] = v end
		l.Parent = row
		return l
	end

	mk("Rank", {
		Size = UDim2.new(0, 26, 1, 0),
		Position = UDim2.new(0, 6, 0, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(120, 120, 130),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	mk("PName", {
		Size = UDim2.new(1, -140, 1, 0),
		Position = UDim2.new(0, 34, 0, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(220, 220, 228),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})
	mk("Amount", {
		Size = UDim2.new(0, 96, 1, 0),
		Position = UDim2.new(1, -102, 0, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = ACC,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	})

	rows[i] = row
	return row
end

local function render(list, hdr)
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
			and "Brak alertów (czekam na popup gry…)"
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

		if now - lastPoll >= POLL_INTERVAL then
			lastPoll = now
			local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
			if pg then pcall(scanPlayerGui, pg) end
		end

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
