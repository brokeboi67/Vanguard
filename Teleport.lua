-- Plik: workspace/Vanguard/Teleport.lua
-- Ponowne ładowanie po teleportacji w tej samej sesji gry (lobby -> mecz itd.).

local Teleport = {}

local LOADER_URL = "https://raw.githubusercontent.com/ihatelgbt2-art/Test/main/Main.lua"

local function loaderSnippet()
	return string.format('loadstring(game:HttpGet(%q))()', LOADER_URL)
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

function Teleport.apply(S)
	if not S then
		return false, "Brak ustawień"
	end

	local queue = resolveQueue()
	if not queue then
		return false, "Executor nie wspiera queue_on_teleport"
	end

	if S.TransferScript then
		local ok, err = pcall(queue, loaderSnippet())
		if not ok then
			return false, tostring(err)
		end
		return true
	end

	Teleport.clearQueue()
	return true
end

function Teleport.init(S, CoreRef)
	S.ApplyTransferScript = function()
		return Teleport.apply(S)
	end

	if S.TransferScript then
		Teleport.apply(S)
	end

	if CoreRef and typeof(CoreRef.registerCleanup) == "function" then
		CoreRef.registerCleanup(Teleport.clearQueue)
	end
end

return Teleport
