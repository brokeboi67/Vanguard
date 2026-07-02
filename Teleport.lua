-- Plik: workspace/Vanguard/Teleport.lua
-- Ponowne ładowanie po teleportacji w tej samej sesji gry (lobby -> mecz itd.).

local Teleport = {}

local LOADER_URL = "https://raw.githubusercontent.com/ihatelgbt2-art/Test/main/Main.lua"
local SKIP_PATH = "Vanguard/skip_transfer"

local function canPersist()
	return typeof(writefile) == "function" and typeof(isfile) == "function"
end

local function loaderSnippet()
	local gameId = game.GameId
	return string.format(
		[[
local EXPECTED_GAME = %d
local SKIP_PATH = %q
local LOADER = %q

local function shouldLoad()
	if game.GameId ~= EXPECTED_GAME then
		return false
	end
	if isfile and isfile(SKIP_PATH) then
		pcall(delfile, SKIP_PATH)
		return false
	end
	local Players = game:GetService("Players")
	local LP = Players.LocalPlayer
	if not LP then
		LP = Players.PlayerAdded:Wait()
	end
	task.wait(0.15)
	local okJoin, joinData = pcall(function()
		return LP:GetJoinData()
	end)
	if not okJoin or typeof(joinData) ~= "table" then
		return false
	end
	local srcPlace = joinData.SourcePlaceId or 0
	local srcGame = joinData.SourceGameId or 0
	if srcPlace > 0 then
		return true
	end
	if srcGame > 0 and srcGame == EXPECTED_GAME then
		return true
	end
	return false
end

if not shouldLoad() then
	return
end
_G.VG_FROM_TRANSFER = true
loadstring(game:HttpGet(LOADER))()
]],
		gameId,
		SKIP_PATH,
		LOADER_URL
	)
end

local function resolveQueue()
	if typeof(queue_on_teleport) == "function" then
		return queue_on_teleport
	end
	if typeof(syn) == "table" and typeof(syn.queue_on_teleport) == "function" then
		return syn.queue_on_teleport
	end
	if typeof(fluxus) == "table" and typeof(fluxus.queue_on_teleport) == "function" then
		return fluxus.queue_on_teleport
	end
	return nil
end

local function resolveClear()
	if typeof(clrtppqueue) == "function" then
		return clrtppqueue
	end
	if typeof(syn) == "table" and typeof(syn.clear_teleport_queue) == "function" then
		return syn.clear_teleport_queue
	end
	if typeof(fluxus) == "table" and typeof(fluxus.clear_teleport_queue) == "function" then
		return fluxus.clear_teleport_queue
	end
	return nil
end

function Teleport.isSupported()
	return resolveQueue() ~= nil
end

function Teleport.clearQueue()
	local clr = resolveClear()
	if clr then
		pcall(clr)
	end
end

function Teleport.markManualLeave()
	Teleport.clearQueue()
	if not canPersist() then
		return
	end
	pcall(function()
		if typeof(makefolder) == "function" then
			makefolder("Vanguard")
		end
		writefile(SKIP_PATH, "1")
	end)
end

function Teleport.apply(S)
	if not S then
		return false, "Brak ustawień"
	end

	local queue = resolveQueue()
	if not queue then
		return false, "Executor nie wspiera queue_on_teleport"
	end

	if S.TransferScript then
		if canPersist() and isfile(SKIP_PATH) then
			pcall(delfile, SKIP_PATH)
		end
		local ok, err = pcall(queue, loaderSnippet())
		if not ok then
			return false, tostring(err)
		end
		return true
	end

	Teleport.clearQueue()
	return true
end

function Teleport.init(S, CoreRef, isTransferLoad)
	S.ApplyTransferScript = function()
		return Teleport.apply(S)
	end

	S.MarkManualLeave = Teleport.markManualLeave

	if S.TransferScript and isTransferLoad then
		Teleport.apply(S)
	end

	if CoreRef and typeof(CoreRef.registerCleanup) == "function" then
		CoreRef.registerCleanup(function()
			Teleport.markManualLeave()
		end)
	end
end

return Teleport
