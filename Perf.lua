-- Perf.lua — global frame profiler for all Vanguard modules.
-- Usage: RS.RenderStepped:Connect(_G.__VG_PERF.wrap("ESP.Main", function() ... end))

local Perf = {}

Perf.INTERVAL = 30   -- seconds between log reports

local stats      = {}   -- [name] = { tot, cnt, max }
local lastReport = os.clock()

function Perf.wrap(name, fn)
	if typeof(fn) ~= "function" then
		return fn
	end
	return function(...)
		local s = stats[name]
		if not s then
			s = { tot = 0, cnt = 0, max = 0 }
			stats[name] = s
		end
		local t0 = os.clock()
		fn(...)
		local dt = os.clock() - t0
		s.tot = s.tot + dt
		s.cnt = s.cnt + 1
		if dt > s.max then
			s.max = dt
		end
		Perf.maybeReport()
	end
end

function Perf.maybeReport()
	local now = os.clock()
	if now - lastReport < Perf.INTERVAL then
		return
	end
	lastReport = now

	local rows = {}
	for name, s in pairs(stats) do
		if s.cnt > 0 then
			table.insert(rows, {
				name = name,
				avg  = s.tot / s.cnt * 1000,
				max  = s.max * 1000,
				cnt  = s.cnt,
			})
			s.tot, s.cnt, s.max = 0, 0, 0
		end
	end

	if #rows == 0 then
		return
	end

	table.sort(rows, function(a, b)
		return a.avg > b.avg
	end)

	local lines = { string.format("[VG:PERF] last %ds:", Perf.INTERVAL) }
	for _, r in ipairs(rows) do
		table.insert(lines, string.format(
			"  %-28s avg=%.3fms  max=%.3fms  n=%d",
			r.name, r.avg, r.max, r.cnt
		))
	end

	local report = table.concat(lines, "\n")
	warn(report)
	if typeof(_G.__VG_LOG_FILE) == "function" then
		_G.__VG_LOG_FILE("PERF", report)
	end
end

return Perf
