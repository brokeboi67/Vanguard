-- Plik: workspace/Vanguard/Stealth.lua

local Stealth = {}

local HttpService = game:GetService("HttpService")

local Hidden = setmetatable({}, { __mode = "k" })
local HiddenRoots = setmetatable({}, { __mode = "k" })
local HooksReady = false
local BypassRef = nil

local FILTER_METHODS = {
	GetChildren = true,
	GetDescendants = true,
	FindFirstChild = true,
	FindFirstChildWhichIsA = true,
	FindFirstChildOfClass = true,
	FindFirstAncestor = true,
	FindFirstAncestorOfClass = true,
	FindFirstAncestorWhichIsA = true,
	waitForChild = true,
	WaitForChild = true,
}

local function isOurThread()
	if typeof(checkcaller) == "function" then
		local ok, ours = pcall(checkcaller)
		if ok and ours then
			return true
		end
	end
	return false
end

local function isHidden(inst)
	if not inst then
		return false
	end
	if Hidden[inst] then
		return true
	end
	local p = inst
	while p do
		if HiddenRoots[p] then
			return true
		end
		p = p.Parent
	end
	return false
end

local function filterList(list)
	if not list or #list == 0 then
		return list
	end
	if isOurThread() then
		return list
	end
	local out = table.create(#list)
	local n = 0
	for i = 1, #list do
		local v = list[i]
		if not isHidden(v) then
			n += 1
			out[n] = v
		end
	end
	for i = n + 1, #list do
		out[i] = nil
	end
	return out
end

local function filterOne(result)
	if isOurThread() then
		return result
	end
	if result and isHidden(result) then
		return nil
	end
	return result
end

function Stealth.uid()
	return "VG_" .. string.gsub(HttpService:GenerateGUID(false), "-", ""):sub(1, 16)
end

function Stealth.mark(inst, asRoot)
	if not inst then
		return
	end
	Hidden[inst] = true
	if asRoot then
		HiddenRoots[inst] = true
	end
	if inst.DescendantAdded then
		inst.DescendantAdded:Connect(function(desc)
			Hidden[desc] = true
		end)
	end
	for _, desc in ipairs(inst:GetDescendants()) do
		Hidden[desc] = true
	end
end

function Stealth.isHidden(inst)
	return isHidden(inst)
end

function Stealth.installHooks()
	if HooksReady then
		return true
	end
	if typeof(hookmetamethod) ~= "function" then
		return false
	end

	local oldNamecall
	oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
		local method = getnamecallmethod()
		local pack = { ... }
		if not isOurThread() then
			if FILTER_METHODS[method] then
				local ok, result = pcall(function()
					return oldNamecall(self, table.unpack(pack))
				end)
				if not ok then
					error(result, 0)
				end
				if method == "GetChildren" or method == "GetDescendants" then
					return filterList(result)
				end
				return filterOne(result)
			end
			if isHidden(self) then
				if method == "GetDebugId" then
					return tostring(math.random(100000000, 999999999))
				end
				if method == "IsA" then
					local className = pack[1]
					if className == "ScreenGui" or className == "GuiObject" or className == "LayerCollector" then
						return false
					end
				end
			end
		end
		return oldNamecall(self, ...)
	end)

	local oldIndex
	oldIndex = hookmetamethod(game, "__index", function(self, key)
		if not isOurThread() and isHidden(self) then
			if key == "Name" then
				return Stealth.uid()
			end
			if key == "ClassName" then
				return "Folder"
			end
		end
		return oldIndex(self, key)
	end)

	HooksReady = true
	return true
end

function Stealth.applyPropsAsync(inst, props, done)
	if not inst or not props then
		if done then
			done()
		end
		return
	end
	local keys = {}
	for k in pairs(props) do
		table.insert(keys, k)
	end
	local function sortKeys(a, b)
		local pa = a == "Parent" and 99 or 0
		local pb = b == "Parent" and 99 or 0
		if pa ~= pb then
			return pa < pb
		end
		return tostring(a) < tostring(b)
	end
	table.sort(keys, sortKeys)

	task.spawn(function()
		for i, key in ipairs(keys) do
			if key ~= "Parent" then
				pcall(function()
					inst[key] = props[key]
				end)
			end
			if i % 3 == 0 then
				task.wait(math.random(2, 8) / 1000)
			end
		end
		if props.Parent ~= nil then
			task.wait(math.random(4, 12) / 1000)
			pcall(function()
				inst.Parent = props.Parent
			end)
		end
		if done then
			done()
		end
	end)
end

function Stealth.create(className, props, opts)
	opts = opts or {}
	local inst = Instance.new(className)
	inst.Name = opts.name or Stealth.uid()
	Stealth.mark(inst, opts.root == true)

	local parent = props and props.Parent
	local copy = {}
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				copy[k] = v
			end
		end
	end

	if opts.async ~= false and (BypassRef and BypassRef.useAsyncProps ~= false) then
		copy.Parent = parent
		Stealth.applyPropsAsync(inst, copy)
	else
		for k, v in pairs(copy) do
			inst[k] = v
		end
		if parent ~= nil then
			inst.Parent = parent
		end
	end

	if parent and BypassRef then
		pcall(function()
			BypassRef.protectInstance(inst)
		end)
	end

	return inst
end

function Stealth.runLoader(fn)
	Stealth.installHooks()
	task.spawn(function()
		task.wait(math.random(8, 25) / 1000)
		local ok, err = pcall(fn)
		if not ok then
			warn("[VG] load:", err)
		end
	end)
end

function Stealth.silentPrint(msg)
	if not BypassRef or BypassRef.silentLoad ~= false then
		return
	end
	print(msg)
end

function Stealth.Init(bypassModule)
	BypassRef = bypassModule or {}
	BypassRef.useAsyncProps = BypassRef.useAsyncProps ~= false
	BypassRef.silentLoad = BypassRef.silentLoad ~= false
	Stealth.installHooks()
end

return Stealth
