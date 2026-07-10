-- Plik: workspace/Vanguard/ESP.lua

local ESP = {}

function ESP.Init(S, ParentGUI, TF, Util)
	local P = game:GetService("Players")
	local RS = game:GetService("RunService")
	local LP = P.LocalPlayer
	local Cam = workspace.CurrentCamera

	local Cache = {}
	local botList = {}
	local botScanAt = 0

	local Bones = {
		{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
		{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
		{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
		{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
		{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
		{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
	}

	local function C(class, props)
		local i = Instance.new(class)
		for k, v in pairs(props) do
			i[k] = v
		end
		return i
	end

	local ESP_C = C("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = ParentGUI })
	local Arrow_C = C("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = ParentGUI })
	local arrowCache = {}

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
			table.insert(cr, C("Frame", { BorderSizePixel = 0, Visible = false, Parent = parent }))
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
			cr[i].Size = UDim2.new(0, spec[3], 0, spec[4])
			cr[i].Position = UDim2.new(0, spec[1], 0, spec[2])
			cr[i].BackgroundColor3 = clr
			cr[i].Visible = true
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

	local function isBotModel(model)
		if not Util then
			return false
		end
		if LP.Character and model == LP.Character then
			return false
		end
		if P:GetPlayerFromCharacter(model) then
			return false
		end
		return Util.isValidTarget(model, nil)
	end

	local function refreshBots()
		if Util then
			Util.refreshBotList(botList, true, LP)
		else
			table.clear(botList)
		end
	end

	local function isBotKey(key)
		return typeof(key) == "Instance" and key:IsA("Model")
	end

	local function isTeammate(plr)
		return TF and TF.isTeammate(LP, plr)
	end

	local function shouldHidePlayer(plr, isBot)
		if TF then
			return TF.shouldHideESP(S, LP, plr, isBot)
		end
		return not isBot and S.Team and isTeammate(plr)
	end

	local losFrame = 0
	local losCache = {}   -- [key] = { frame, result }

	local function getLosKey(plr, char, isBot)
		if plr then return plr end
		if isBot and char then return char end
		return char
	end

	local function charHasLineOfSight(losKey, char)
		if not char or not losKey then
			return true
		end
		local cached = losCache[losKey]
		if cached and cached.frame == losFrame then
			return cached.result
		end
		local result = Util.charHasLineOfSight(Cam.CFrame.Position, char, LP.Character)
		losCache[losKey] = { frame = losFrame, result = result }
		return result
	end

	local function clearLosKey(key)
		losCache[key] = nil
	end

	local function pruneLosCacheIfNeeded()
		losFrame += 1
		if losFrame % 300 == 0 then
			for key in pairs(losCache) do
				local dead = false
				if typeof(key) == "Instance" then
					dead = key.Parent == nil
				end
				if dead then
					losCache[key] = nil
				end
			end
		end
	end

	local function GetColor(plr, c, isBot, distSq, losKey)
		if S.Chams and S.ChamsRainbow then
			return Rainbow()
		end
		losKey = losKey or getLosKey(plr, c, isBot)
		if isBot then
			if S.LoS and not charHasLineOfSight(losKey, c) then
				return S.O
			end
			return Color3.fromRGB(255, 180, 80)
		end
		if S.RealTeamColor and plr and plr.Team then
			return plr.Team.TeamColor.Color
		end
		if S.LoS and not charHasLineOfSight(losKey, c) then
			return S.O
		end
		return S.V
	end

	local function ensureCache(key)
		if Cache[key] then
			return Cache[key]
		end
		local box = C("Frame", { BackgroundTransparency = 1, Parent = ESP_C })
		Cache[key] = {
			B = box,
			BO = C("UIStroke", { Thickness = S.Th, Parent = box }),
			Cr = MakeCorner(box),
			T = C("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextStrokeTransparency = 0, Parent = ESP_C }),
			WT = C("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10, TextStrokeTransparency = 0, Parent = ESP_C }),
			HB = C("Frame", { BackgroundColor3 = Color3.fromRGB(30, 30, 30), BorderSizePixel = 0, Parent = ESP_C }),
			HT = C("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 9, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Right, Parent = ESP_C }),
			CHM = C("Highlight", { FillTransparency = 0.6, OutlineTransparency = 0.2, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = ParentGUI }),
			Tr = Ln(),
			Sk = {},
		}
		C("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Parent = Cache[key].HB })
		Cache[key].HF = C("Frame", { BackgroundColor3 = Color3.new(0, 1, 0), BorderSizePixel = 0, Parent = Cache[key].HB })
		for _ = 1, #Bones do
			table.insert(Cache[key].Sk, Ln())
		end
		return Cache[key]
	end

	local function hideAll(ch)
		if not ch then
			return
		end
		ch.B.Visible = false
		ch.T.Visible = false
		ch.WT.Visible = false
		ch.Tr.Visible = false
		ch.HB.Visible = false
		ch.HT.Visible = false
		ch.CHM.Enabled = false
		if ch.Cr then
			HideCorner(ch.Cr)
		end
		if ch.BO then
			ch.BO.Enabled = false
		end
		for _, bn in pairs(ch.Sk) do
			bn.Visible = false
		end
	end

	local function destroyCache(key)
		local ch = Cache[key]
		if not ch then
			return
		end
		pcall(function() ch.B:Destroy() end)
		pcall(function() ch.T:Destroy() end)
		pcall(function() ch.WT:Destroy() end)
		pcall(function() ch.HB:Destroy() end)
		pcall(function() ch.HT:Destroy() end)
		pcall(function() ch.CHM:Destroy() end)
		pcall(function() ch.Tr:Destroy() end)
		for _, bn in pairs(ch.Sk) do
			pcall(function() bn:Destroy() end)
		end
		Cache[key] = nil
	end

	local function hideAllCaches()
		for _, ch in pairs(Cache) do
			hideAll(ch)
		end
	end

	local function purgeBotCaches()
		for key in pairs(Cache) do
			if isBotKey(key) then
				destroyCache(key)
			end
		end
		table.clear(botList)
	end

	local function getEspMaxDist()
		if not S.ESPRenderLimit then
			return math.huge
		end
		return math.max(50, tonumber(S.ESPRenderDist) or 500)
	end

	local function renderEntity(key, c, plr, displayName, isBot, fastOnly)
		if not c or not c.Parent or not Util.isValidTarget(c, plr) then
			if Cache[key] then
				hideAll(Cache[key])
			end
			if isBot or not plr then
				destroyCache(key)
			end
			return
		end

		if shouldHidePlayer(plr, isBot) then
			if Cache[key] then
				hideAll(Cache[key])
			end
			return
		end

		local h = c:FindFirstChildOfClass("Humanoid")
		local hrp = Util and Util.resolveBodyPart(c, "HumanoidRootPart") or c:FindFirstChild("HumanoidRootPart")
		local ch = ensureCache(key)

		if not h or not hrp or h.Health <= 0 then
			hideAll(ch)
			return
		end

		local box = Util and Util.getEspBox(c, Cam)
		if not box then
			hideAll(ch)
			return
		end

		local dist = box.dist
		if dist > getEspMaxDist() then
			hideAll(ch)
			return
		end

		local distSq = dist * dist
		local losKey = getLosKey(plr, c, isBot)

		if S.ESPRenderOnlyVisible and not charHasLineOfSight(losKey, c) then
			hideAll(ch)
			return
		end

		local h2 = math.abs(box.topY - box.bottomY)
		local w2 = h2 * 0.55
		local bx, by = box.centerX - w2 / 2, box.topY
		local rp = Vector2.new(box.centerX, (box.topY + box.bottomY) / 2)

		-- Fast path: box position only (no LOS, skeleton, text). Runs 3/4 frames per player.
		if fastOnly and ch._lastClr then
			local clr = ch._lastClr
			if S.Box then
				ch.B.Size = UDim2.new(0, w2, 0, h2)
				ch.B.Position = UDim2.new(0, bx, 0, by)
				ch.B.Visible = true
				if S.BoxType == "Corner" then
					UpdCorner(ch.Cr, w2, h2, clr)
				else
					ch.BO.Enabled = true
					ch.BO.Color = clr
				end
			end
			if S.Chams and ch.CHM.Enabled then
				ch.CHM.FillColor = clr
				ch.CHM.OutlineColor = clr
			end
			return
		end

		local clr = GetColor(plr, c, isBot, distSq, losKey)
		ch._lastClr = clr

		if S.Chams then
			ch.CHM.Adornee = c
			ch.CHM.FillColor = clr
			ch.CHM.OutlineColor = clr
			ch.CHM.Enabled = true
		else
			ch.CHM.Enabled = false
		end

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
			HideCorner(ch.Cr)
			ch.BO.Enabled = false
		end

		local label = displayName or (plr and plr.Name) or c.Name
		if isBot then
			label = "[BOT] " .. label
		end

		if S.Name or S.DistView then
			local distStr = S.DistView and ("[" .. math.floor(dist) .. "m]") or ""
			if S.Name and S.DistView then
				ch.T.Text = label .. "  " .. distStr
			elseif S.Name then
				ch.T.Text = label
			else
				ch.T.Text = distStr
			end
			ch.T.Size = UDim2.new(0, w2 + 50, 0, 14)
			ch.T.Position = UDim2.new(0, bx - 25, 0, by - (S.Name and 16 or 8))
			ch.T.TextColor3 = clr
			ch.T.Visible = true
		else
			ch.T.Visible = false
		end

		if S.Weapon then
			ch.WT.Text = GetWeapon(c) or "None"
			ch.WT.Size = UDim2.new(0, w2 + 40, 0, 12)
			ch.WT.Position = UDim2.new(0, bx - 20, 0, by + h2 + 2)
			ch.WT.TextColor3 = Color3.fromRGB(200, 200, 210)
			ch.WT.Visible = true
		else
			ch.WT.Visible = false
		end

		if S.Health then
			local hpRatio = math.clamp(h.Health / h.MaxHealth, 0, 1)
			ch.HB.Size = UDim2.new(0, 3, 0, h2)
			ch.HB.Position = UDim2.new(0, bx - 7, 0, by)
			ch.HF.Size = UDim2.new(1, 0, hpRatio, 0)
			ch.HF.Position = UDim2.new(0, 0, 1 - hpRatio, 0)
			ch.HF.BackgroundColor3 = Color3.new(1, 0, 0):Lerp(Color3.new(0, 1, 0), hpRatio)
			ch.HB.Visible = true
		else
			ch.HB.Visible = false
		end

		if S.HealthText then
			ch.HT.Text = math.floor(h.Health) .. " HP"
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
			UpdLn(ch.Tr, origin, Vector2.new(rp.X, box.bottomY), clr)
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
	end

	local lastRenderBots = S.RenderBots
	local lastESP = S.ESP

	-- Performance: cap targets + stagger full-detail updates across frames.
	local espTick         = 0
	local DETAIL_SLOTS    = 2   -- full detail every 2 frames (~33ms lag) — was 4 (67ms lag)
	local MAX_ESP_TARGETS = 28
	local espTargets      = {}

	local function rebuildPlayerTargets()
		table.clear(espTargets)
		local camPos = Cam.CFrame.Position
		local maxDist = getEspMaxDist()
		for _, plr in ipairs(P:GetPlayers()) do
			if plr ~= LP then
				local c = plr.Character
				local hrp = c and c:FindFirstChild("HumanoidRootPart")
				if hrp then
					local dist = (camPos - hrp.Position).Magnitude
					if dist <= maxDist then
						table.insert(espTargets, {
							key = plr,
							char = c,
							plr = plr,
							name = plr.Name,
							bot = false,
							dist = dist,
							uid = plr.UserId,
						})
					end
				end
			end
		end
		if #espTargets > MAX_ESP_TARGETS then
			table.sort(espTargets, function(a, b) return a.dist < b.dist end)
			for i = #espTargets, MAX_ESP_TARGETS + 1, -1 do
				espTargets[i] = nil
			end
		end
	end

	local function getArrowConfig()
		local high = S.OffscreenArrowHighVis == true
		local scale = tonumber(S.OffscreenArrowScale) or (high and 1.35 or 1)
		scale = math.clamp(scale, 0.8, 2.5)
		return {
			highVis = high,
			scale = scale,
			showName = S.OffscreenArrowShowName ~= false,
			glyphSize = math.floor((high and 22 or 16) * scale),
			distSize = math.floor((high and 12 or 9) * scale),
			nameSize = math.floor((high and 10 or 8) * scale),
			rootW = math.floor((high and 78 or 32) * scale),
			rootH = math.floor((high and 62 or 36) * scale),
			margin = math.floor((high and 58 or 44) * scale),
		}
	end

	local function getOffscreenPlacement(worldPos, margin)
		margin = margin or 44
		local viewport = Cam.ViewportSize
		local cx, cy = viewport.X * 0.5, viewport.Y * 0.5
		local pos, onScreen = Cam:WorldToViewportPoint(worldPos)
		if onScreen and pos.Z > 0 and pos.X >= 0 and pos.X <= viewport.X and pos.Y >= 0 and pos.Y <= viewport.Y then
			return nil
		end

		local dir = Vector2.new(pos.X - cx, pos.Y - cy)
		if pos.Z <= 0 then
			if dir.Magnitude < 0.01 then
				dir = Vector2.new(0, 1)
			end
			dir = -dir.Unit
		elseif dir.Magnitude < 0.01 then
			dir = Vector2.new(0, -1)
		else
			dir = dir.Unit
		end

		local maxX = cx - margin
		local maxY = cy - margin
		local t = math.huge
		if dir.X > 0.001 then
			t = math.min(t, maxX / dir.X)
		elseif dir.X < -0.001 then
			t = math.min(t, -maxX / dir.X)
		end
		if dir.Y > 0.001 then
			t = math.min(t, maxY / dir.Y)
		elseif dir.Y < -0.001 then
			t = math.min(t, -maxY / dir.Y)
		end
		if t == math.huge then
			t = maxX
		end

		local edge = Vector2.new(cx, cy) + dir * t
		local angle = math.deg(math.atan2(dir.Y, dir.X)) + 90
		return edge, angle, dir
	end

	local function ensureArrow(key)
		if arrowCache[key] then
			return arrowCache[key]
		end
		local root = C("Frame", {
			Size = UDim2.new(0, 32, 0, 36),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = Arrow_C,
		})
		local rotWrap = C("Frame", {
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.new(0.5, 0, 0, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Parent = root,
		})
		local glyph = C("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "▲",
			Font = Enum.Font.GothamBlack,
			TextSize = 16,
			TextStrokeTransparency = 0.35,
			TextColor3 = S.V,
			Parent = rotWrap,
		})
		local stack = C("Frame", {
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.new(0.5, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			Parent = root,
		})
		local bg = C("Frame", {
			Size = UDim2.new(1, 8, 1, 6),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(8, 8, 12),
			BackgroundTransparency = 0.28,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 1,
			Parent = stack,
		})
		C("UICorner", { CornerRadius = UDim.new(0, 6), Parent = bg })
		C("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 1,
			Transparency = 0.72,
			Parent = bg,
		})
		local nameLbl = C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 12),
			Position = UDim2.new(0, 0, 0, 2),
			BackgroundTransparency = 1,
			Text = "",
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextStrokeTransparency = 0.5,
			TextColor3 = Color3.fromRGB(235, 235, 240),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 2,
			Visible = false,
			Parent = stack,
		})
		local distLbl = C("TextLabel", {
			Size = UDim2.new(1, 0, 0, 12),
			Position = UDim2.new(0, 0, 0, 14),
			BackgroundTransparency = 1,
			Text = "",
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			TextStrokeTransparency = 0.35,
			TextColor3 = Color3.fromRGB(220, 220, 228),
			ZIndex = 2,
			Parent = stack,
		})
		arrowCache[key] = {
			root = root,
			rotWrap = rotWrap,
			glyph = glyph,
			stack = stack,
			bg = bg,
			nameLbl = nameLbl,
			distLbl = distLbl,
		}
		return arrowCache[key]
	end

	local function applyArrowStyle(ch, cfg)
		ch.root.Size = UDim2.new(0, cfg.rootW, 0, cfg.rootH)
		ch.rotWrap.Size = UDim2.new(1, 0, 0, math.floor(cfg.glyphSize + 6))
		ch.glyph.TextSize = cfg.glyphSize
		ch.glyph.TextStrokeTransparency = cfg.highVis and 0.08 or 0.35
		ch.distLbl.TextSize = cfg.distSize
		ch.distLbl.TextStrokeTransparency = cfg.highVis and 0.05 or 0.35
		ch.nameLbl.TextSize = cfg.nameSize
		ch.nameLbl.TextStrokeTransparency = cfg.highVis and 0.1 or 0.45
		ch.bg.Visible = cfg.highVis
		local showName = cfg.showName and cfg.highVis
		ch.nameLbl.Visible = showName
		ch.distLbl.Position = UDim2.new(0, 0, 0, showName and 14 or 4)
		ch.stack.Size = UDim2.new(1, 0, 0, showName and 28 or 18)
	end

	local function purgeArrow(key)
		local ch = arrowCache[key]
		if ch then
			pcall(function() ch.root:Destroy() end)
			arrowCache[key] = nil
		end
	end

	local function hideArrow(key)
		local ch = arrowCache[key]
		if ch then
			ch.root.Visible = false
			ch.bg.Visible = false
			ch.nameLbl.Visible = false
			ch.glyph.Visible = false
			ch.distLbl.Visible = false
		end
	end

	local function hideAllArrows()
		for key in pairs(arrowCache) do
			hideArrow(key)
		end
	end

	local function purgeAllArrows()
		for key in pairs(arrowCache) do
			purgeArrow(key)
		end
	end

	local function renderOffscreen(key, worldPos, clr, dist, displayName)
		local cfg = getArrowConfig()
		local edge, angle = getOffscreenPlacement(worldPos, cfg.margin)
		if not edge then
			hideArrow(key)
			return
		end
		local ch = ensureArrow(key)
		applyArrowStyle(ch, cfg)
		ch.root.Position = UDim2.new(0, edge.X, 0, edge.Y)
		ch.root.Rotation = 0
		ch.rotWrap.Rotation = angle
		ch.glyph.TextColor3 = clr
		ch.glyph.Visible = true
		ch.distLbl.Text = math.floor(dist) .. "m"
		ch.distLbl.Visible = true
		ch.distLbl.TextColor3 = cfg.highVis and Color3.fromRGB(245, 245, 248) or clr
		if cfg.showName and cfg.highVis then
			ch.nameLbl.Text = tostring(displayName or "")
			ch.nameLbl.TextColor3 = clr
		else
			ch.nameLbl.Text = ""
		end
		ch.root.Visible = true
	end

	-- Lightweight per-frame timing via global Perf module.
	local perfWrap = _G.__VG_PERF and _G.__VG_PERF.wrap or function(_, fn) return fn end

	RS.RenderStepped:Connect(perfWrap("ESP.Main", function()
		pruneLosCacheIfNeeded()

		if not S.ESP then
			ESP_C.Visible = false
			Arrow_C.Visible = false
			if lastESP then
				hideAllCaches()
				purgeAllArrows()
			else
				hideAllArrows()
			end
			lastESP = false
			return
		end

		ESP_C.Visible = true
		Arrow_C.Visible = S.OffscreenArrows == true

		if lastRenderBots and not S.RenderBots then
			purgeBotCaches()
		end
		lastRenderBots = S.RenderBots

		espTick = espTick + 1
		local detailSlot = espTick % DETAIL_SLOTS

		local active = {}
		rebuildPlayerTargets()

		for _, t in ipairs(espTargets) do
			active[t.key] = true
			local fullDetail = (t.uid % DETAIL_SLOTS) == detailSlot or t.dist < 35
			renderEntity(t.key, t.char, t.plr, t.name, false, not fullDetail)
		end

		if S.RenderBots then
			if tick() - botScanAt > 5 then
				botScanAt = tick()
				refreshBots()
			end
			local i = 1
			while i <= #botList do
				local model = botList[i]
				if model.Parent and isBotModel(model) then
					active[model] = true
					local fullDetail = (i % DETAIL_SLOTS) == detailSlot
					renderEntity(model, model, nil, model.Name, true, not fullDetail)
					i += 1
				else
					destroyCache(model)
					table.remove(botList, i)
				end
			end
		else
			purgeBotCaches()
		end

		for key, ch in pairs(Cache) do
			if not active[key] then
				hideAll(ch)
				if isBotKey(key) then
					destroyCache(key)
				end
			end
		end

		if S.ESP and S.OffscreenArrows then
			local arrowActive = {}
			local function trackOffscreen(key, char, plr, isBot)
				if shouldHidePlayer(plr, isBot) then
					return
				end
				if not char or not Util.isValidTarget(char, plr) then
					return
				end
				local hum = char:FindFirstChildOfClass("Humanoid")
				local hrp = Util.resolveBodyPart(char, "HumanoidRootPart")
				if not hum or not hrp or hum.Health <= 0 then
					return
				end
				local dist = (Cam.CFrame.Position - hrp.Position).Magnitude
				if dist > getEspMaxDist() then
					return
				end
				if S.ESPRenderOnlyVisible then
					local losKey = getLosKey(plr, char, isBot)
					if not charHasLineOfSight(losKey, char) then
						return
					end
				end
				local cfg = getArrowConfig()
				local edge = getOffscreenPlacement(hrp.Position, cfg.margin)
				if edge then
					arrowActive[key] = true
					local ch = Cache[key]
					local clr = ch and ch._lastClr or S.V
					local label = plr and plr.Name or (char and char.Name or "?")
					pcall(renderOffscreen, key, hrp.Position, clr, dist, label)
				else
					hideArrow(key)
				end
			end

			for _, plr in pairs(P:GetPlayers()) do
				if plr ~= LP then
					trackOffscreen(plr, plr.Character, plr, false)
				end
			end
			if S.RenderBots then
				for _, model in ipairs(botList) do
					if model.Parent then
						trackOffscreen(model, model, nil, true)
					end
				end
			end
			for key in pairs(arrowCache) do
				if not arrowActive[key] then
					hideArrow(key)
				end
			end
		else
			hideAllArrows()
		end

		lastESP = true
	end))

	P.PlayerRemoving:Connect(function(plr)
		destroyCache(plr)
		purgeArrow(plr)
		clearLosKey(plr)
	end)
end

return ESP
