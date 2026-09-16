-- Shared co-op expedition state. This owns membership, crate progress, and the
-- in-world board so the world builder only needs to provide the interaction.
return function(dependencies)
    local CrewExpedition = {}
    local members = {}
    local progress = 0
    local activeGoal

    local function getPlayers()
        local players = {}
        for userId in pairs(members) do
            local player = dependencies.Players:GetPlayerByUserId(userId)
            if player then table.insert(players, player) end
        end
        return players
    end

    local function goal()
        return activeGoal or math.max(dependencies.Config.CrewGoalBase, #getPlayers() * dependencies.Config.CrewSuppliesPerMember)
    end

    function CrewExpedition:IsMember(player)
        return members[player.UserId] == true
    end

    function CrewExpedition:GetPlayers()
        return getPlayers()
    end

    function CrewExpedition:Sync()
        local players = getPlayers()
        local memberCount = #players
        local expeditionGoal = goal()
        dependencies.Remotes:SetAttribute("CrewProgress", progress)
        dependencies.Remotes:SetAttribute("CrewGoal", expeditionGoal)
        dependencies.Remotes:SetAttribute("CrewMemberCount", memberCount)

        local board = dependencies.FindBoard()
        if not board then return end
        board.Color = memberCount > 0 and dependencies.Theme.Aqua:Lerp(dependencies.Theme.PanelRaised, 0.5) or dependencies.Theme.PanelRaised
        local gui = board:FindFirstChildOfClass("BillboardGui")
        local label = gui and gui:FindFirstChildOfClass("TextLabel")
        if label then
            label.Text = memberCount > 0
                and ("CREW EXPEDITION\n" .. memberCount .. " / " .. dependencies.Config.CrewMaxMembers .. "  •  " .. progress .. " / " .. expeditionGoal .. " CRATES  •  +" .. dependencies.Config.CrewReward .. " EACH")
                or "CREW EXPEDITION\nJOIN • +" .. dependencies.Config.CrewReward .. " SALVAGE EACH"
        end
        local light = board:FindFirstChild("CrewBoardLight") or Instance.new("PointLight")
        light.Name = "CrewBoardLight"
        light.Color = dependencies.Theme.Aqua
        light.Range = 10
        light.Brightness = memberCount > 0 and 1.2 or 0
        light.Parent = board
    end

    function CrewExpedition:ToggleMembership(player)
        if self:IsMember(player) then
            members[player.UserId] = nil
            player:SetAttribute("InCrew", false)
            self:Sync()
            return false
        end
        if #getPlayers() >= dependencies.Config.CrewMaxMembers then
            return nil, "This Crew Expedition is full. A maximum of " .. dependencies.Config.CrewMaxMembers .. " deckhands can share its rewards."
        end
        members[player.UserId] = true
        player:SetAttribute("InCrew", true)
        self:Sync()
        return true
    end

    function CrewExpedition:CelebrateCompletion()
        local board = dependencies.FindBoard()
        if not board then return end
        local light = board:FindFirstChild("CrewBoardLight")
        local originalSize = board.Size
        board.Color = dependencies.Theme.Gold
        if light then
            light.Color = dependencies.Theme.Gold
            light.Brightness = 3.4
        end
        dependencies.TweenService:Create(board, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = originalSize + Vector3.new(0.5, 0.7, 0.5),
        }):Play()
        task.delay(0.34, function()
            if board.Parent then
                dependencies.TweenService:Create(board, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = originalSize,
                }):Play()
            end
        end)
        task.delay(0.72, function()
            if board.Parent then self:Sync() end
        end)
    end

    function CrewExpedition:Remove(player)
        if not self:IsMember(player) then return end
        members[player.UserId] = nil
        self:Sync()
    end

    function CrewExpedition:RegisterRecovery(player)
        if not self:IsMember(player) then return false end
        -- Freeze the objective on the first recovery, until this round pays out.
        -- Membership changes must not erase progress or move the finish line.
        activeGoal = goal()
        progress = progress + 1
        local expeditionGoal = goal()
        if progress < expeditionGoal then
            self:Sync()
            return false
        end

        progress = 0
        activeGoal = nil
        for _, teammate in ipairs(getPlayers()) do
            dependencies.SetSalvage(teammate, dependencies.GetSalvage(teammate) + dependencies.Config.CrewReward)
            dependencies.SendStatus(teammate, "Crew Expedition cache recovered! Everyone earns +" .. dependencies.Config.CrewReward .. " salvage.", "Success")
        end
        self:Sync()
        self:CelebrateCompletion()
        return true
    end

    return CrewExpedition
end
