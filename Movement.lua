-- Plik: workspace/Vanguard/Movement.lua

local Movement = {}

function Movement.Init(S)
	local RS = game:GetService("RunService")
	local LP = game:GetService("Players").LocalPlayer

	RS.RenderStepped:Connect(function()
		if not S.BHop then
			return
		end

		local char = LP.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end

		if hum.MoveDirection.Magnitude < 0.08 then
			return
		end

		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.RunningNoPhysics
			or state == Enum.HumanoidStateType.Landed then
			hum.Jump = true
		end
	end)
end

return Movement
