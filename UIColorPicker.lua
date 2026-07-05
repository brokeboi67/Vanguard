-- Plik: workspace/Vanguard/UIColorPicker.lua

local UIColorPicker = {}

function UIColorPicker.create(env)
	local ParentGUI = env.ParentGUI
	local S = env.S
	local C = env.C
	local ACC = env.ACC
	local UIS = env.UIS
	local UpdPreview = env.UpdPreview
	local colorRegistry = env.colorRegistry

	local colorPickerOpen = false
	local colorPickerCtx = nil

	local ColorPickerOverlay = C("TextButton", {
		Name = "ColorPickerOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 200,
		Parent = ParentGUI,
	})

	local ColorPickerPanel = C("TextButton", {
		Name = "ColorPickerPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 248, 0, 292),
		BackgroundColor3 = Color3.fromRGB(14, 14, 18),
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 201,
		Parent = ColorPickerOverlay,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = ColorPickerPanel })
	C("UIStroke", { Color = Color3.fromRGB(42, 42, 52), Thickness = 1, Parent = ColorPickerPanel })

	local PickerTitle = C("TextLabel", {
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.new(0, 12, 0, 10),
		BackgroundTransparency = 1,
		Text = "Color",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(230, 230, 238),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 202,
		Parent = ColorPickerPanel,
	})

	local SVBox = C("TextButton", {
		Size = UDim2.new(1, -24, 0, 132),
		Position = UDim2.new(0, 12, 0, 42),
		BackgroundColor3 = Color3.fromHSV(0, 1, 1),
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 202,
		Parent = ColorPickerPanel,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = SVBox })
	C("UIStroke", { Color = Color3.fromRGB(50, 50, 58), Thickness = 1, Parent = SVBox })

	local SatOverlay = C("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 203,
		Parent = SVBox,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = SatOverlay })
	local SatGrad = C("UIGradient", { Rotation = 0, Parent = SatOverlay })
	SatGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})

	local ValOverlay = C("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 204,
		Parent = SVBox,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = ValOverlay })
	local ValGrad = C("UIGradient", { Rotation = 90, Parent = ValOverlay })
	ValGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})

	local SVCursor = C("Frame", {
		Size = UDim2.new(0, 12, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 205,
		Parent = SVBox,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = SVCursor })
	C("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Parent = SVCursor })

	local HueTrack = C("TextButton", {
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.new(0, 12, 0, 184),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 202,
		Parent = ColorPickerPanel,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = HueTrack })
	local hueKeys = {}
	for i = 0, 6 do
		table.insert(hueKeys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
	end
	C("UIGradient", { Color = ColorSequence.new(hueKeys), Parent = HueTrack })

	local HueKnob = C("Frame", {
		Size = UDim2.new(0, 8, 0, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 203,
		Parent = HueTrack,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = HueKnob })
	C("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Parent = HueKnob })

	local PreviewSwatch = C("Frame", {
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(0, 12, 0, 210),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 202,
		Parent = ColorPickerPanel,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = PreviewSwatch })
	C("UIStroke", { Color = Color3.fromRGB(50, 50, 58), Thickness = 1, Parent = PreviewSwatch })

	local HexLbl = C("TextLabel", {
		Size = UDim2.new(1, -120, 0, 36),
		Position = UDim2.new(0, 56, 0, 210),
		BackgroundTransparency = 1,
		Text = "#FFFFFF",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 202,
		Parent = ColorPickerPanel,
	})

	local PickerDone = C("TextButton", {
		Size = UDim2.new(0, 72, 0, 32),
		Position = UDim2.new(1, -84, 0, 248),
		BackgroundColor3 = ACC,
		Text = "Done",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(12, 12, 16),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 202,
		Parent = ColorPickerPanel,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 8), Parent = PickerDone })

	local function formatHex(col)
		local r = math.floor(col.R * 255 + 0.5)
		local g = math.floor(col.G * 255 + 0.5)
		local b = math.floor(col.B * 255 + 0.5)
		return string.format("#%02X%02X%02X", r, g, b)
	end

	local function closeColorPicker()
		colorPickerOpen = false
		colorPickerCtx = nil
		ColorPickerOverlay.Visible = false
	end

	local function applyPickerVisuals()
		if not colorPickerCtx then
			return
		end
		local h, s, v = colorPickerCtx.h, colorPickerCtx.s, colorPickerCtx.v
		SVBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		local col = Color3.fromHSV(h, s, v)
		SVCursor.Position = UDim2.new(s, 0, 1 - v, 0)
		HueKnob.Position = UDim2.new(h, 0, 0.5, 0)
		PreviewSwatch.BackgroundColor3 = col
		HexLbl.Text = formatHex(col)
		if colorPickerCtx.swatch then
			colorPickerCtx.swatch.BackgroundColor3 = col
		end
		S[colorPickerCtx.key] = col
		UpdPreview()
		if colorPickerCtx.onChange then
			pcall(colorPickerCtx.onChange, col)
		end
	end

	local function setPickerHSV(h, s, v)
		if not colorPickerCtx then
			return
		end
		colorPickerCtx.h = math.clamp(h, 0, 1)
		colorPickerCtx.s = math.clamp(s, 0, 1)
		colorPickerCtx.v = math.clamp(v, 0, 1)
		applyPickerVisuals()
	end

	local function openColorPicker(label, key, swatch, opts)
		opts = opts or {}
		if opts.enabled == false then
			return
		end
		local col = S[key] or Color3.new(1, 1, 1)
		local h, s, v = col:ToHSV()
		if s == 0 and v == 0 then
			h = 0
			s = 0
			v = 0
		end
		colorPickerCtx = {
			key = key,
			swatch = swatch,
			onChange = opts.onChange,
			h = h,
			s = s,
			v = v,
		}
		colorPickerOpen = true
		PickerTitle.Text = label or "Color"
		ColorPickerOverlay.Visible = true
		applyPickerVisuals()
	end

	local svDragging = false
	local hueDragging = false

	local function svFromInput(x, y)
		local ax, ay = SVBox.AbsolutePosition.X, SVBox.AbsolutePosition.Y
		local aw, ah = SVBox.AbsoluteSize.X, SVBox.AbsoluteSize.Y
		if aw <= 0 or ah <= 0 or not colorPickerCtx then
			return
		end
		local s = math.clamp((x - ax) / aw, 0, 1)
		local v = math.clamp(1 - (y - ay) / ah, 0, 1)
		setPickerHSV(colorPickerCtx.h, s, v)
	end

	local function hueFromInput(x)
		local ax = HueTrack.AbsolutePosition.X
		local aw = HueTrack.AbsoluteSize.X
		if aw <= 0 or not colorPickerCtx then
			return
		end
		local h = math.clamp((x - ax) / aw, 0, 1)
		setPickerHSV(h, colorPickerCtx.s, colorPickerCtx.v)
	end

	SVBox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and colorPickerOpen then
			svDragging = true
			svFromInput(input.Position.X, input.Position.Y)
		end
	end)
	HueTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and colorPickerOpen then
			hueDragging = true
			hueFromInput(input.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if svDragging and colorPickerOpen then
			svFromInput(input.Position.X, input.Position.Y)
		elseif hueDragging and colorPickerOpen then
			hueFromInput(input.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			svDragging = false
			hueDragging = false
		end
	end)
	ColorPickerOverlay.MouseButton1Click:Connect(closeColorPicker)
	PickerDone.MouseButton1Click:Connect(closeColorPicker)

	local function MakeColorPicker(page, label, key, order, opts)
		opts = opts or {}
		local enabled = opts.enabled ~= false

		local Row = C("TextButton", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Color3.fromRGB(17, 17, 21),
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 5,
			Parent = page,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Row })
		C("UIStroke", { Color = Color3.fromRGB(32, 32, 40), Thickness = 1, Transparency = 0.5, Parent = Row })

		C("TextLabel", {
			Size = UDim2.new(1, -100, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1,
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(200, 200, 208),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
			Parent = Row,
		})

		local HexRow = C("TextLabel", {
			Size = UDim2.new(0, 64, 1, 0),
			Position = UDim2.new(1, -92, 0, 0),
			BackgroundTransparency = 1,
			Text = formatHex(S[key] or Color3.new(1, 1, 1)),
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextColor3 = Color3.fromRGB(130, 130, 145),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6,
			Parent = Row,
		})

		local Swatch = C("Frame", {
			Size = UDim2.new(0, 24, 0, 24),
			Position = UDim2.new(1, -36, 0.5, -12),
			BackgroundColor3 = S[key] or Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = Row,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 5), Parent = Swatch })
		C("UIStroke", { Color = Color3.fromRGB(50, 50, 58), Thickness = 1, Parent = Swatch })

		local SwatchBtn = C("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 7,
			Parent = Swatch,
		})

		local regActive = enabled
		local function refreshRow()
			local col = S[key] or Color3.new(1, 1, 1)
			Swatch.BackgroundColor3 = col
			HexRow.Text = formatHex(col)
		end

		SwatchBtn.MouseButton1Click:Connect(function()
			if not regActive then
				return
			end
			openColorPicker(label, key, Swatch, {
				onChange = function(col)
					HexRow.Text = formatHex(col)
					if opts.onChange then
						pcall(opts.onChange, col)
					end
				end,
			})
		end)

		Row.MouseButton1Click:Connect(function()
			if not regActive then
				return
			end
			openColorPicker(label, key, Swatch, {
				onChange = function(col)
					HexRow.Text = formatHex(col)
					if opts.onChange then
						pcall(opts.onChange, col)
					end
				end,
			})
		end)

		table.insert(colorRegistry, {
			row = Row,
			swatch = Swatch,
			hex = HexRow,
			setEnabled = function(on)
				regActive = on
				Row.BackgroundTransparency = on and 0 or 0.35
				Swatch.BackgroundTransparency = on and 0 or 0.35
				HexRow.TextTransparency = on and 0 or 0.45
			end,
			refresh = refreshRow,
		})
	end

	return MakeColorPicker
end

return UIColorPicker
