-- BountyTracker.lua v2.52.1
-- Scrapes Criminality's custom bounty popups ("Bounty Alert" / "Bounty Claimed").
--
-- Performance: NEVER BFS the whole PlayerGui on a timer.
-- - ChildAdded on PlayerGui + each top-level ScreenGui (shallow) → scan that tree only
-- - Debounced, node-budgeted BFS (max ~250 nodes)
-- - Fallback poll every 2s only compares child counts (cheap), deep-scans if changed
-- No DescendantAdded / GetDescendants (AC-safe).

local BountyTracker = {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local LP = Players.LocalPlayer

local tracked = {}
local seenSigs = {}
local rows = {}
local ACC = Color3.fromRGB(235, 90, 90)
local dirty = true

local hbConn = nil
local pgConn = nil
local sgConns = {}       -- ScreenGui → RBXScriptConnection
local sgChildCount = {}  -- ScreenGui → last #GetChildren
local pendingScan = {}   -- ScreenGui → true
local scanToken = 0
local lastFallback = 0
local lastRender = 0
local lastSeenPrune = 0

local FALLBACK_INTERVAL = 2.0
local RENDER_INTERVAL = 1.0
local SCAN_DEBOUNCE = 0.25
local MAX_DEPTH = 10
local MAX_NODES = 250
local SEEN_CAP = 80

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

local function isOurs(inst)
	local n = inst.Name
	return type(n) == "string" and (n:find("^VG_") ~= nil or n:find("Vanguard") ~= nil)
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
	local prev = tracked[key]
	if prev and prev.amount == amount then
		return
	end
	tracked[key] = {
		name    = (p and p.Name) or rawName,
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

local function collectTexts(root, maxDepth, budget)
	local out = {}
	local queue = { root }
	local depths = { [root] = 0 }
	local qi = 1
	local nodes = 0
	while qi <= #queue and nodes < budget do
		local node = queue[qi]
		qi += 1
		nodes += 1
		local depth = depths[node] or 0
		if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then
			local t = node.Text
			if type(t) == "string" and #t > 0 and t ~= "Close" then
				out[#out + 1] = t
			end
		end
		if depth < maxDepth then
			local ok, kids = pcall(node.GetChildren, node)
			if ok then
				for _, ch in ipairs(kids) do
					if not isOurs(ch) then
						queue[#queue + 1] = ch
						depths[ch] = depth + 1
					end
				end
			end
		end
	end
	return out
end

local function parsePopupBag(texts)
	if #texts == 0 then return false end
	local joined = table.concat(texts, "\n")
	local low = string.lower(joined)
	if seenSigs[low] then return false end

	local isAlert = low:find("bounty alert", 1, true) ~= nil
	local isClaim = low:find("bounty claimed", 1, true) ~= nil
	if not isAlert and not isClaim then return false end

	seenSigs[low] = true

	if isAlert then
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

-- Scan a SINGLE ScreenGui / Frame root (not entire PlayerGui).
local function scanRoot(root)
	if not root or not root.Parent then return end
	if isOurs(root) then return end

	local texts = collectTexts(root, MAX_DEPTH, MAX_NODES)
	-- Fast reject: no "bounty" substring anywhere
	local hit = false
	for _, t in ipairs(texts) do
		if string.lower(t):find("bounty", 1, true) then
			hit = true
			break
		end
	end
	if not hit then return end

	-- Prefer parsing the whole bag once (popup is usually one ScreenGui)
	if parsePopupBag(texts) then return end

	-- Fallback: find title labels and climb a few parents
	local queue = { root }
	local depths = { [root] = 0 }
	local qi = 1
	local nodes = 0
	while qi <= #queue and nodes < MAX_NODES do
		local node = queue[qi]
		qi += 1
		nodes += 1
		local depth = depths[node] or 0
		if node:IsA("TextLabel") or node:IsA("TextButton") then
			local t = node.Text
			if type(t) == "string" then
				local low = string.lower(t)
				if low:find("bounty alert", 1, true) or low:find("bounty claimed", 1, true) then
					local climb = node
					for _ = 1, 5 do
						local p = climb.Parent
						if not p or p == root.Parent then break end
						climb = p
						if climb:IsA("Frame") or climb:IsA("ScreenGui") then
							if parsePopupBag(collectTexts(climb, 6, 80)) then
								return
							end
						end
					end
				end
			end
		end
		if depth < MAX_DEPTH then
			local ok, kids = pcall(node.GetChildren, node)
			if ok then
				for _, ch in ipairs(kids) do
					if not isOurs(ch) then
						queue[#queue + 1] = ch
						depths[ch] = depth + 1
					end
				end
			end
		end
	end
end

local function scheduleScan(root, S)
	if not S or not S.CrimBountyTracker then return end
	if not root or pendingScan[root] then return end
	pendingScan[root] = true
	scanToken += 1
	local token = scanToken
	task.delay(SCAN_DEBOUNCE, function()
		pendingScan[root] = nil
		if token ~= scanToken and not pendingScan[root] then
			-- still run — token bump only coalesces; latest debounce wins per root
		end
		if not S.CrimBountyTracker then return end
		if root.Parent then
			pcall(scanRoot, root)
		end
	end)
end

local function unwatchScreenGui(sg)
	local c = sgConns[sg]
	if c then
		pcall(function() c:Disconnect() end)
		sgConns[sg] = nil
	end
	sgChildCount[sg] = nil
	pendingScan[sg] = nil
end

local function watchScreenGui(sg, S)
	if not sg or sgConns[sg] or isOurs(sg) then return end
	local ok, n = pcall(function() return #sg:GetChildren() end)
	sgChildCount[sg] = ok and n or 0
	sgConns[sg] = sg.ChildAdded:Connect(function()
		scheduleScan(sg, S)
	end)
	-- One immediate scan in case popup already exists inside
	scheduleScan(sg, S)
end

local function attachPlayerGui(pg, S)
	if pgConn then
		pgConn:Disconnect()
		pgConn = nil
	end
	for sg in pairs(sgConns) do
		unwatchScreenGui(sg)
	end
	if not pg then return end

	for _, ch in ipairs(pg:GetChildren()) do
		if ch:IsA("ScreenGui") or ch:IsA("Folder") or ch:IsA("Frame") then
			watchScreenGui(ch, S)
		end
	end

	pgConn = pg.ChildAdded:Connect(function(ch)
		if not S.CrimBountyTracker then return end
		if ch:IsA("ScreenGui") or ch:IsA("Folder") or ch:IsA("Frame") then
			watchScreenGui(ch, S)
			scheduleScan(ch, S)
		end
	end)

	pg.ChildRemoved:Connect(function(ch)
		unwatchScreenGui(ch)
	end)
end

local function pruneSeen()
	local n = 0
	for _ in pairs(seenSigs) do n += 1 end
	if n <= SEEN_CAP then return end
	table.clear(seenSigs)
end

-- Cheap fallback: if a watched ScreenGui gained/lost children, rescan it.
local function fallbackCheck(S)
	for sg, last in pairs(sgChildCount) do
		if not sg.Parent then
			unwatchScreenGui(sg)
		else
			local ok, n = pcall(function() return #sg:GetChildren() end)
			if ok and n ~= last then
				sgChildCount[sg] = n
				scheduleScan(sg, S)
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
			or string.format("%d aktywnych bounty", #data)
	end
	dirty = false
end

-- ── Init ──────────────────────────────────────────────────────────────────────

local pgAttached = false
local wasOn = false

function BountyTracker.Init(S)
	if hbConn then return end

	Players.PlayerRemoving:Connect(function(p)
		local key = string.lower(p.Name)
		if tracked[key] then tracked[key] = nil; dirty = true end
	end)

	hbConn = RS.Heartbeat:Connect(function()
		local on = S.CrimBountyTracker == true
		if not on then
			if wasOn then
				-- Tear down watchers when toggled off → zero idle cost
				if pgConn then pgConn:Disconnect(); pgConn = nil end
				for sg in pairs(sgConns) do unwatchScreenGui(sg) end
				pgAttached = false
				wasOn = false
			end
			return
		end
		wasOn = true

		local now = tick()
		local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
		if pg and not pgAttached then
			attachPlayerGui(pg, S)
			pgAttached = true
		end

		if now - lastFallback >= FALLBACK_INTERVAL then
			lastFallback = now
			fallbackCheck(S)
			if now - lastSeenPrune > 30 then
				lastSeenPrune = now
				pruneSeen()
			end
		end

		if not dirty then return end
		local list = _G.__VG_BountyList
		if not list or not list.Parent then return end
		if now - lastRender < RENDER_INTERVAL and lastRender > 0 then return end
		lastRender = now
		pcall(render, list, _G.__VG_BountyHeader)
	end)
end

function BountyTracker.Stop()
	if hbConn then hbConn:Disconnect(); hbConn = nil end
	if pgConn then pgConn:Disconnect(); pgConn = nil end
	for sg in pairs(sgConns) do unwatchScreenGui(sg) end
	table.clear(tracked)
	table.clear(seenSigs)
	pgAttached = false
	wasOn = false
	for _, r in ipairs(rows) do if r then r.Visible = false end end
end

return BountyTracker
