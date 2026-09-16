-- Player-facing runtime utilities shared by gameplay systems.
return function(statusEvent)
    local Runtime = {}

    function Runtime.leaderstat(player, name)
        local folder = player:FindFirstChild("leaderstats")
        return folder and folder:FindFirstChild(name)
    end

    function Runtime.sendStatus(player, message, kind)
        statusEvent:FireClient(player, message, kind or "Info")
    end

    function Runtime.canInteract(player, target, maximumDistance)
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid or humanoid.Health <= 0 or not target or not target.Parent then
            return false
        end
        return (root.Position - target.Position).Magnitude <= maximumDistance
    end

    function Runtime.teleportPlayer(player, destination)
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if root and humanoid and humanoid.Health > 0 then
            root.CFrame = CFrame.new(destination)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            return true
        else
            Runtime.sendStatus(player, "Your airship navigator is recalibrating. Try again in a moment.", "Warning")
            return false
        end
    end

    return Runtime
end
