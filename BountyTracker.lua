-- BountyTracker.lua v2.52.10
-- Scrapes Criminality's custom bounty popups ("Bounty Alert" / "Bounty Claimed").
-- Fixes:
--   • Display names with spaces/special chars now matched (pattern .-)
--   • Passive $3/s drain simulation after ~8 s combat-tag window
--   • seenSigs keyed on name+amount so new amounts for same player always pass
--   • Popup is often a REUSED/persistent Frame (Visible + Text just get updated,
--     no ChildAdded, no child-count change) → fallback now unconditionally
--     re-scans every watched root every 1s instead of only on child-count diff.
-- Performance: bounded BFS (MAX_NODES/MAX_DEPTH) on already-known roots only,
-- no full-PlayerGui walk.

local BountyTracker = {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local LP = Players.LocalPlayer

-- combat-tag lasts ~8 s after last popup; after that, bounty drains $3/s
local COMBAT_TAG_WINDOW = 8
local DRAIN_PER_SEC     = 3

local tracked       = {}   -- key → { name, display, amount, lastSeenAt, userId, isLP }
local seenSigs      = {}   -- "name_lower:amount" → true  (prevents re-fire same popup)
local rows          = {}
local ACC           = Color3.fromRGB(235, 90, 90)
local ACC_DRAIN     = Color3.fromRGB(180, 120, 60)  -- orange-ish while draining
local dirty         = true

local hbConn        = nil
local pgConn        = nil
local sgConns       = {}      -- ScreenGui → RBXScriptConnection
local sgChildCount  = {}      -- ScreenGui → last #GetChildren
local pendingScan   = {}      -- ScreenGui → true
local scanToken     = 0
local lastFallback  = 0
local lastRender    = 0
local lastSeenPrune = 0

local FALLBACK_INTERVAL = 1.0
local RENDER_INTERVAL   = 0.5   -- refresh display twice/s so drain looks smooth
local SCAN_DEBOUNCE     = 0.20
local MAX_DEPTH         = 12
local MAX_NODES         = 300
local SEEN_CAP          = 120

-- ── Helpers ────────────────────────────────────────────────────────────────────

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
	local low = string.lower(rawName)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == low
			or (p.DisplayName and p.DisplayName:lower() == low) then
			return p
		end
	end
	return nil
end

-- Estimated current bounty applying passive drain after combat tag expires.
local function getEstimated(entry)
	local elapsed = math.max(0, tick() - entry.lastSeenAt - COMBAT_TAG_WINDOW)
	local drained  = math.floor(elapsed * DRAIN_PER_SEC)
	return math.max(0, entry.amount - drained)
end

-- ── Tracking state ─────────────────────────────────────────────────────────────

local function setBounty(rawName, amount)
	local p   = resolvePlayer(rawName)
	local key = string.lower((p and p.Name) or rawName)
	local now = tick()

	-- seenSigs: use name+amount so same player with new amount always updates.
	local sig = key .. ":" .. tostring(amount)
	if seenSigs[sig] then
		-- Still update lastSeenAt so drain timer resets (they're back in combat)
		if tracked[key] then
			tracked[key].lastSeenAt = now
			dirty = true
		end
		return
	end
	seenSigs[sig] = true

	tracked[key] = {
		name       = (p and p.Name) or rawName,
		display    = (p and p.DisplayName) or rawName,
		amount     = amount,
		lastSeenAt = now,
		userId     = p and p.UserId or nil,
		isLP       = (p == LP),
	}
	dirty = true
end

local function clearBounty(rawName)
	local p   = resolvePlayer(rawName)
	local key = string.lower((p and p.Name) or rawName)
	if tracked[key] then
		tracked[key] = nil
		dirty = true
	end
end

-- ── Popup parsing ──────────────────────────────────────────────────────────────

local function collectTexts(root, maxDepth, budget)
	local out   = {}
	local queue = { root }
	local depth = { [root] = 0 }
	local qi    = 1
	local nodes = 0
	while qi <= #queue and nodes < budget do
		local node = queue[qi]; qi += 1; nodes += 1
		local d    = depth[node] or 0
		if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then
			local t = node.Text
			if type(t) == "string" and #t > 0 and t ~= "Close" then
				out[#out + 1] = t
			end
		end
		if d < maxDepth then
			local ok, kids = pcall(node.GetChildren, node)
			if ok then
				for _, ch in ipairs(kids) do
					if not isOurs(ch) then
						queue[#queue + 1] = ch
						depth[ch] = d + 1
					end
				end
			end
		end
	end
	return out
end

-- Try to extract a player name and bounty amount from a block of popup texts.
-- Handles display names with spaces, amounts with commas, $ prefix optional.
-- IMPORTANT: name must resolve to a real player on the server — otherwise we
-- risk grabbing random GUI text (e.g. server codes like "#1x8z").
local function tryExtractAlert(texts, joined)
	-- Pattern 1: line with "Name: $1,000" or "Name: 1000"
	for _, t in ipairs(texts) do
		local name, amt = t:match("^%s*(.-)%s*:%s*%$?([%d,]+)%s*$")
		if name and amt and #name >= 2 and not string.lower(name):find("bounty") then
			local n = parseAmount(amt)
			if n and n > 0 and resolvePlayer(name) then
				return name, n
			end
		end
	end
	-- Pattern 2: anywhere in joined text — try every "x: y" pair and keep the
	-- first that matches a real player.
	for name, amt in joined:gmatch("([^\n:]+)%s*:%s*%$?([%d,]+)") do
		name = name:match("^%s*(.-)%s*$")  -- trim
		if #name >= 2 and not string.lower(name):find("bounty") then
			local n = parseAmount(amt)
			if n and n > 0 and resolvePlayer(name) then
				return name, n
			end
		end
	end
	return nil, nil
end

local function tryExtractClaim(texts, joined)
	-- "PlayerName's $1,000 bounty was claimed" — allow spaces in name
	for _, t in ipairs(texts) do
		local name = t:match("^%s*(.-)%s*'s%s.*bounty%s+was%s+claimed")
			or t:match("^%s*(.-)%s*'s%s+bounty%s+was%s+claimed")
		if name and #name >= 2 then return name end
	end
	local name = joined:match("(.-)%s*'s%s.*bounty%s+was%s+claimed")
		or joined:match("(.-)%s*'s%s+bounty%s+was%s+claimed")
	if name and #name >= 2 then return name end
	return nil
end

local function parsePopupBag(texts)
	if #texts == 0 then return false end
	local joined = table.concat(texts, "\n")
	local low    = string.lower(joined)

	local isAlert = low:find("bounty alert",   1, true) ~= nil
	local isClaim = low:find("bounty claimed", 1, true) ~= nil
	if not isAlert and not isClaim then return false end

	if isAlert then
		local name, n = tryExtractAlert(texts, joined)
		if name and n then
			setBounty(name, n)
			return true
		end
		return false
	end

	-- Claimed
	local name = tryExtractClaim(texts, joined)
	if name then
		clearBounty(name)
		return true
	end
	return false
end

-- ── Scan a single root ─────────────────────────────────────────────────────────

local function scanRoot(root)
	if not root or not root.Parent then return end
	if isOurs(root) then return end

	local texts = collectTexts(root, MAX_DEPTH, MAX_NODES)

	-- Fast reject
	local hit = false
	for _, t in ipairs(texts) do
		if string.lower(t):find("bounty", 1, true) then hit = true; break end
	end
	if not hit then return end

	if parsePopupBag(texts) then return end

	-- Climb: find title label, then look at ancestor frames
	local queue  = { root }
	local depths = { [root] = 0 }
	local qi, nodes = 1, 0
	while qi <= #queue and nodes < MAX_NODES do
		local node = queue[qi]; qi += 1; nodes += 1
		local d    = depths[node] or 0
		if node:IsA("TextLabel") or node:IsA("TextButton") then
			local t = node.Text
			if type(t) == "string" then
				local tl = string.lower(t)
				if tl:find("bounty alert", 1, true) or tl:find("bounty claimed", 1, true) then
					local climb = node
					for _ = 1, 6 do
						local par = climb.Parent
						if not par or par == root.Parent then break end
						climb = par
						if climb:IsA("Frame") or climb:IsA("ScreenGui") then
							if parsePopupBag(collectTexts(climb, 8, 120)) then return end
						end
					end
				end
			end
		end
		if d < MAX_DEPTH then
			local ok, kids = pcall(node.GetChildren, node)
			if ok then
				for _, ch in ipairs(kids) do
					if not isOurs(ch) then
						queue[#queue + 1] = ch
						depths[ch] = d + 1
					end
				end
			end
		end
	end
end

-- ── Watcher management ─────────────────────────────────────────────────────────

local function scheduleScan(root, S)
	if not S or not S.CrimBountyTracker then return end
	if not root or pendingScan[root] then return end
	pendingScan[root] = true
	scanToken += 1
	local token = scanToken
	task.delay(SCAN_DEBOUNCE, function()
		pendingScan[root] = nil
		if not S.CrimBountyTracker then return end
		if root.Parent then pcall(scanRoot, root) end
	end)
end

local function unwatchScreenGui(sg)
	local c = sgConns[sg]
	if c then pcall(function() c:Disconnect() end); sgConns[sg] = nil end
	sgChildCount[sg] = nil
	pendingScan[sg]  = nil
end

local function watchScreenGui(sg, S)
	if not sg or sgConns[sg] or isOurs(sg) then return end
	local ok, n = pcall(function() return #sg:GetChildren() end)
	sgChildCount[sg] = ok and n or 0
	sgConns[sg] = sg.ChildAdded:Connect(function()
		scheduleScan(sg, S)
	end)
	scheduleScan(sg, S)
end

local function attachPlayerGui(pg, S)
	if pgConn then pgConn:Disconnect(); pgConn = nil end
	for sg in pairs(sgConns) do unwatchScreenGui(sg) end
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

-- IMPORTANT: Criminality's popup is often a single persistent Frame that just
-- toggles Visible + updates Text (no ChildAdded fires, child count unchanged).
-- So we can't rely on mutation events alone — periodically re-scan every
-- watched root unconditionally. Still bounded (MAX_NODES/MAX_DEPTH) and only
-- touches roots we already track, so cost stays tiny (no full PlayerGui walk).
local function fallbackCheck(S)
	for sg, last in pairs(sgChildCount) do
		if not sg.Parent then
			unwatchScreenGui(sg)
		else
			local ok, n = pcall(function() return #sg:GetChildren() end)
			if ok then sgChildCount[sg] = n end
			scheduleScan(sg, S)
		end
	end
end

-- ── Rendering ─────────────────────────────────────────────────────────────────

local function ensureRow(list, i)
	if rows[i] and rows[i].Parent == list then return rows[i] end
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	row.BorderSizePixel  = 0
	row.LayoutOrder      = i
	row.ZIndex           = 7
	row.Name             = "BountyRow" .. i
	row.Parent           = list
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

	local function mk(name, props)
		local l = Instance.new("TextLabel")
		l.Name                = name
		l.BackgroundTransparency = 1
		l.ZIndex              = 8
		for k, v in pairs(props) do l[k] = v end
		l.Parent = row
		return l
	end

	mk("Rank", {
		Size = UDim2.new(0, 26, 1, 0),
		Position = UDim2.new(0, 6, 0, 0),
		Font = Enum.Font.GothamBold, TextSize = 11,
		TextColor3 = Color3.fromRGB(120, 120, 130),
		TextXAlignment = Enum.TextXAlignment.Left, Text = "",
	})
	mk("PName", {
		Size = UDim2.new(1, -140, 1, 0),
		Position = UDim2.new(0, 34, 0, 0),
		Font = Enum.Font.GothamMedium, TextSize = 11,
		TextColor3 = Color3.fromRGB(220, 220, 228),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = "",
	})
	mk("Amount", {
		Size = UDim2.new(0, 96, 1, 0),
		Position = UDim2.new(1, -102, 0, 0),
		Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = ACC,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "",
	})

	rows[i] = row
	return row
end

local function render(list, hdr)
	-- Remove players who left
	for key, entry in pairs(tracked) do
		if entry.userId then
			local found = false
			for _, p in ipairs(Players:GetPlayers()) do
				if p.UserId == entry.userId then found = true; break end
			end
			if not found then tracked[key] = nil end
		end
	end

	-- Apply estimated drain; remove zeroed entries
	for key, entry in pairs(tracked) do
		if getEstimated(entry) <= 0 then
			tracked[key] = nil
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

		local est     = getEstimated(entry)
		local draining = tick() - entry.lastSeenAt > COMBAT_TAG_WINDOW
		if draining then
			row.Amount.Text       = "~" .. fmtMoney(est)
			row.Amount.TextColor3 = ACC_DRAIN
		else
			row.Amount.Text       = fmtMoney(entry.amount)
			row.Amount.TextColor3 = ACC
		end
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
local wasOn      = false

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
				if pgConn then pgConn:Disconnect(); pgConn = nil end
				for sg in pairs(sgConns) do unwatchScreenGui(sg) end
				pgAttached = false
				wasOn = false
			end
			return
		end
		wasOn = true

		local now = tick()
		local pg  = LP and LP:FindFirstChildOfClass("PlayerGui")
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

		-- Drain causes constant change → always mark dirty after combat tag window
		for key, entry in pairs(tracked) do
			if tick() - entry.lastSeenAt > COMBAT_TAG_WINDOW then
				dirty = true
				break
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
	wasOn      = false
	for _, r in ipairs(rows) do if r then r.Visible = false end end
end

return BountyTracker
