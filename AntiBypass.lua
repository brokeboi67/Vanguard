-- Plik: workspace/Vanguard/AntiBypass.lua

local AntiBypass = {}

local concealed = setmetatable({}, { __mode = "k" })
local protected = setmetatable({}, { __mode = "k" })

local GUI_ORDER = 999999

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
	return LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
end

function AntiBypass.bringToFront(gui)
	if not gui then
		return
	end
	pcall(function()
		if gui:IsA("ScreenGui") then
			gui.DisplayOrder = GUI_ORDER
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
			gui.ResetOnSpawn = false
			gui.IgnoreGuiInset = true
		end
	end)
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
	concealed[gui] = true
	AntiBypass.protectInstance(gui)
	AntiBypass.bringToFront(gui)
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
				AntiBypass.bringToFront(ch)
			end
		end
	end

	sweep(root)
	root.ChildAdded:Connect(function(ch)
		task.defer(function()
			if concealed[ch] then
				AntiBypass.bringToFront(ch)
			end
		end)
	end)

	task.spawn(function()
		while S.AntiBypass ~= false do
			sweep(root)
			task.wait(2)
		end
	end)
end

return AntiBypass
