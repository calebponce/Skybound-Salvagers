-- Cosmetic only: no server transform replication or gameplay collisions.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local flyers = {}
local function register(model) flyers[model] = true end
CollectionService:GetInstanceAddedSignal("AmbientFlyer"):Connect(register)
CollectionService:GetInstanceRemovedSignal("AmbientFlyer"):Connect(function(model)
    flyers[model] = nil
end)
for _, model in ipairs(CollectionService:GetTagged("AmbientFlyer")) do register(model) end

local elapsed = 0
RunService.RenderStepped:Connect(function(delta)
    elapsed += delta
    if elapsed < 1 / 30 then return end
    elapsed = elapsed % (1 / 30)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local now = workspace:GetServerTimeNow()
    for model in pairs(flyers) do
        local origin = model:GetAttribute("FlightOrigin")
        local offset = model:GetAttribute("FlightOffset")
        local duration = model:GetAttribute("FlightDuration")
        -- Attributes/parts may arrive separately when an island streams in.
        if model.Parent and origin and offset and duration and duration > 0 then
            local side = Vector3.new(-offset.Z, 0, offset.X) * 0.12
            local angle = (now % (duration * 2)) * math.pi / duration
            local position = origin + offset * ((1 - math.cos(angle)) * 0.5) + side * math.sin(angle)
            local distance = (position - camera.CFrame.Position).Magnitude
            local fade = math.clamp((distance - 550) / 100, 0, 1)
            -- Hiding distant parts prevents a frozen bird/dragon being left at
            -- its last rendered position when transform updates are skipped.
            local parts = model:GetChildren()
            for _, part in ipairs(parts) do
                if part:IsA("BasePart") and part.LocalTransparencyModifier ~= fade then
                    part.LocalTransparencyModifier = fade
                end
            end
            if distance < 650 then
                local tangent = offset * (math.sin(angle) * 0.5) + side * math.cos(angle)
                local frame = CFrame.lookAt(position, position + tangent)
                local flap = math.sin(now * (model.Name == "CloudDrake" and 4 or 9) + duration) * 0.45
                for _, part in ipairs(parts) do
                    if part:IsA("BasePart") then
                        local rest = part:GetAttribute("FlightRest")
                        if rest then
                            if string.find(part.Name, "Wing") then
                                local p = rest.Position
                                local shoulder = p.X * 0.25
                                local sign = p.X < 0 and -1 or 1
                                part.CFrame = frame * CFrame.new(shoulder, p.Y, p.Z)
                                    * CFrame.Angles(0, 0, sign * flap)
                                    * CFrame.new(p.X - shoulder, 0, 0)
                            else
                                part.CFrame = frame * rest
                            end
                        end
                    end
                end
            end
        end
    end
end)
