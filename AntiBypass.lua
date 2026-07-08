-- Plik: workspace/Vanguard/AntiBypass.lua

local AntiBypass = {}

local concealed = setmetatable({}, { __mode = "k" })
local protected = setmetatable({}, { __mode = "k" })
local cachedGuiRoot = nil

local function cr(inst)
	if typeof(cloneref) == "function" then
		local ok, ref = pcall(cloneref, inst)
		if ok and ref then return ref end
	end
	return inst
end

local function tryHiddenGui(fn)
	if typeof(fn) ~= "function" then
		return nil
	end
	local ok, hui = pcall(fn)
	if ok and hui and typeof(hui) == "Instance" then
		return cr(hui)
	end
	return nil
end

local GUI_ORDER = 8

function AntiBypass.setStealth(_mod)
end

function AntiBypass.getGuiRoot()
	if cachedGuiRoot and cachedGuiRoot.Parent then
		return cachedGuiRoot
	end

	local root = tryHiddenGui(gethui)
		or tryHiddenGui(get_hidden_gui)
		or tryHiddenGui(gethiddengui)

	if not root and typeof(getgenv) == "function" then
		local g = getgenv()
		if g and typeof(g.gethui) == "function" then
			root = tryHiddenGui(g.gethui)
		end
	end

	if not root then
		local okCore, coreGui = pcall(function() return cr(game:GetService("CoreGui")) end)
		if okCore and coreGui then
			root = coreGui
		end
	end

	if not root then
		local LP = cr(game:GetService("Players").LocalPlayer)
		root = LP and (LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui"))
	end

	if root then
		cachedGuiRoot = root
	end
	return root
end

function AntiBypass.bringToFront(gui)
	if not gui then
		return
	end
	pcall(function()
		if gui:IsA("ScreenGui") then
			gui.DisplayOrder = GUI_ORDER
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
	if typeof(cloneref) == "function" then
		pcall(cloneref, gui)
	end
	local root = AntiBypass.getGuiRoot()
	if root and gui.Parent ~= root then
		pcall(function()
			gui.Parent = root
		end)
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
		while S.AntiBypass ~= false and not S.Unloaded do
			if _G.VANGUARD and not _G.VANGUARD.Active then
				break
			end
			sweep(root)
			task.wait(2)
		end
	end)
end

return AntiBypass
