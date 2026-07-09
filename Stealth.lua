-- Plik: workspace/Vanguard/Stealth.lua
-- Bezpieczny stealth BEZ globalnych hookmetamethod (powodowały freeze całego klienta).

local Stealth = {}

local HttpService = game:GetService("HttpService")
local BypassRef = nil

function Stealth.uid()
	local raw = string.gsub(HttpService:GenerateGUID(false), "-", "")
	local out = {}
	for i = 1, math.min(#raw, 14) do
		local c = raw:sub(i, i)
		if c:match("[%w]") then
			out[#out + 1] = c
		end
	end
	if #out < 8 then
		return "Ui" .. HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 10)
	end
	return table.concat(out)
end

function Stealth.mark(_inst, _asRoot)
	-- Rejestr zarezerwowany pod przyszłe rozszerzenia; bez hooków reflection.
end

function Stealth.isHidden(_inst)
	return false
end

function Stealth.installHooks()
	-- Celowo wyłączone — globalne hooki __namecall/__index lagują / freezują Roblox.
	return false
end

function Stealth.create(className, props, opts)
	opts = opts or {}
	local inst = Instance.new(className)
	inst.Name = opts.name or Stealth.uid()

	if BypassRef and BypassRef.protectInstance and className == "ScreenGui" then
		pcall(function()
			BypassRef.protectInstance(inst)
		end)
	end

	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				pcall(function()
					inst[k] = v
				end)
			end
		end
		if props.Parent ~= nil and not inst.Parent then
			if BypassRef and BypassRef.protectInstance then
				pcall(function()
					BypassRef.protectInstance(inst)
				end)
				if not inst.Parent then
					inst.Parent = props.Parent
				end
			else
				inst.Parent = props.Parent
			end
		end
	end

	return inst
end

function Stealth.runLoader(fn)
	task.defer(function()
		local ok, err = pcall(fn)
		if not ok then
			warn("[VG] load:", err)
		end
	end)
end

function Stealth.silentPrint(msg)
	if BypassRef and BypassRef.silentLoad == false then
		print(msg)
	end
end

function Stealth.Init(bypassModule)
	BypassRef = bypassModule or {}
	BypassRef.silentLoad = BypassRef.silentLoad ~= false
end

return Stealth
