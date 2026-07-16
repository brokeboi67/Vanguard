-- BountyTracker.lua v2.51.0
-- Scans players in the server and shows their bounty, sorted highest → lowest.
-- The remote/attribute names in Criminality are obfuscated, so instead of relying
-- on a fixed key this module auto-discovers the bounty source per player:
--   1) player / character attributes whose name looks like "bounty" / "wanted"
--   2) leaderstats + direct Value objects with a matching name
--   3) nametag BillboardGui text over the character head containing "$"
-- It renders its rows into a container the UI publishes at _G.__VG_BountyList.

local BountyTracker = {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")

local LP = Players.LocalPlayer

local function nameMatches(n)
	if type(n) ~= "string" then return false end
	n = string.lower(n)
	return n:find("bounty") ~= nil or n:find("wanted") ~= nil or n == "bnty"
end

-- Turns "$2,201" / "2201" / 2201 into a number. Returns nil if nothing usable.
local function parseAmount(v)
	if type(v) == "number" then
		return v
	end
	if type(v) == "string" then
		local digits = (v:gsub("[^%d]", ""))
		if #digits > 0 then
			return tonumber(digits)
		end
	end
	return nil
end

local function scanAttributes(inst, best)
	if not inst then return best end
	local ok, attrs = pcall(function() return inst:GetAttributes() end)
	if ok and type(attrs) == "table" then
		for k, v in pairs(attrs) do
			if nameMatches(k) then
				local a = parseAmount(v)
				if a and a > (best or -1) then best = a end
			end
		end
	end
	return best
end

local function scanValues(container, best, deep)
	if not container then return best end
	local list = deep and container:GetDescendants() or container:GetChildren()
	for _, d in ipairs(list) do
		if nameMatches(d.Name) then
			local ok, val = pcall(function() return d.Value end)
			if ok then
				local a = parseAmount(val)
				if a and a > (best or -1) then best = a end
			end
		end
	end
	return best
end

-- Best-effort read of a bounty number over the character head (nametag GUIs).
local function scanNametag(char, best)
	if not char then return best end
	local head = char:FindFirstChild("Head")
	local roots = { head, char }
	for _, root in ipairs(roots) do
		if root then
			for _, gui in ipairs(root:GetChildren()) do
				if gui:IsA("BillboardGui") then
					for _, lbl in ipairs(gui:GetDescendants()) do
						if lbl:IsA("TextLabel") or lbl:IsA("TextButton") then
							local t = lbl.Text
							if type(t) == "string" and t:find("%$") then
								local a = parseAmount(t)
								if a and a > (best or -1) then best = a end
							end
						end
					end
				end
			end
		end
	end
	return best
end

function BountyTracker.getBounty(p)
	local best = nil
	best = scanAttributes(p, best)
	best = scanAttributes(p.Character, best)

	local ls = p:FindFirstChild("leaderstats")
	if ls then best = scanValues(ls, best, false) end
	best = scanValues(p, best, false)

	-- Common stat folders (obfuscated-safe: matched by name pattern anyway)
	for _, fname in ipairs({ "Data", "Stats", "PlayerData", "Values", "stats" }) do
		local f = p:FindFirstChild(fname)
		if f then best = scanValues(f, best, false) end
	end

	if best == nil then
		best = scanNametag(p.Character, best)
	end
	return best
end

-- ── Rendering ────────────────────────────────────────────────────────────────

local rows = {}
local ACC = Color3.fromRGB(235, 90, 90)

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

local function fmtMoney(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	out = out:gsub("^,", "")
	return "$" .. out
end

local function render(S, list)
	local data = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local b = BountyTracker.getBounty(p)
		if b == nil then b = 0 end
		if b > 0 or S.CrimBountyShowZero then
			table.insert(data, { name = p.DisplayName or p.Name, raw = p.Name, amount = b, isLP = (p == LP) })
		end
	end
	table.sort(data, function(a, b) return a.amount > b.amount end)

	for i, entry in ipairs(data) do
		local row = ensureRow(list, i)
		row.Visible = true
		row.Rank.Text = "#" .. i
		local disp = entry.name
		if entry.raw and entry.raw ~= entry.name then
			disp = disp .. "  (@" .. entry.raw .. ")"
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
	return #data
end

local function clearRows()
	for _, r in ipairs(rows) do
		if r then r.Visible = false end
	end
end

-- ── Loop ─────────────────────────────────────────────────────────────────────

local conn = nil
local lastScan = 0
local knownBounties = {}

function BountyTracker.Init(S)
	if conn then return end

	conn = RS.Heartbeat:Connect(function()
		if not S.CrimBountyTracker then
			return
		end
		local list = _G.__VG_BountyList
		if not list or not list.Parent then
			return
		end
		local hdr = _G.__VG_BountyHeader

		local now = tick()
		if now - lastScan < 1 then
			return
		end
		lastScan = now

		local ok, count = pcall(render, S, list)
		if ok and hdr then
			hdr.Text = string.format("%d gracz(y) z bounty", count)
		end

		-- Passive notify of newly appeared bounties (optional light signal)
		if S.CrimBountyNotify then
			for _, p in ipairs(Players:GetPlayers()) do
				local b = BountyTracker.getBounty(p)
				if b and b > 0 then
					local prev = knownBounties[p.UserId]
					if prev == nil or b > prev then
						knownBounties[p.UserId] = b
					end
				end
			end
		end
	end)
end

function BountyTracker.Stop()
	if conn then conn:Disconnect() conn = nil end
	clearRows()
end

return BountyTracker
