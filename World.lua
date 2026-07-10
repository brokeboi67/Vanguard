-- Plik: workspace/Vanguard/World.lua

local World = {}

function World.Init(S)
	local Lighting = game:GetService("Lighting")
	local RS = game:GetService("RunService")

	local saved = nil
	local menuBlur = nil

	local function ensureBlur()
		if menuBlur and menuBlur.Parent then
			return menuBlur
		end
		menuBlur = Lighting:FindFirstChild("VanguardMenuBlur")
		if not menuBlur then
			menuBlur = Instance.new("BlurEffect")
			menuBlur.Name = "VanguardMenuBlur"
			menuBlur.Size = 0
			menuBlur.Enabled = true
			menuBlur.Parent = Lighting
		end
		return menuBlur
	end

	local function snapshotChild(className)
		local out = {}
		for _, inst in ipairs(Lighting:GetChildren()) do
			if inst:IsA(className) then
				if className == "Atmosphere" then
					out[inst] = {
						Density = inst.Density,
						Offset = inst.Offset,
						Haze = inst.Haze,
						Glare = inst.Glare,
						Color = inst.Color,
						Decay = inst.Decay,
					}
				elseif className == "ColorCorrectionEffect" then
					out[inst] = {
						Brightness = inst.Brightness,
						Contrast = inst.Contrast,
						Saturation = inst.Saturation,
						TintColor = inst.TintColor,
					}
				elseif className == "BloomEffect" then
					out[inst] = {
						Intensity = inst.Intensity,
						Size = inst.Size,
						Threshold = inst.Threshold,
					}
				elseif className == "SunRaysEffect" then
					out[inst] = {
						Intensity = inst.Intensity,
						Spread = inst.Spread,
					}
				end
			end
		end
		return out
	end

	local function captureDefaults()
		if saved then
			return
		end
		saved = {
			Brightness = Lighting.Brightness,
			GlobalShadows = Lighting.GlobalShadows,
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			FogEnd = Lighting.FogEnd,
			FogStart = Lighting.FogStart,
			FogColor = Lighting.FogColor,
			ClockTime = Lighting.ClockTime,
			ColorShift_Top = Lighting.ColorShift_Top,
			ColorShift_Bottom = Lighting.ColorShift_Bottom,
			ExposureCompensation = Lighting.ExposureCompensation,
			Atmosphere = snapshotChild("Atmosphere"),
			ColorCorrection = snapshotChild("ColorCorrectionEffect"),
			Bloom = snapshotChild("BloomEffect"),
			SunRays = snapshotChild("SunRaysEffect"),
		}
	end

	local function restoreGroup(group)
		if not saved or not group then
			return
		end
		for inst, props in pairs(group) do
			if inst.Parent then
				for k, v in pairs(props) do
					inst[k] = v
				end
			end
		end
	end

	local function restoreDefaults()
		if not saved then
			return
		end
		Lighting.Brightness = saved.Brightness
		Lighting.GlobalShadows = saved.GlobalShadows
		Lighting.Ambient = saved.Ambient
		Lighting.OutdoorAmbient = saved.OutdoorAmbient
		Lighting.FogEnd = saved.FogEnd
		Lighting.FogStart = saved.FogStart
		Lighting.FogColor = saved.FogColor
		Lighting.ClockTime = saved.ClockTime
		Lighting.ColorShift_Top = saved.ColorShift_Top
		Lighting.ColorShift_Bottom = saved.ColorShift_Bottom
		Lighting.ExposureCompensation = saved.ExposureCompensation
		restoreGroup(saved.Atmosphere)
		restoreGroup(saved.ColorCorrection)
		restoreGroup(saved.Bloom)
		restoreGroup(saved.SunRays)
	end

	local function applyFullBright(on)
		if on then
			Lighting.GlobalShadows = false
			Lighting.Brightness = math.max(S.WorldBrightness or 2, 2)
			Lighting.Ambient = Color3.fromRGB(255, 255, 255)
			Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
		elseif saved then
			Lighting.GlobalShadows = saved.GlobalShadows
			Lighting.Brightness = saved.Brightness
			Lighting.Ambient = saved.Ambient
			Lighting.OutdoorAmbient = saved.OutdoorAmbient
		end
	end

	local function applyLighting()
		if S.FullBright or not S.WorldLight then
			if saved and not S.FullBright then
				Lighting.Brightness = saved.Brightness
				Lighting.GlobalShadows = saved.GlobalShadows
				Lighting.Ambient = saved.Ambient
				Lighting.OutdoorAmbient = saved.OutdoorAmbient
				Lighting.ExposureCompensation = saved.ExposureCompensation
			end
			return
		end
		Lighting.Brightness = math.clamp(S.WorldBrightness or 2, 0, 10)
		Lighting.GlobalShadows = S.WorldShadows ~= false
		Lighting.ExposureCompensation = math.clamp(S.WorldExposure or 0, -3, 3)
		if typeof(S.WorldAmbient) == "Color3" then
			Lighting.Ambient = S.WorldAmbient
		end
		if typeof(S.WorldOutdoorAmbient) == "Color3" then
			Lighting.OutdoorAmbient = S.WorldOutdoorAmbient
		end
	end

	local function applyFog()
		if S.NoFog then
			Lighting.FogEnd = 100000
			Lighting.FogStart = 100000
			for _, inst in ipairs(Lighting:GetChildren()) do
				if inst:IsA("Atmosphere") then
					inst.Density = 0
					inst.Haze = 0
					inst.Glare = 0
				end
			end
			return
		end
		if not S.WorldFog then
			if saved then
				Lighting.FogEnd = saved.FogEnd
				Lighting.FogStart = saved.FogStart
				Lighting.FogColor = saved.FogColor
				restoreGroup(saved.Atmosphere)
			end
			return
		end
		if typeof(S.WorldFogColor) == "Color3" then
			Lighting.FogColor = S.WorldFogColor
		end
		Lighting.FogStart = math.clamp(S.WorldFogStart or 0, 0, 100000)
		Lighting.FogEnd = math.clamp(S.WorldFogEnd or 100000, 1, 100000)
		for _, inst in ipairs(Lighting:GetChildren()) do
			if inst:IsA("Atmosphere") then
				inst.Density = math.clamp(S.WorldAtmoDensity or 0.3, 0, 1)
				inst.Haze = math.clamp(S.WorldAtmoHaze or 0, 0, 10)
				inst.Glare = math.clamp(S.WorldAtmoGlare or 0, 0, 10)
				inst.Offset = math.clamp(S.WorldAtmoOffset or 0, 0, 1)
				if typeof(S.WorldAtmoColor) == "Color3" then
					inst.Color = S.WorldAtmoColor
				end
			end
		end
	end

	local function applyGrade()
		if not S.WorldGrade then
			if saved then
				Lighting.ColorShift_Top = saved.ColorShift_Top
				Lighting.ColorShift_Bottom = saved.ColorShift_Bottom
				restoreGroup(saved.ColorCorrection)
			end
			if S.WorldCustomLight then
				local hue = math.clamp(S.WorldColorHue or 0.55, 0, 1)
				local sat = math.clamp(S.WorldColorSat or 0.35, 0, 1)
				local tint = Color3.fromHSV(hue, sat, 1)
				Lighting.ColorShift_Top = tint
				Lighting.ColorShift_Bottom = tint:Lerp(Color3.new(1, 1, 1), 0.35)
			end
			return
		end
		if typeof(S.WorldColorShiftTop) == "Color3" then
			Lighting.ColorShift_Top = S.WorldColorShiftTop
		end
		if typeof(S.WorldColorShiftBottom) == "Color3" then
			Lighting.ColorShift_Bottom = S.WorldColorShiftBottom
		end
		for _, inst in ipairs(Lighting:GetChildren()) do
			if inst:IsA("ColorCorrectionEffect") then
				inst.Brightness = math.clamp(S.WorldCCBrightness or 0, -1, 1)
				inst.Contrast = math.clamp(S.WorldCCContrast or 0, -1, 1)
				inst.Saturation = math.clamp(S.WorldCCSaturation or 0, -1, 1)
				if typeof(S.WorldCCTint) == "Color3" then
					inst.TintColor = S.WorldCCTint
				end
			end
		end
	end

	local function applyPost()
		if not S.WorldPost then
			restoreGroup(saved and saved.Bloom or {})
			restoreGroup(saved and saved.SunRays or {})
			return
		end
		for _, inst in ipairs(Lighting:GetChildren()) do
			if inst:IsA("BloomEffect") then
				inst.Intensity = math.clamp(S.WorldBloom or 0, 0, 3)
			elseif inst:IsA("SunRaysEffect") then
				inst.Intensity = math.clamp(S.WorldSunRays or 0, 0, 1)
			end
		end
	end

	local function applyTime()
		if S.WorldTimeLock then
			Lighting.ClockTime = math.clamp(S.WorldTime or 14, 0, 24)
		elseif saved then
			Lighting.ClockTime = saved.ClockTime
		end
	end

	local function applyMenuBlur()
		local blur = ensureBlur()
		if S.MenuBlur and S.MenuOpen then
			blur.Size = math.clamp(S.MenuBlurSize or 18, 4, 48)
		else
			blur.Size = 0
		end
	end

	local function applyAll()
		captureDefaults()
		applyFullBright(S.FullBright == true)
		applyLighting()
		applyFog()
		applyGrade()
		applyPost()
		applyTime()
		applyMenuBlur()
	end

	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end

	RS.RenderStepped:Connect(perfWrap("World.Render", function()
		if S.WorldTimeLock then
			Lighting.ClockTime = math.clamp(S.WorldTime or 14, 0, 24)
		end
		applyMenuBlur()
	end))

	RS.Heartbeat:Connect(perfWrap("World.Heartbeat", function()
		captureDefaults()
		applyFullBright(S.FullBright == true)
		applyLighting()
		applyFog()
		applyGrade()
		applyPost()
	end))

	function World.Refresh()
		applyAll()
	end

	function World.OnSettingChanged()
		applyAll()
	end

	World.Refresh()

	if _G.VANGUARD then
		_G.VANGUARD.registerCleanup(function()
			restoreDefaults()
			if menuBlur and menuBlur.Parent then
				menuBlur:Destroy()
			end
		end)
	end
end

return World
