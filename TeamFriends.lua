-- Plik: workspace/Vanguard/TeamFriends.lua

local TeamFriends = {}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local initDone = false

function TeamFriends.isTeammate(LP, plr)
	return plr and plr.Team and LP.Team and plr.Team == LP.Team
end

function TeamFriends.isFriend(S, plr)
	if not plr then
		return false
	end
	local ids = S.FriendIds
	if typeof(ids) ~= "table" then
		return false
	end
	local uid = plr.UserId
	for _, id in ipairs(ids) do
		if id == uid then
			return true
		end
	end
	return false
end

function TeamFriends.shouldExclude(S, LP, plr)
	if not plr then
		return false
	end
	if TeamFriends.isFriend(S, plr) then
		return true
	end
	if S.ExcludeTeam and TeamFriends.isTeammate(LP, plr) then
		return true
	end
	return false
end

function TeamFriends.shouldHideESP(S, LP, plr, isBot)
	if isBot or not plr then
		return false
	end
	if TeamFriends.isFriend(S, plr) then
		return true
	end
	if S.Team and TeamFriends.isTeammate(LP, plr) then
		return true
	end
	return false
end

function TeamFriends.ensureFriendIds(S)
	if typeof(S.FriendIds) ~= "table" then
		S.FriendIds = {}
	end
	return S.FriendIds
end

function TeamFriends.toggleFriend(S, plr)
	if not plr then
		return false
	end
	local ids = TeamFriends.ensureFriendIds(S)
	local uid = plr.UserId
	for i, id in ipairs(ids) do
		if id == uid then
			table.remove(ids, i)
			return false
		end
	end
	table.insert(ids, uid)
	return true
end

function TeamFriends.removeFriend(S, userId)
	local ids = TeamFriends.ensureFriendIds(S)
	for i, id in ipairs(ids) do
		if id == userId then
			table.remove(ids, i)
			return true
		end
	end
	return false
end

function TeamFriends.clearFriends(S)
	S.FriendIds = {}
end

function TeamFriends.getFriendPlayers(S)
	local out = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if TeamFriends.isFriend(S, plr) then
			table.insert(out, plr)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

local function getPlayerFromInstance(inst)
	if not inst then
		return nil
	end
	local model = inst:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

function TeamFriends.Init(S, ParentGUI, accent, onFriendChanged)
	if initDone then
		return
	end
	initDone = true

	local LP = Players.LocalPlayer
	local ACC = accent or Color3.fromRGB(0, 255, 150)

	local CG = pcall(function() return game:GetService("CoreGui").Name end)
		and game:GetService("CoreGui")
		or LP:WaitForChild("PlayerGui")
	pcall(function() CG.VanguardFriendPopup:Destroy() end)

	local function C(class, props)
		local i = Instance.new(class)
		for k, v in pairs(props) do
			i[k] = v
		end
		return i
	end

	local PopGui = C("ScreenGui", {
		Name = "VG_" .. string.sub(game:GetService("HttpService"):GenerateGUID(false), 1, 8),
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 999997,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = CG,
	})

	local PopupRoot = C("Frame", {
		Name = "FriendPopupRoot",
		Size = UDim2.new(0, 280, 0, 72),
		Position = UDim2.new(0.5, -140, 0, 56),
		BackgroundTransparency = 1,
		ZIndex = 95,
		Parent = PopGui,
	})

	local PopupCard = C("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		ZIndex = 96,
		Parent = PopupRoot,
	})
	C("UICorner", { CornerRadius = UDim.new(0, 10), Parent = PopupCard })
	local popupStroke = C("UIStroke", {
		Color = ACC,
		Thickness = 1,
		Transparency = 0.25,
		Parent = PopupCard,
	})

	local Avatar = C("ImageLabel", {
		Size = UDim2.new(0, 44, 0, 44),
		Position = UDim2.new(0, 12, 0.5, -22),
		BackgroundColor3 = Color3.fromRGB(28, 28, 34),
		BorderSizePixel = 0,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 97,
		Parent = PopupCard,
	})
	C("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Avatar })

	PopupRoot.Visible = false

	local TitleLbl = C("TextLabel", {
		Size = UDim2.new(1, -72, 0, 16),
		Position = UDim2.new(0, 64, 0, 14),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(235, 235, 242),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 97,
		Parent = PopupCard,
	})

	local SubLbl = C("TextLabel", {
		Size = UDim2.new(1, -72, 0, 14),
		Position = UDim2.new(0, 64, 0, 32),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextColor3 = ACC,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 97,
		Parent = PopupCard,
	})

	local function showFriendPopup(plr, added)
		if not plr then
			return
		end

		TitleLbl.Text = plr.DisplayName or plr.Name
		if added then
			SubLbl.Text = "Dodano do wykluczeń"
			SubLbl.TextColor3 = ACC
			popupStroke.Color = ACC
		else
			SubLbl.Text = "Usunięto z wykluczeń"
			SubLbl.TextColor3 = Color3.fromRGB(160, 160, 170)
			popupStroke.Color = Color3.fromRGB(90, 90, 100)
		end

		Avatar.Image = string.format(
			"https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=48&height=48&format=png",
			plr.UserId
		)
		Avatar.ImageTransparency = 0
		TitleLbl.TextTransparency = 0
		SubLbl.TextTransparency = 0
		PopupCard.BackgroundTransparency = 0.06

		PopupRoot.Visible = true
		PopupRoot.Position = UDim2.new(0.5, -140, 0, 48)
		TS:Create(PopupRoot, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, -140, 0, 56),
		}):Play()

		task.delay(2.5, function()
			if not PopupRoot.Parent then
				return
			end
			local tw = TS:Create(PopupRoot, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, -140, 0, 44),
			})
			tw:Play()
			tw.Completed:Wait()
			PopupRoot.Visible = false
		end)
	end

	TeamFriends.showFriendPopup = showFriendPopup

	local mouse = LP:GetMouse()

	UIS.InputBegan:Connect(function(input, processed)
		if processed or S.MenuOpen then
			return
		end
		if not S.FriendClick then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local ctrl = UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)
		if not ctrl then
			return
		end

		task.defer(function()
			local plr = getPlayerFromInstance(mouse.Target)
			if not plr or plr == LP then
				return
			end
			local added = TeamFriends.toggleFriend(S, plr)
			showFriendPopup(plr, added)
			if onFriendChanged then
				onFriendChanged()
			end
		end)
	end)
end

return TeamFriends
