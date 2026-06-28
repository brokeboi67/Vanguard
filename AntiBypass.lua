-- Plik: workspace/Vanguard/AntiBypass.lua

local AntiBypass = {}

local concealed = setmetatable({}, { __mode = "k" })
local protected = setmetatable({}, { __mode = "k" })

local function randomName()
	local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	local out = {}
	for i = 1, 12 do
		local idx = math.random(1, #chars)
		out[i] = string.sub(chars, idx, idx)
	end
	return table.concat(out)
end

function AntiBypass.getGuiRoot()
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then
			return hui
		end
	end
	if typeof(get_hidden_gui) == "function" then
		local ok, hui = pcall(get_hidden_gui)
		if ok and hui then
			return hui
		end
	end
	local LP = game:GetService("Players").LocalPlayer
	local pg = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
	local folder = pg:FindFirstChild("_")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "_"
		folder.Parent = pg
	end
	return folder
end

function AntiBypass.protectInstance(gui)
	if not gui or protected[gui] then
		return
	end
	protected[gui] = true

	if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, gui)
	end
	if typeof(protectgui) == "function" then
		pcall(protectgui, gui)
	end
	if typeof(gethui) == "function" then
		pcall(function()
			local hui = gethui()
			if hui and gui.Parent ~= hui then
				gui.Parent = hui
			end
		end)
	end
	if typeof(cloneref) == "function" then
		pcall(cloneref, gui)
	end
end

function AntiBypass.concealGui(gui)
	if not gui or not gui:IsA("GuiObject") then
		return
	end
	if concealed[gui] then
		return
	end
	concealed[gui] = true

	AntiBypass.protectInstance(gui)

	pcall(function()
		gui.Name = randomName()
	end)
	pcall(function()
		if gui:IsA("ScreenGui") then
			gui.DisplayOrder = math.clamp(gui.DisplayOrder or 1, -999, 9)
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			gui.ResetOnSpawn = false
			gui.IgnoreGuiInset = true
		end
	end)
end

function AntiBypass.isVanguardGui(gui)
	return gui and concealed[gui] == true
end

function AntiBypass.Init(S)
	if S.AntiBypass == false then
		return
	end

	local root = AntiBypass.getGuiRoot()

	local function sweep(parent)
		for _, ch in ipairs(parent:GetChildren()) do
			if concealed[ch] then
				AntiBypass.concealGui(ch)
			elseif ch:IsA("ScreenGui") then
				local n = string.lower(ch.Name)
				if n:find("vanguard", 1, true) or n:find("esp", 1, true) and ch:GetAttribute("VG") then
					AntiBypass.concealGui(ch)
				end
			end
		end
	end

	sweep(root)
	root.ChildAdded:Connect(function(ch)
		task.defer(function()
			if ch:IsA("ScreenGui") or ch:IsA("Folder") then
				sweep(ch)
			end
			if concealed[ch] or (ch:IsA("ScreenGui") and string.lower(ch.Name):find("vanguard", 1, true)) then
				AntiBypass.concealGui(ch)
			end
		end)
	end)

	task.spawn(function()
		while S.AntiBypass ~= false do
			sweep(root)
			if S.AntiStealth ~= false then
				for gui in pairs(concealed) do
					if gui.Parent then
						pcall(function()
							if math.random() < 0.15 then
								gui.Name = randomName()
							end
						end)
					end
				end
			end
			task.wait(8 + math.random() * 4)
		end
	end)
end

return AntiBypass
