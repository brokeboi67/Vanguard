-- BountyTracker.lua v2.52.18
-- Watches PlayerGui.CoreGUI.NotificationFrame → Template_Button
--   Frame.NotificationTitle / NotificationText
-- ("Bounty Alert" adds, "Bounty Claimed" removes).
-- Also simulates $3/s passive drain after ~8 s combat-tag window.

local BountyTracker = {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local LP = Players.LocalPlayer

local COMBAT_TAG_WINDOW = 8
local DRAIN_PER_SEC     = 3

local tracked  = {}
local seenSigs = {}
local rows     = {}
local ACC      = Color3.fromRGB(235, 90, 90)
local ACC_DRAIN = Color3.fromRGB(180, 120, 60)
local dirty    = true

local hbConn       = nil
local nfConn       = nil   -- NotificationFrame.ChildAdded
local nfRemConn    = nil
local coreConn     = nil   -- CoreGUI wait
local btnConns     = {}    -- Template_Button → {conns}
local lastRender   = 0
local lastSeenPrune = 0
local lastPoll     = 0
local watchedNf    = nil

local RENDER_INTERVAL = 0.5
local POLL_INTERVAL   = 0.75  -- catch reused Template_Button Text updates
local SEEN_CAP        = 120

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
	if type(rawName) ~= "string" or #rawName < 2 then return nil end
	local low = string.lower(rawName)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == low
			or (p.DisplayName and p.DisplayName:lower() == low) then
			return p
		end
	end
	return nil
end

local function getEstimated(entry)
	local elapsed = math.max(0, tick() - entry.lastSeenAt - COMBAT_TAG_WINDOW)
	local drained = math.floor(elapsed * DRAIN_PER_SEC)
	return math.max(0, entry.amount - drained)
end

local function setBounty(rawName, amount)
	local p   = resolvePlayer(rawName)
	local key = string.lower((p and p.Name) or rawName)
	local now = tick()
	local sig = key .. ":" .. tostring(amount)
	if seenSigs[sig] then
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

local function findLabel(root, name)
	if not root then return nil end
	local direct = root:FindFirstChild(name)
	if direct and (direct:IsA("TextLabel") or direct:IsA("TextButton")) then
		return direct
	end
	-- one level deep (Frame.NotificationTitle)
	for _, ch in ipairs(root:GetChildren()) do
		local nested = ch:FindFirstChild(name)
		if nested and (nested:IsA("TextLabel") or nested:IsA("TextButton")) then
			return nested
		end
	end
	return nil
end

local function extractFromButton(btn)
	if not btn or not btn.Parent then return false end
	local frame = btn:FindFirstChild("Frame") or btn
	local titleInst = findLabel(frame, "NotificationTitle") or findLabel(btn, "NotificationTitle")
	local textInst  = findLabel(frame, "NotificationText") or findLabel(btn, "NotificationText")
	local title = titleInst and tostring(titleInst.Text or "") or ""
	local body  = textInst and tostring(textInst.Text or "") or ""
	local lowTitle = string.lower(title)
	local lowBody  = string.lower(body)
	local joined = title .. "\n" .. body
	local lowJoined = string.lower(joined)

	local isAlert = lowTitle:find("bounty alert", 1, true)
		or lowJoined:find("bounty alert", 1, true)
	local isClaim = lowTitle:find("bounty claimed", 1, true)
		or lowJoined:find("bounty claimed", 1, true)
		or lowBody:find("bounty was claimed", 1, true)

	if not isAlert and not isClaim then
		return false
	end

	if isAlert then
		-- "Volkenn: $3001" or "Name: 3001"
		local name, amt = body:match("^%s*(.-)%s*:%s*%$?([%d,]+)%s*$")
		if not name then
			name, amt = joined:match("([^\n:]+)%s*:%s*%$?([%d,]+)")
		end
		if name and amt then
			name = name:match("^%s*(.-)%s*$")
			if #name >= 2 and not string.lower(name):find("bounty") then
				local n = parseAmount(amt)
				if n and n > 0 then
					-- Prefer real player; still accept if HUD shows it (name may lag)
					setBounty(name, n)
					return true
				end
			end
		end
		return false
	end

	-- Claimed
	local name = body:match("^%s*(.-)%s*'s%s.*bounty")
		or body:match("^%s*(.-)%s*'s%s+bounty")
		or joined:match("(.-)%s*'s%s.*bounty%s+was%s+claimed")
	if name and #name >= 2 then
		name = name:match("^%s*(.-)%s*$")
		clearBounty(name)
		return true
	end
	return false
end

local function unwatchButton(btn)
	local pack = btnConns[btn]
	if not pack then return end
	for _, c in ipairs(pack) do
		pcall(function() c:Disconnect() end)
	end
	btnConns[btn] = nil
end

local function watchButton(btn, S)
	if not btn or btnConns[btn] then return end
	if type(btn.Name) == "string" and btn.Name:find("^VG_") then return end
	local pack = {}
	btnConns[btn] = pack

	local function hookText(inst)
		if not inst then return end
		pack.hooked = pack.hooked or {}
		if pack.hooked[inst] then return end
		pack.hooked[inst] = true
		local c = inst:GetPropertyChangedSignal("Text"):Connect(function()
			if S.CrimBountyTracker then
				pcall(extractFromButton, btn)
			end
		end)
		pack[#pack + 1] = c
	end

	local frame = btn:FindFirstChild("Frame") or btn
	hookText(findLabel(frame, "NotificationTitle") or findLabel(btn, "NotificationTitle"))
	hookText(findLabel(frame, "NotificationText") or findLabel(btn, "NotificationText"))

	-- Immediate + delayed parse (text often fills after clone)
	pcall(extractFromButton, btn)
	task.delay(0.15, function()
		if S.CrimBountyTracker and btn.Parent then
			local fr = btn:FindFirstChild("Frame") or btn
			hookText(findLabel(fr, "NotificationTitle") or findLabel(btn, "NotificationTitle"))
			hookText(findLabel(fr, "NotificationText") or findLabel(btn, "NotificationText"))
			pcall(extractFromButton, btn)
		end
	end)
	task.delay(0.5, function()
		if S.CrimBountyTracker and btn.Parent then pcall(extractFromButton, btn) end
	end)
end

local function pollNotificationFrame(nf, S)
	if not nf or not S.CrimBountyTracker then return end
	for _, ch in ipairs(nf:GetChildren()) do
		if ch:IsA("GuiObject") and ch.Name ~= "UIListLayout" and ch.Name ~= "UIScale" then
			if not btnConns[ch] then
				watchButton(ch, S)
			else
				pcall(extractFromButton, ch)
			end
		end
	end
end

local function detachNotificationFrame()
	if nfConn then pcall(function() nfConn:Disconnect() end); nfConn = nil end
	if nfRemConn then pcall(function() nfRemConn:Disconnect() end); nfRemConn = nil end
	for btn in pairs(btnConns) do unwatchButton(btn) end
	watchedNf = nil
end

local function attachNotificationFrame(nf, S)
	if not nf or watchedNf == nf then
		if nf then pollNotificationFrame(nf, S) end
		return
	end
	detachNotificationFrame()
	watchedNf = nf
	nfConn = nf.ChildAdded:Connect(function(ch)
		if not S.CrimBountyTracker then return end
		task.defer(function()
			watchButton(ch, S)
		end)
	end)
	nfRemConn = nf.ChildRemoved:Connect(function(ch)
		unwatchButton(ch)
	end)
	pollNotificationFrame(nf, S)
end

local function findNotificationFrame(pg)
	if not pg then return nil end
	local core = pg:FindFirstChild("CoreGUI") or pg:FindFirstChild("CoreGui")
	if not core then return nil end
	return core:FindFirstChild("NotificationFrame")
end

local function ensureWatch(S)
	local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
	if not pg then return end
	local nf = findNotificationFrame(pg)
	if nf then
		attachNotificationFrame(nf, S)
		return
	end
	-- Wait for CoreGUI / NotificationFrame
	if coreConn then return end
	local core = pg:FindFirstChild("CoreGUI") or pg:FindFirstChild("CoreGui")
	if core then
		coreConn = core.ChildAdded:Connect(function(ch)
			if ch.Name == "NotificationFrame" and S.CrimBountyTracker then
				attachNotificationFrame(ch, S)
			end
		end)
	else
		coreConn = pg.ChildAdded:Connect(function(ch)
			if (ch.Name == "CoreGUI" or ch.Name == "CoreGui") and S.CrimBountyTracker then
				if coreConn then coreConn:Disconnect(); coreConn = nil end
				local nf2 = ch:FindFirstChild("NotificationFrame")
				if nf2 then
					attachNotificationFrame(nf2, S)
				else
					coreConn = ch.ChildAdded:Connect(function(c2)
						if c2.Name == "NotificationFrame" and S.CrimBountyTracker then
							attachNotificationFrame(c2, S)
						end
					end)
				end
			end
		end)
	end
end

local function pruneSeen()
	local n = 0
	for _ in pairs(seenSigs) do n += 1 end
	if n <= SEEN_CAP then return end
	table.clear(seenSigs)
end

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
	for key, entry in pairs(tracked) do
		if entry.userId then
			local found = false
			for _, p in ipairs(Players:GetPlayers()) do
				if p.UserId == entry.userId then found = true; break end
			end
			if not found then tracked[key] = nil end
		end
	end
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
		local est = getEstimated(entry)
		local draining = tick() - entry.lastSeenAt > COMBAT_TAG_WINDOW
		if draining then
			row.Amount.Text = "~" .. fmtMoney(est)
			row.Amount.TextColor3 = ACC_DRAIN
		else
			row.Amount.Text = fmtMoney(entry.amount)
			row.Amount.TextColor3 = ACC
		end
	end
	for i = #data + 1, #rows do
		if rows[i] then rows[i].Visible = false end
	end
	if hdr then
		hdr.Text = #data == 0
			and "Brak alertów (czekam na NotificationFrame…)"
			or string.format("%d aktywnych bounty", #data)
	end
	dirty = false
end

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
				detachNotificationFrame()
				if coreConn then coreConn:Disconnect(); coreConn = nil end
				pgAttached = false
				wasOn = false
			end
			return
		end
		wasOn = true

		local now = tick()
		if not pgAttached then
			ensureWatch(S)
			pgAttached = true
		elseif not watchedNf then
			ensureWatch(S)
		end

		if now - lastPoll >= POLL_INTERVAL then
			lastPoll = now
			if watchedNf then
				pollNotificationFrame(watchedNf, S)
			else
				ensureWatch(S)
			end
			if now - lastSeenPrune > 30 then
				lastSeenPrune = now
				pruneSeen()
			end
		end

		for _, entry in pairs(tracked) do
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
	if coreConn then coreConn:Disconnect(); coreConn = nil end
	detachNotificationFrame()
	table.clear(tracked)
	table.clear(seenSigs)
	pgAttached = false
	wasOn = false
	for _, r in ipairs(rows) do if r then r.Visible = false end end
end

return BountyTracker
