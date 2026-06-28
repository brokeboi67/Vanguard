-- Plik: workspace/Vanguard/AntiBypass.lua

local AntiBypass = {}

local concealed = {}

function AntiBypass.getGuiRoot()
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then
			return hui
		end
	end
	local ok, cg = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and cg then
		return cg
	end
	return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

function AntiBypass.concealGui(gui)
	if not gui or not gui:IsA("GuiObject") then
		return
	end
	if concealed[gui] then
		return
	end
	concealed[gui] = true
	pcall(function()
		gui:SetAttribute("VG", true)
	end)
	pcall(function()
		local HttpService = game:GetService("HttpService")
		gui.Name = "Gui_" .. string.sub(HttpService:GenerateGUID(false), 1, 10)
	end)
	pcall(function()
		gui.DisplayOrder = math.clamp(gui.DisplayOrder or 1, 1, 9)
	end)
end

function AntiBypass.Init(S)
	if S.AntiBypass == false then
		return
	end

	local root = AntiBypass.getGuiRoot()

	local function sweep(parent)
		for _, ch in ipairs(parent:GetChildren()) do
			if ch:IsA("ScreenGui") and ch:GetAttribute("VG") then
				AntiBypass.concealGui(ch)
			end
		end
	end

	sweep(root)
	root.ChildAdded:Connect(function(ch)
		task.defer(function()
			if ch:IsA("ScreenGui") and ch:GetAttribute("VG") then
				AntiBypass.concealGui(ch)
			end
		end)
	end)

	task.spawn(function()
		while S.AntiBypass ~= false do
			sweep(root)
			task.wait(4 + math.random() * 2)
		end
	end)
end

return AntiBypass
