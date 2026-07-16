-- BountyTracker.lua v2.51.1
-- Tracks live bounties by scraping Criminality's own popup UI:
--   "Bounty Alert"   → "solo0141: $1078"          → add / update
--   "Bounty Claimed" → "ethlandIXIX's $563 bounty was claimed." → remove
-- Claimed = no longer active. Renders into _G.__VG_BountyList from the UI tab.

local BountyTracker = {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")

local LP = Players.LocalPlayer

-- nameLower → { name, amount, at }
local tracked = {}
local seenNodes = setmetatable({}, { __mode = "k" })
local rows = {}
local ACC = Color3.fromRGB(235, 90, 90)
local dirty = true
local watchConn = nil
local hbConn = nil
local lastRender = 0

local function parseAmount(v)
	if type(v) == "number" then
		return v
	end
	if type(v) ~= "string" then
		return nil
	end
	local digits = (v:gsub("[^%d]", ""))
	if #digits == 0 then
		return nil
	end
	return tonumber(digits)
end

local function fmtMoney(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "$" .. out
end

local function resolvePlayer(name)
	if type(name) ~= "string" or name == "" then
		return nil, name
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == name:lower() or (p.DisplayName and p.DisplayName:lower() == name:lower()) then
			return p, p.Name
		end
	end
	return nil, name
end

local function setBounty(rawName, amount)
	local p, canon = resolvePlayer(rawName)
	local key = string.lower(canon or rawName)
	tracked[key] = {
		name = (p and p.Name) or canon or rawName,
		display = (p and p.DisplayName) or canon or rawName,
		amount = amount,
		at = tick(),
		userId = p and p.UserId or nil,
		isLP = p == LP,
	}
	dirty = true
end

local function clearBounty(rawName)
	local _, canon = resolvePlayer(rawName)
	local key = string.lower(canon or rawName)
	if tracked[key] then
		tracked[key] = nil
		dirty = true
	end
end

-- Collect all TextLabel / TextButton text under an instance (shallow + deep).
local function collectTexts(root)
	local texts = {}
	local function push(t)
		if type(t) == "string" and t ~= "" then
			texts[#texts + 1] = t
		end
	end
	if root:IsA("TextLabel") or root:IsA("TextButton") then
		push(root.Text)
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			push(d.Text)
		end
	end
	return texts
end

-- Parse one popup's text blob.
-- Alert:  title contains "Bounty Alert", body like "solo0141: $1078"
-- Claim:  title contains "Bounty Claimed", body like "ethlandIXIX's $563 bounty was claimed."
local function parsePopupTexts(texts)
	local joined = table.concat(texts, "\n")
	local lower = string.lower(joined)

	local isAlert = lower:find("bounty alert", 1, true) ~= nil
	local isClaim = lower:find("bounty claimed", 1, true) ~= nil
	if not isAlert and not isClaim then
		return
	end

	-- Alert line: Name: $1234  (or Name: 1234)
	if isAlert then
		for _, t in ipairs(texts) do
			local name, amt = t:match("^%s*([%w_]+)%s*:%s*%$?([%d,]+)%s*$")
			if name and amt then
				local n = parseAmount(amt)
				if n and n > 0 then
					setBounty(name, n)
					return
				end
			end
		end
		-- Fallback across joined blob
		local name, amt = joined:match("([%w_]+)%s*:%s*%$?([%d,]+)")
		if name and amt and not string.lower(name):find("bounty") then
			local n = parseAmount(amt)
			if n and n > 0 then
				setBounty(name, n)
			end
		end
		return
	end

	-- Claimed: Name's $123 bounty was claimed
	if isClaim then
		for _, t in ipairs(texts) do
			local name = t:match("([%w_]+)'s%s*%$?[%d,]+%s*bounty%s+was%s+claimed")
			if not name then
				name = t:match("([%w_]+)'s%s+bounty%s+was%s+claimed")
			end
			if name then
				clearBounty(name)
				return
			end
		end
		local name = joined:match("([%w_]+)'s%s*%$?[%d,]+%s*bounty%s+was%s+claimed")
			or joined:match("([%w_]+)'s%s+bounty%s+was%s+claimed")
		if name then
			clearBounty(name)
		end
	end
end

local function ingestNode(inst)
	if not inst or seenNodes[inst] then
		return
	end
	-- Only care about GUI text containers that might be the popup (or its parent frame)
	local isGui = inst:IsA("GuiObject") or inst:IsA("ScreenGui") or inst:IsA("BillboardGui")
	if not isGui and not inst:IsA("Folder") and not inst:IsA("Frame") then
		return
	end

	-- Defer a frame so all labels inside the popup have Text set
	task.defer(function()
		if not inst or not inst.Parent then
			return
		end
		seenNodes[inst] = true
		local texts = collectTexts(inst)
		if #texts == 0 then
			return
		end
		parsePopupTexts(texts)
	end)
end

local function scanExisting(pg)
	if not pg then
		return
	end
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local t = d.Text
			if type(t) == "string" then
				local low = string.lower(t)
				if low:find("bounty alert", 1, true) or low:find("bounty claimed", 1, true) then
					ingestNode(d.Parent or d)
				elseif t:find(":%s*%$") or t:find("bounty was claimed") then
					ingestNode(d.Parent or d)
				end
			end
		end
	end
end

local function ensureRow(list, i)
	if rows[i] and rows[i].Parent == list then
		return rows[i]
	end
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
	rank.Size = UDim2.new(0, 26, 1, 0)
	rank.Position = UDim2.new(0, 6, 0, 0)
	rank.BackgroundTransparency = 1
	rank.Font = Enum.Font.GothamBold
	rank.TextSize = 11
	rank.TextColor3 = Color3.fromRGB(120, 120, 130)
	rank.TextXAlignment = Enum.TextXAlignment.Left
	rank.ZIndex = 8
	rank.Name = "Rank"
	rank.Parent = row

	local nameL = Instance.new("TextLabel")
	nameL.Size = UDim2.new(1, -140, 1, 0)
	nameL.Position = UDim2.new(0, 34, 0, 0)
	nameL.BackgroundTransparency = 1
	nameL.Font = Enum.Font.GothamMedium
	nameL.TextSize = 11
	nameL.TextColor3 = Color3.fromRGB(220, 220, 228)
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	nameL.TextTruncate = Enum.TextTruncate.AtEnd
	nameL.ZIndex = 8
	nameL.Name = "PName"
	nameL.Parent = row

	local amt = Instance.new("TextLabel")
	amt.Size = UDim2.new(0, 96, 1, 0)
	amt.Position = UDim2.new(1, -102, 0, 0)
	amt.BackgroundTransparency = 1
	amt.Font = Enum.Font.GothamBold
	amt.TextSize = 12
	amt.TextColor3 = ACC
	amt.TextXAlignment = Enum.TextXAlignment.Right
	amt.ZIndex = 8
	amt.Name = "Amount"
	amt.Parent = row

	rows[i] = row
	return row
end

local function render(list, hdr)
	-- Drop entries for players who left
	for key, entry in pairs(tracked) do
		if entry.userId then
			local still = false
			for _, p in ipairs(Players:GetPlayers()) do
				if p.UserId == entry.userId then
					still = true
					break
				end
			end
			if not still then
				tracked[key] = nil
			end
		end
	end

	local data = {}
	for _, entry in pairs(tracked) do
		data[#data + 1] = entry
	end
	table.sort(data, function(a, b)
		return a.amount > b.amount
	end)

	for i, entry in ipairs(data) do
		local row = ensureRow(list, i)
		row.Visible = true
		row.Rank.Text = "#" .. i
		local disp = entry.display or entry.name
		if entry.name and entry.display and entry.name ~= entry.display then
			disp = entry.display .. "  (@" .. entry.name .. ")"
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
		if rows[i] then
			rows[i].Visible = false
		end
	end
	if hdr then
		if #data == 0 then
			hdr.Text = "Brak aktywnych bounty (czekam na Alert…)"
		else
			hdr.Text = string.format("%d aktywnych bounty", #data)
		end
	end
	dirty = false
end

function BountyTracker.Init(S)
	if hbConn then
		return
	end

	local function attachWatch(pg)
		if watchConn then
			watchConn:Disconnect()
			watchConn = nil
		end
		if not pg then
			return
		end
		scanExisting(pg)
		watchConn = pg.DescendantAdded:Connect(function(inst)
			if not S.CrimBountyTracker then
				return
			end
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("Frame") or inst:IsA("ImageLabel") then
				-- Walk up a bit so we get the full popup frame, not a single label
				local root = inst
				for _ = 1, 4 do
					if root.Parent and root.Parent ~= pg then
						root = root.Parent
					else
						break
					end
				end
				ingestNode(root)
				ingestNode(inst)
			end
		end)
	end

	local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
	if pg then
		attachWatch(pg)
	end
	if LP then
		LP.ChildAdded:Connect(function(ch)
			if ch:IsA("PlayerGui") then
				attachWatch(ch)
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(p)
		local key = string.lower(p.Name)
		if tracked[key] then
			tracked[key] = nil
			dirty = true
		end
	end)

	hbConn = RS.Heartbeat:Connect(function()
		if not S.CrimBountyTracker then
			return
		end
		local list = _G.__VG_BountyList
		if not list or not list.Parent then
			return
		end
		local now = tick()
		if dirty or now - lastRender > 1.5 then
			lastRender = now
			pcall(render, list, _G.__VG_BountyHeader)
		end
	end)
end

function BountyTracker.Stop()
	if watchConn then
		watchConn:Disconnect()
		watchConn = nil
	end
	if hbConn then
		hbConn:Disconnect()
		hbConn = nil
	end
	table.clear(tracked)
	for _, r in ipairs(rows) do
		if r then
			r.Visible = false
		end
	end
end

return BountyTracker
