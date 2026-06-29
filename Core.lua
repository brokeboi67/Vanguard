-- Plik: workspace/Vanguard/Core.lua

local Core = {}

local MARKER_NAME = "VanguardActiveMarker"

function Core.isActive()
	return _G.VANGUARD ~= nil and _G.VANGUARD.Active == true
end

function Core.showDuplicateWarning()
	local Players = game:GetService("Players")
	local TS = game:GetService("TweenService")
	local LP = Players.LocalPlayer
	if not LP then
		return
	end

	local root = LP:WaitForChild("PlayerGui")
	if root:FindFirstChild("VG_DuplicateWarn") then
		return
	end

	local sg = Instance.new("ScreenGui")
	sg.Name = "VG_DuplicateWarn"
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Global
	sg.DisplayOrder = 999999
	sg.Parent = root

	local dim = Instance.new("Frame")
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Parent = sg

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.Size = UDim2.new(0, 360, 0, 120)
	card.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	card.BorderSizePixel = 0
	card.Parent = sg
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 80, 80)
	stroke.Thickness = 2
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Position = UDim2.new(0, 12, 0, 14)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(255, 100, 100)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "VANGUARD JUŻ DZIAŁA"
	title.Parent = card

	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -24, 0, 48)
	body.Position = UDim2.new(0, 12, 0, 44)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamMedium
	body.TextSize = 12
	body.TextColor3 = Color3.fromRGB(210, 210, 220)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextWrapped = true
	body.Text = "Nie można załadować ponownie. Użyj Unload w Settings albo rejoin."
	body.Parent = card

	card.BackgroundTransparency = 1
	title.TextTransparency = 1
	body.TextTransparency = 1
	TS:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.05,
	}):Play()
	TS:Create(title, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	TS:Create(body, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()

	task.delay(4.5, function()
		if sg.Parent then
			TS:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TS:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TS:Create(title, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TS:Create(body, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.delay(0.35, function()
				pcall(function() sg:Destroy() end)
			end)
		end
	end)
end

function Core.begin()
	_G.VANGUARD = {
		Active = true,
		GUIs = {},
		Cleanups = {},
		registerGui = Core.registerGui,
		registerCleanup = Core.registerCleanup,
	}

	local marker = Instance.new("BoolValue")
	marker.Name = MARKER_NAME
	marker.Value = true
	marker.Parent = game:GetService("Players").LocalPlayer
	_G.VANGUARD.Marker = marker
end

function Core.registerGui(gui)
	if not _G.VANGUARD or not gui then
		return
	end
	table.insert(_G.VANGUARD.GUIs, gui)
end

function Core.registerCleanup(fn)
	if not _G.VANGUARD or typeof(fn) ~= "function" then
		return
	end
	table.insert(_G.VANGUARD.Cleanups, fn)
end

function Core.unload()
	if not Core.isActive() then
		return
	end

	_G.VANGUARD.Active = false

	for i = #_G.VANGUARD.Cleanups, 1, -1 do
		pcall(_G.VANGUARD.Cleanups[i])
	end

	for _, gui in ipairs(_G.VANGUARD.GUIs) do
		pcall(function()
			if gui and gui.Parent then
				gui:Destroy()
			end
		end)
	end

	pcall(function()
		if _G.VANGUARD.Marker then
			_G.VANGUARD.Marker:Destroy()
		end
	end)

	local Lighting = game:GetService("Lighting")
	for _, inst in ipairs(Lighting:GetChildren()) do
		if inst.Name == "VG_FX" or inst.Name == "VG_CC" or inst.Name == "VG_Bloom" or inst.Name == "VanguardMenuBlur" then
			pcall(function() inst:Destroy() end)
		end
	end

	pcall(function()
		local blur = workspace:FindFirstChild("VG_FXRoot")
		if blur then
			blur:Destroy()
		end
	end)

	pcall(function()
		game:GetService("ContextActionService"):UnbindAction("VanguardSilent")
	end)

	_G.VANGUARD = nil
	print("VANGUARD: Unloaded")
end

return Core
