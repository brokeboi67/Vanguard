-- Plik: workspace/Vanguard/Settings.lua

local Settings = {
	Version = "2.11.2",
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
	ExcludeTeam = true,
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

	-- RAGE
	MasterRage = false,
	AntiAim = false,
	AASpin = true,
	AASpinSpeed = 8,
	AAYaw = 0,
	AAPitch = 0,
	AAJitter = false,
	AAJitterRange = 45,
	RageBot = false,
	RageKey = "C",
	RageMode = "Toggle",
	RageDelay = 80,
	ShowRageHud = true,
	RageHudMinimal = true,
	RageHitPart = "Head",
	RageVisibleCheck = true,
	RageBots = true,
	RageMaxDist = 500,
	RageAimMode = "Silent",
	RageTrackSmooth = 0.35,

	-- WORLD
	FullBright = false,
	NoFog = false,
	WorldTimeLock = false,
	WorldTime = 14,
	WorldCustomLight = false,
	WorldColorHue = 0.55,
	WorldColorSat = 0.35,
	MenuBlur = true,
	MenuBlurSize = 18,

	-- MOVEMENT
	BHop = false,
	AutoStrafe = false,

	-- HUD
	Crosshair = false,
	CrosshairSize = 5,
	Spectators = false,
	Hitmarker = false,
	DamageLog = false,
	Watermark = false,
	KeybindList = false,
	SessionStats = false,
	KillFeed = false,
	HitSound = true,
	HitSoundVolume = 0.45,

	-- FRIENDS
	FriendClick = true,
	FriendIds = {},

	-- MISC
	HeadSize = false,
	HeadSizeScale = 2,
	HitboxSize = false,
	HitboxSizeScale = 1.5,
	MiscAffectFriends = false,
	MiscBots = true,
	AntiBypass = true,

	-- EFFECTS (local only)
	KillEffects = false,
	KillEffectStyle = "Neon",
	HitEffects = false,
	HitEffectStyle = "Lightning",
	SelfKillFX = false,

	-- UI runtime
	MenuOpen = false,
	LastShotAt = 0,
	LastShotHum = nil,
	LastShotChar = nil,
}

return Settings
