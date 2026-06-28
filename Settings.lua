-- Plik: workspace/Vanguard/Settings.lua

local Settings = {
	Version = "2.3.1",
	-- ESP
	ESP = false,
	Box = false,
	BoxType = "Full",
	Name = false,
	DistView = true,
	Health = false,
	HealthText = false,
	Weapon = false,
	Skel = false,
	Trace = false,
	Chams = false,
	ChamsRainbow = false,
	RenderBots = false,
	Team = false,
	RealTeamColor = true,
	LoS = false,
	MaxDist = 500,
	Th = 1.5,
	V = Color3.fromRGB(0, 255, 150),
	O = Color3.fromRGB(255, 50, 50),

	-- AIM
	Aimbot = false,
	Silent = false,
	Trigger = false,
	TriggerKey = "V",
	TriggerMode = "Hold",
	TriggerDelay = 100,
	ShowTriggerHud = true,
	TriggerHudMinimal = true,
	VisibleCheck = true,
	ShowFOV = true,
	FOV = 80,
	Smooth = 0.4,
	AimCurve = true,
	TargetMode = "FOV",
	HitPart = "Head",
	AimBots = true,

	-- MOVEMENT
	BHop = false,

	-- HUD
	Crosshair = false,
	CrosshairSize = 5,
	Spectators = false,
	Hitmarker = false,
	DamageLog = false,

	-- UI runtime
	MenuOpen = false,
	LastShotAt = 0,
	LastShotHum = nil,
}

return Settings
