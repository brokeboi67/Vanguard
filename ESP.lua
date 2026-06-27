-- Plik: workspace/Vanguard/ESP.lua

local ESP = {}

function ESP.Init(S, ParentGUI)
	local P = game:GetService("Players")
	local RS = game:GetService("RunService")
	local LP = P.LocalPlayer
	local Cam = workspace.CurrentCamera

	local function C(class, props)
		local i = Instance.new(class)
		for k, v in pairs(props) do
			i[k] = v
		end
		return i
	end

	local ESP_C = C("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = ParentGUI })
	local Cache = {}
	local Bones = {
		{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
		{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
		{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
		{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
		{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
		{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
	}

	local function Ln()
		return C("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false, Parent = ESP_C })
	end

	local function UpdLn(f, p1, p2, c)
		local d = p2 - p1
		f.Size = UDim2.new(0, d.Magnitude, 0, S.Th)
		f.Position = UDim2.new(0, (p1.X + p2.X) / 2, 0, (p1.Y + p2.Y) / 2)
		f.Rotation = math.deg(math.atan2(d.Y, d.X))
		f.BackgroundColor3 = c
		f.Visible = true
	end

	local function MakeCorner(parent)
		local cr = {}
		for _ = 1, 8 do
			table.insert(cr, C("Frame", { BorderSizePixel = 0, BackgroundTransparency = 0, Visible = false, Parent = parent }))
		end
		return cr
	end

	local function UpdCorner(cr, w, h, clr)
		local th = S.Th
		local len = math.min(w, h) * 0.24
		local specs = {
			{ 0, 0, len, th }, { 0, 0, th, len },
			{ w - len, 0, len, th }, { w - th, 0, th, len },
			{ 0, h - th, len, th }, { 0, h - len, th, len },
			{ w - len, h - th, len, th }, { w - th, h - len, th, len },
		}
		for i, spec in ipairs(specs) do
			local f = cr[i]
			f.Size = UDim2.new(0, spec[3], 0, spec[4])
			f.Position = UDim2.new(0, spec[1], 0, spec[2])
			f.BackgroundColor3 = clr
			f.Visible = true
		end
	end

	local function HideCorner(cr)
		for _, f in ipairs(cr) do
			f.Visible = false
		end
	end

	local function GetWeapon(char)
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") then
				return item.Name
			end
		end
		return nil
	end

	local function Rainbow()
		return Color3.fromHSV((tick() * 0.45) % 1, 0.9, 1)
	end

	local function GetColor(p, c, ray)
		if S.Chams and S.ChamsRainbow then
			return Rainbow()
		end
		local clr = S.V
		if S.RealTeamColor and p.Team then
			clr = p.Team.TeamColor.Color
		elseif S.LoS and ray and ray.Instance and not ray.Instance:IsDescendantOf(c) then
			clr = S.O
		end
		return clr
	end

	RS.RenderStepped:Connect(function()
		ESP_C.Visible = S.ESP
		if not S.ESP then
			return
		end

		for _, p in pairs(P:GetPlayers()) do
			if p == LP then
				continue
			end

			local c = p.Character
			local h = c and c:FindFirstChild("Humanoid")
			local hrp = c and c:FindFirstChild("HumanoidRootPart")

			if not Cache[p] then
				local box = C("Frame", { BackgroundTransparency = 1, Parent = ESP_C })
				Cache[p] = {
					B = box,
					BO = C("UIStroke", { Thickness = S.Th, Parent = box }),
					Cr = MakeCorner(box),
					T = C("TextLabel", {
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamBold,
						TextSize = 11,
						TextStrokeTransparency = 0,
						Parent = ESP_C,
					}),
					WT = C("TextLabel", {
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamMedium,
						TextSize = 10,
						TextStrokeTransparency = 0,
						Parent = ESP_C,
					}),
					HB = C("Frame", { BackgroundColor3 = Color3.fromRGB(30, 30, 30), BorderSizePixel = 0, Parent = ESP_C }),
					HT = C("TextLabel", {
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamBold,
						TextSize = 9,
						TextStrokeTransparency = 0,
						TextXAlignment = Enum.TextXAlignment.Right,
						Parent = ESP_C,
					}),
					CHM = C("Highlight", {
						FillTransparency = 0.6,
						OutlineTransparency = 0.2,
						DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
						Parent = ParentGUI,
					}),
					Tr = Ln(),
					Sk = {},
				}
				C("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Parent = Cache[p].HB })
				Cache[p].HF = C("Frame", { BackgroundColor3 = Color3.new(0, 1, 0), BorderSizePixel = 0, Parent = Cache[p].HB })
				for _ = 1, #Bones do
					table.insert(Cache[p].Sk, Ln())
				end
			end

			local ch = Cache[p]
			local val = c and h and hrp and h.Health > 0 and (not S.Team or p.Team ~= LP.Team)

			if val then
				local cf, sz = c:GetBoundingBox()
				local dist = (Cam.CFrame.Position - cf.Position).Magnitude
				if dist > S.MaxDist then
					val = false
				end
			end

			if val then
				local cf, sz = c:GetBoundingBox()
				local dist = (Cam.CFrame.Position - cf.Position).Magnitude
				local ray = S.LoS and workspace:Raycast(Cam.CFrame.Position, hrp.Position - Cam.CFrame.Position, RaycastParams.new())
				local clr = GetColor(p, c, ray)

				if S.Chams then
					ch.CHM.Adornee = c
					ch.CHM.FillColor = clr
					ch.CHM.OutlineColor = clr
					ch.CHM.Enabled = true
				else
					ch.CHM.Enabled = false
				end

				local rp, onScreen = Cam:WorldToViewportPoint(cf.Position)
				if onScreen then
					local t2 = Cam:WorldToViewportPoint(cf.Position + Vector3.new(0, sz.Y / 2, 0))
					local b2 = Cam:WorldToViewportPoint(cf.Position - Vector3.new(0, sz.Y / 2, 0))
					local h2 = math.abs(t2.Y - b2.Y)
					local w2 = math.abs(t2.Y - b2.Y) * (sz.X / sz.Y)
					local bx, by = rp.X - w2 / 2, t2.Y

					if S.Box then
						ch.B.Size = UDim2.new(0, w2, 0, h2)
						ch.B.Position = UDim2.new(0, bx, 0, by)
						ch.B.Visible = true
						if S.BoxType == "Corner" then
							ch.BO.Enabled = false
							UpdCorner(ch.Cr, w2, h2, clr)
						else
							ch.BO.Enabled = true
							ch.BO.Color = clr
							ch.BO.Thickness = S.Th
							HideCorner(ch.Cr)
						end
					else
						ch.B.Visible = false
					end

					if S.Name then
						ch.T.Text = p.Name .. "  [" .. math.floor(dist) .. "m]"
						ch.T.Size = UDim2.new(0, w2 + 40, 0, 14)
						ch.T.Position = UDim2.new(0, bx - 20, 0, by - 16)
						ch.T.TextColor3 = clr
						ch.T.Visible = true
					else
						ch.T.Visible = false
					end

					if S.Weapon then
						local wpn = GetWeapon(c) or "None"
						ch.WT.Text = wpn
						ch.WT.Size = UDim2.new(0, w2 + 40, 0, 12)
						ch.WT.Position = UDim2.new(0, bx - 20, 0, by + h2 + 2)
						ch.WT.TextColor3 = Color3.fromRGB(200, 200, 210)
						ch.WT.Visible = true
					else
						ch.WT.Visible = false
					end

					if S.Health then
						local hpRatio = math.clamp(h.Health / h.MaxHealth, 0, 1)
						local hpClr = Color3.new(1, 0, 0):Lerp(Color3.new(0, 1, 0), hpRatio)
						ch.HB.Size = UDim2.new(0, 3, 0, h2)
						ch.HB.Position = UDim2.new(0, bx - 7, 0, by)
						ch.HF.Size = UDim2.new(1, 0, hpRatio, 0)
						ch.HF.Position = UDim2.new(0, 0, 1 - hpRatio, 0)
						ch.HF.BackgroundColor3 = hpClr
						ch.HB.Visible = true
					else
						ch.HB.Visible = false
					end

					if S.HealthText then
						local hp = math.floor(h.Health)
						local maxHp = math.floor(h.MaxHealth)
						ch.HT.Text = hp .. " HP"
						ch.HT.Size = UDim2.new(0, 36, 0, 12)
						ch.HT.Position = UDim2.new(0, bx - 44, 0, by + h2 / 2 - 6)
						ch.HT.TextColor3 = Color3.fromRGB(220, 220, 228)
						ch.HT.Visible = true
					else
						ch.HT.Visible = false
					end

					if S.Trace then
						local origin = Vector2.new(Cam.ViewportSize.X / 2, Cam.ViewportSize.Y)
						if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
							local mpos, mos = Cam:WorldToViewportPoint(LP.Character.HumanoidRootPart.Position)
							if mos then
								origin = Vector2.new(mpos.X, mpos.Y)
							end
						end
						UpdLn(ch.Tr, origin, Vector2.new(rp.X, b2.Y), clr)
					else
						ch.Tr.Visible = false
					end

					if S.Skel then
						for i, bn in ipairs(Bones) do
							local p1 = c:FindFirstChild(bn[1])
							local p2 = c:FindFirstChild(bn[2])
							if p1 and p2 then
								local p1_2, o1 = Cam:WorldToViewportPoint(p1.Position)
								local p2_2, o2 = Cam:WorldToViewportPoint(p2.Position)
								if o1 and o2 then
									UpdLn(ch.Sk[i], Vector2.new(p1_2.X, p1_2.Y), Vector2.new(p2_2.X, p2_2.Y), clr)
								else
									ch.Sk[i].Visible = false
								end
							else
								ch.Sk[i].Visible = false
							end
						end
					else
						for _, bn in pairs(ch.Sk) do
							bn.Visible = false
						end
					end
				else
					ch.B.Visible = false
					ch.T.Visible = false
					ch.WT.Visible = false
					ch.Tr.Visible = false
					ch.HB.Visible = false
					ch.HT.Visible = false
					for _, bn in pairs(ch.Sk) do
						bn.Visible = false
					end
				end
			else
				ch.B.Visible = false
				ch.T.Visible = false
				ch.WT.Visible = false
				ch.Tr.Visible = false
				ch.HB.Visible = false
				ch.HT.Visible = false
				ch.CHM.Enabled = false
				for _, bn in pairs(ch.Sk) do
					bn.Visible = false
				end
			end
		end
	end)

	P.PlayerRemoving:Connect(function(plr)
		local ch = Cache[plr]
		if not ch then
			return
		end
		ch.B:Destroy()
		ch.T:Destroy()
		ch.WT:Destroy()
		ch.HB:Destroy()
		ch.HT:Destroy()
		ch.CHM:Destroy()
		ch.Tr:Destroy()
		for _, bn in pairs(ch.Sk) do
			bn:Destroy()
		end
		Cache[plr] = nil
	end)
end

return ESP
