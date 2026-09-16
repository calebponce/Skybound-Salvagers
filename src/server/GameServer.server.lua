-- Skybound Salvagers vertical-slice server.
-- Builds a playable prototype world at runtime so the project only needs a blank Baseplate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = Config.Theme
local WorldPrimitives = require(script.Parent:WaitForChild("WorldPrimitives"))(Theme.Cloud)
local createPart = WorldPrimitives.createPart
local addBillboard = WorldPrimitives.addBillboard
local addPrompt = WorldPrimitives.addPrompt
local CrewExpedition = require(script.Parent:WaitForChild("CrewExpedition"))
local GuardianAttack = require(script.Parent:WaitForChild("GuardianAttack"))
local ProgressData = require(script.Parent:WaitForChild("ProgressData"))
-- DataStores are unavailable in an unpublished local place. Keep the prototype
-- immediately playable in Studio and enable persistence automatically after publish.
local dataStore
local dataStoreAvailable = pcall(function()
    dataStore = DataStoreService:GetDataStore(Config.DataStoreName)
end)

local playerData = {}
local plots = {}
local usedPlots = {}
local playerPlots = {}
local refreshHarborProgress
local pulseSanctuary
-- Harbor prompt callbacks are created before the travel implementation below.
local travelToBiome
local stormActive = false
local stormCompleted = false
local stormProgress = 0
local stormGoal = 0
local stormEndsAt = 0
local guestBookEntries = {}
local discoveryChains = {}
local voidRescueCooldowns = {}
local biomePositions = {
    [2] = Vector3.new(260, 24, 0),
    [3] = Vector3.new(-260, 24, 0),
}

local remotes = Instance.new("Folder")
remotes.Name = "SkyboundRemotes"
remotes.Parent = ReplicatedStorage

local statusEvent = Instance.new("RemoteEvent")
statusEvent.Name = "Status"
statusEvent.Parent = remotes

local crewMateEvent = Instance.new("RemoteEvent")
crewMateEvent.Name = "ChooseCrewMate"
crewMateEvent.Parent = remotes

local guideEvent = Instance.new("RemoteEvent")
guideEvent.Name = "OpenIslandGuide"
guideEvent.Parent = remotes

local returnHomeEvent = Instance.new("RemoteEvent")
returnHomeEvent.Name = "ReturnToHarbor"
returnHomeEvent.Parent = remotes
local PlayerRuntime = require(script.Parent:WaitForChild("PlayerRuntime"))(statusEvent)
local leaderstat = PlayerRuntime.leaderstat
local sendStatus = PlayerRuntime.sendStatus
local teleportPlayer = PlayerRuntime.teleportPlayer

remotes:SetAttribute("StormActive", false)
remotes:SetAttribute("StormProgress", 0)
remotes:SetAttribute("StormGoal", 0)
remotes:SetAttribute("StormEndsAt", 0)
remotes:SetAttribute("CrewProgress", 0)
remotes:SetAttribute("CrewGoal", Config.CrewGoalBase)
remotes:SetAttribute("CrewMemberCount", 0)

local function setSalvage(player, amount)
    local data = playerData[player]
    if not data then return end
    data.Salvage = math.max(0, amount)
    local stat = leaderstat(player, "Salvage")
    if stat then stat.Value = data.Salvage end
    if refreshHarborProgress then refreshHarborProgress(player) end
end

local function crewMateFor(player)
    local data = playerData[player]
    return data and Config.crewMateById(data.CrewMate)
end

local function applyCrewMateVisual(player, character)
    if not character then return end
    local existing = character:FindFirstChild("CrewMateAccent")
    if existing then existing:Destroy() end
    local mate = crewMateFor(player)
    if not mate then return end
    local accent = Theme[mate.Accent] or Theme.Aqua
    local highlight = Instance.new("Highlight")
    highlight.Name = "CrewMateAccent"
    highlight.Adornee = character
    highlight.FillColor = accent
    highlight.FillTransparency = 0.94
    highlight.OutlineColor = accent:Lerp(Theme.Text, 0.18)
    highlight.OutlineTransparency = 0.38
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = character
end

local function salvageRewardFor(player, value, isStorm)
    local mate = crewMateFor(player)
    local bonus = mate and (isStorm and mate.StormBonus or mate.NormalBonus) or 0
    local data = playerData[player]
    local level = (data and data.ExplorerLevel) or 1
    local skylingBonus = data and Config.skylingSalvageBonus(data.SkylingsRescued) or 0
    local trainingBonus = data and data.CrewTrainingLevel or 0
    return math.max(1, math.floor((value + bonus) * Config.explorerSalvageMultiplier(level) + 0.5) + skylingBonus + trainingBonus)
end

local function upgradeCostFor(player, level)
    local mate = crewMateFor(player)
    local multiplier = mate and mate.UpgradeMultiplier or 1
    return math.ceil(Config.upgradeCost(level) * multiplier)
end

local function setLevel(player, amount)
    local data = playerData[player]
    if not data then return end
    data.HarborLevel = amount
    local stat = leaderstat(player, "Harbor Level")
    if stat then stat.Value = amount end
end

local crew = CrewExpedition({
    Players = Players,
    Remotes = remotes,
    Config = Config,
    Theme = Theme,
    TweenService = TweenService,
    SetSalvage = setSalvage,
    GetSalvage = function(player)
        local data = playerData[player]
        return data and data.Salvage or 0
    end,
    SendStatus = sendStatus,
    FindBoard = function()
        local world = workspace:FindFirstChild("SkyboundWorld")
        local expedition = world and world:FindFirstChild("WhisperingWreck")
        return expedition and expedition:FindFirstChild("CrewBoard")
    end,
})

local function syncStormState()
    remotes:SetAttribute("StormActive", stormActive)
    remotes:SetAttribute("StormProgress", stormProgress)
    remotes:SetAttribute("StormGoal", stormGoal)
    remotes:SetAttribute("StormEndsAt", stormEndsAt)
end

local function currentDay()
    return math.floor(os.time() / 86400)
end

local function nextDailyStreak(data, today)
    if data.LastDailyClaimDay == today - 1 then
        return math.min(data.DailyStreak + 1, Config.DailyRewardStreakMax)
    end
    return 1
end

local function syncAdventure(player)
    local data = playerData[player]
    if not data then return end
    local today = currentDay()
    local dailyReady = data.LastDailyClaimDay ~= today
    local upcomingStreak = dailyReady and nextDailyStreak(data, today) or data.DailyStreak
    player:SetAttribute("ContractProgress", data.ContractProgress)
    player:SetAttribute("FirstFlightComplete", data.FirstFlightComplete)
    player:SetAttribute("ContractGoal", Config.ContractGoal)
    player:SetAttribute("RescueBeacons", data.RescueBeacons)
    player:SetAttribute("SkylingsRescued", data.SkylingsRescued)
    player:SetAttribute("HarborVisits", data.HarborVisits)
    player:SetAttribute("CrewMate", data.CrewMate)
    player:SetAttribute("ExplorerXP", data.ExplorerXP)
    player:SetAttribute("ExplorerNextXP", Config.explorerXpForLevel(data.ExplorerLevel))
    player:SetAttribute("ExplorerBonusPercent", math.floor((Config.explorerSalvageMultiplier(data.ExplorerLevel) - 1) * 100 + 0.5))
    player:SetAttribute("ExplorerTitle", Config.explorerTitleForLevel(data.ExplorerLevel))
    player:SetAttribute("SkylingBonus", Config.skylingSalvageBonus(data.SkylingsRescued))
    player:SetAttribute("CrewTrainingLevel", data.CrewTrainingLevel)
    player:SetAttribute("CrewTrainingCost", data.CrewTrainingLevel < Config.CrewTrainingMax and Config.crewTrainingCost(data.CrewTrainingLevel) or 0)
    player:SetAttribute("DailyReady", dailyReady)
    player:SetAttribute("DailyStreak", data.DailyStreak)
    player:SetAttribute("DailyReward", dailyReady and Config.dailyRewardFor(upcomingStreak) or 0)
    if refreshHarborProgress then refreshHarborProgress(player) end
end

local function awardExplorerXp(player, amount)
    local data = playerData[player]
    if not data then return false end
    data.ExplorerXP += amount
    local rankedUp = false
    while data.ExplorerXP >= Config.explorerXpForLevel(data.ExplorerLevel) do
        data.ExplorerXP -= Config.explorerXpForLevel(data.ExplorerLevel)
        data.ExplorerLevel += 1
        rankedUp = true
    end
    local stat = leaderstat(player, "Explorer Level")
    if stat then stat.Value = data.ExplorerLevel end
    syncAdventure(player)
    return rankedUp
end

local function registerDiscoveryChain(player)
    local now = os.clock()
    local chain = discoveryChains[player]
    if not chain or now - chain.LastRecovery > Config.DiscoveryChainWindow then
        chain = { Count = 1, LastRecovery = now, Version = 0 }
        discoveryChains[player] = chain
    else
        chain.Count = math.min(chain.Count + 1, Config.DiscoveryChainMax)
        chain.LastRecovery = now
    end
    chain.Version += 1
    local version = chain.Version
    player:SetAttribute("DiscoveryChain", chain.Count)
    player:SetAttribute("DiscoveryChainEndsAt", os.time() + Config.DiscoveryChainWindow)
    task.delay(Config.DiscoveryChainWindow, function()
        if discoveryChains[player] == chain and chain.Version == version then
            discoveryChains[player] = nil
            if player.Parent then
                player:SetAttribute("DiscoveryChain", 0)
                player:SetAttribute("DiscoveryChainEndsAt", 0)
            end
        end
    end)
    return math.min(chain.Count - 1, Config.DiscoveryChainBonusMax), chain.Count
end

local function registerNormalRecovery(player)
    local data = playerData[player]
    if not data then return false end
    local completedFirstFlight = not data.FirstFlightComplete
    if completedFirstFlight then data.FirstFlightComplete = true end
    data.ContractProgress += 1
    local completed = false
    if data.ContractProgress >= Config.ContractGoal then
        data.ContractProgress = 0
        data.RescueBeacons += 1
        completed = true
    end
    syncAdventure(player)
    if completedFirstFlight then
        sendStatus(player, "First Flight complete! Your Journey now tracks contracts, upgrades, and crew opportunities.", "Success")
    end
    if completed and pulseSanctuary then pulseSanctuary(player) end
    return completed
end

local function registerStormCore()
    if not stormActive or stormCompleted then return false end
    stormProgress += 1
    if stormProgress < stormGoal then
        syncStormState()
        return false
    end

    stormCompleted = true
    syncStormState()
    for _, teammate in ipairs(Players:GetPlayers()) do
        if playerData[teammate] then
            setSalvage(teammate, playerData[teammate].Salvage + Config.StormCoopReward)
            sendStatus(teammate, "Storm front secured! Your crew earned +" .. Config.StormCoopReward .. " salvage.", "Storm")
        end
    end
    return true
end

local function createCloud(parent, position, scale)
    local cloud = Instance.new("Model")
    cloud.Name = "Cloud"
    cloud.Parent = parent
    for index = 1, 4 do
        local angle = (math.pi * 2 / 4) * index
        local puff = createPart(cloud, {
            Name = "Puff",
            Size = Vector3.new(scale, scale * 0.55, scale),
            Color = Theme.Cloud,
            Material = Enum.Material.SmoothPlastic,
            CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * scale * 0.3, math.random(-2, 2), math.sin(angle) * scale * 0.3)),
            CanCollide = false,
        })
        puff.Shape = Enum.PartType.Ball
        TweenService:Create(puff, TweenInfo.new(4.5 + (index * 0.45), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            CFrame = puff.CFrame * CFrame.new(math.cos(angle) * 1.25, 0.8 + (index % 2) * 0.25, math.sin(angle) * 0.7),
        }):Play()
    end
    return cloud
end

local function createStormCloud(parent, position, scale)
    local cloud = createCloud(parent, position, scale)
    for _, puff in ipairs(cloud:GetChildren()) do
        if puff:IsA("BasePart") then
            puff.Color = Theme.Violet:Lerp(Theme.Ink, 0.72)
            puff.Transparency = 0.12
        end
    end
    return cloud
end

local function createStormwindTrail(parent, startPosition, endPosition)
    local trail = Instance.new("Model")
    trail.Name = "StormwindTrail"
    trail.Parent = parent
    local segments = 11
    for index = 1, segments do
        local t = (index - 1) / (segments - 1)
        local position = startPosition:Lerp(endPosition, t)
            + Vector3.new(math.sin(index * 1.8) * 1.8, 0, 0)
        local gust = createPart(trail, {
            Name = "StormwindGust",
            Size = Vector3.new(2.5, 10, 8.5),
            Color = Theme.Violet:Lerp(Theme.Cloud, 0.22 + ((index % 2) * 0.08)),
            Material = Enum.Material.SmoothPlastic,
            CFrame = CFrame.new(position),
        })
        gust.Shape = Enum.PartType.Cylinder
        gust.Orientation = Vector3.new(0, 0, 90)
        local mist = createPart(trail, {
            Name = "StormMist",
            Size = Vector3.new(5, 2.2, 5),
            Color = Theme.Violet,
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(position + Vector3.new(0, 1.9, 0)),
            CanCollide = false,
        })
        mist.Shape = Enum.PartType.Ball
        mist.Transparency = 0.7
        TweenService:Create(mist, TweenInfo.new(1.35 + (index * 0.08), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            CFrame = mist.CFrame + Vector3.new(0, 0.8, 0),
            Transparency = 0.84,
        }):Play()
    end
end

local function createStormCloudRun(parent, center)
    local run = Instance.new("Model")
    run.Name = "StormCloudRun"
    run.Parent = parent
    for index = 1, 8 do
        local angle = (math.pi * 2 / 8) * index
        local bankPosition = center + Vector3.new(math.cos(angle) * 23, 0, math.sin(angle) * 23)
        local bank = createPart(run, {
            Name = "StormCloudBank",
            Size = Vector3.new(3.5, 20, 20),
            Color = Theme.Violet:Lerp(Theme.Cloud, 0.18),
            Material = Enum.Material.SmoothPlastic,
            CFrame = CFrame.new(bankPosition),
        })
        bank.Shape = Enum.PartType.Cylinder
        bank.Orientation = Vector3.new(0, 0, 90)
        local lightning = createPart(run, {
            Name = "StormLightningShard",
            Size = Vector3.new(0.38, 5 + (index % 3), 0.38),
            Color = Theme.Gold:Lerp(Theme.Violet, 0.3),
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(bankPosition + Vector3.new(0, 3.8, 0)),
            CanCollide = false,
        })
        local light = Instance.new("PointLight")
        light.Color = lightning.Color
        light.Range = 8
        light.Brightness = 0.7
        light.Parent = lightning
        TweenService:Create(lightning, TweenInfo.new(0.42 + (index * 0.03), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Transparency = 0.58,
        }):Play()
    end
    createStormwindTrail(run, Vector3.new(0, 29.2, -60), center + Vector3.new(0, 1.3, 17))
end

local function createAmbientSkyLife(parent)
    local life = Instance.new("Folder")
    life.Name = "AmbientSkyLife"
    life.Parent = parent
    local function animate(parts, offset, duration)
        local model = parts[1].Parent
        local origin = parts[1].CFrame
        for _, part in ipairs(parts) do
            part:SetAttribute("FlightRest", origin:ToObjectSpace(part.CFrame))
            part.CanTouch = false
            part.CanQuery = false
        end
        model:SetAttribute("FlightOrigin", origin.Position)
        model:SetAttribute("FlightOffset", offset)
        model:SetAttribute("FlightDuration", duration)
        CollectionService:AddTag(model, "AmbientFlyer")
    end
    for index = 1, 10 do
        local angle = math.rad(index * 36)
        local position = Vector3.new(math.cos(angle) * (145 + (index % 3) * 30), 58 + (index % 3) * 9, math.sin(angle) * (145 + (index % 2) * 40))
        local bird = Instance.new("Model")
        bird.Name = "SkyBird"
        bird.Parent = life
        local color = index % 2 == 0 and Theme.Cloud:Lerp(Theme.Aqua, 0.22) or Theme.Gold:Lerp(Theme.Cloud, 0.45)
        local body = createPart(bird, {
            Name = "BirdBody", Size = Vector3.new(1.2, 0.65, 1.7), Color = color,
            Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(position), CanCollide = false,
        })
        local leftWing = createPart(bird, {
            Name = "LeftWing", Size = Vector3.new(2.8, 0.2, 0.7), Color = color,
            Material = Enum.Material.SmoothPlastic, CFrame = body.CFrame * CFrame.new(-1.5, 0, 0.15), CanCollide = false,
        })
        local rightWing = createPart(bird, {
            Name = "RightWing", Size = Vector3.new(2.8, 0.2, 0.7), Color = color,
            Material = Enum.Material.SmoothPlastic, CFrame = body.CFrame * CFrame.new(1.5, 0, 0.15), CanCollide = false,
        })
        animate({ body, leftWing, rightWing }, Vector3.new(math.sin(angle) * 40, 6, math.cos(angle) * 40), 8 + (index % 4))
    end
    for index, color in ipairs({ Theme.Coral, Theme.Violet }) do
        local start = Vector3.new(-260, 82 + (index * 12), -140 + (index * 90))
        local drake = Instance.new("Model")
        drake.Name = "CloudDrake"
        drake.Parent = life
        local body = createPart(drake, {
            Name = "DrakeBody", Size = Vector3.new(6, 2.3, 11), Color = color:Lerp(Theme.Ink, 0.2),
            Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(start), CanCollide = false,
        })
        local head = createPart(drake, {
            Name = "DrakeHead", Size = Vector3.new(3.2, 2.4, 3.6), Color = color,
            Material = Enum.Material.SmoothPlastic, CFrame = body.CFrame * CFrame.new(0, 0.4, -6.1), CanCollide = false,
        })
        local leftWing = createPart(drake, {
            Name = "DrakeWing", Size = Vector3.new(13, 0.45, 4), Color = color:Lerp(Theme.Cloud, 0.15),
            Material = Enum.Material.Fabric, CFrame = body.CFrame * CFrame.new(-7.8, 0.8, 0), CanCollide = false,
        })
        local rightWing = createPart(drake, {
            Name = "DrakeWing", Size = Vector3.new(13, 0.45, 4), Color = color:Lerp(Theme.Cloud, 0.15),
            Material = Enum.Material.Fabric, CFrame = body.CFrame * CFrame.new(7.8, 0.8, 0), CanCollide = false,
        })
        animate({ body, head, leftWing, rightWing }, Vector3.new(520, 5, 145), 26 + (index * 4))
    end
end

-- Reusable scenery gives every island a silhouette from a distance. These
-- pieces are non-colliding, so they add atmosphere without fighting movement.
local function createIslandUnderside(parent, center, radius, color)
    for tier, scale in ipairs({ 0.8, 0.56, 0.32 }) do
        local shelf = createPart(parent, {
            Name = "FloatingRockShelf",
            Size = Vector3.new(7 + (tier * 4), radius * scale, radius * scale),
            Color = color:Lerp(Theme.Ink, tier * 0.1),
            Material = Enum.Material.Slate,
            CFrame = CFrame.new(center - Vector3.new(0, 5 + (tier * 6), 0)),
            CanCollide = false,
        })
        shelf.Shape = Enum.PartType.Cylinder
        shelf.Orientation = Vector3.new(0, 0, 90)
        TweenService:Create(shelf, TweenInfo.new(5 + (tier * 0.8), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            CFrame = shelf.CFrame + Vector3.new(0, 0.8 + (tier * 0.2), 0),
        }):Play()
    end
end

local function createRockCluster(parent, center, radius, count, color)
    local rocks = Instance.new("Folder")
    rocks.Name = "RockCluster"
    rocks.Parent = parent
    for index = 1, count do
        local angle = (math.pi * 2 / count) * index + 0.35
        local distance = radius * (0.72 + ((index % 3) * 0.08))
        local rock = createPart(rocks, {
            Name = "WeatheredRock",
            Size = Vector3.new(4 + (index % 2), 2.8 + (index % 3), 4.5 + ((index + 1) % 2)),
            Color = color:Lerp(Theme.Ink, 0.16 + ((index % 2) * 0.08)),
            Material = Enum.Material.Slate,
            CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * distance, 4.2, math.sin(angle) * distance)),
            CanCollide = false,
        })
        rock.Shape = Enum.PartType.Ball
    end
end

local function createSkyTree(parent, position, canopyColor, scale)
    local tree = Instance.new("Model")
    tree.Name = "SkyTree"
    tree.Parent = parent
    local trunk = createPart(tree, {
        Name = "TwistedTrunk",
        Size = Vector3.new(7 * scale, 1.25 * scale, 1.25 * scale),
        Color = Color3.fromRGB(91, 68, 48),
        Material = Enum.Material.Wood,
        CFrame = CFrame.new(position + Vector3.new(0, 3.5 * scale, 0)),
        CanCollide = false,
    })
    trunk.Shape = Enum.PartType.Cylinder
    trunk.Orientation = Vector3.new(0, 0, 90)
    for index = 1, 3 do
        local angle = (math.pi * 2 / 3) * index
        local canopy = createPart(tree, {
            Name = "Cloudleaf",
            Size = Vector3.new(4.6 * scale, 3.6 * scale, 4.6 * scale),
            Color = canopyColor:Lerp(Theme.Cloud, 0.08 * index),
            Material = Enum.Material.Grass,
            CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * scale, 7 * scale + ((index % 2) * scale), math.sin(angle) * scale)),
            CanCollide = false,
        })
        canopy.Shape = Enum.PartType.Ball
        TweenService:Create(canopy, TweenInfo.new(2.8 + (index * 0.35), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            CFrame = canopy.CFrame * CFrame.new(math.cos(angle) * 0.45, 0.35, math.sin(angle) * 0.45),
        }):Play()
    end
end

local function createCrystalCluster(parent, center, color)
    for index = 1, 4 do
        local angle = (math.pi * 2 / 4) * index
        local crystal = createPart(parent, {
            Name = "SkyCrystal",
            Size = Vector3.new(5 + (index % 2) * 2, 1.6, 1.6),
            Color = color:Lerp(Theme.Text, 0.22),
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * 5, 4, math.sin(angle) * 5)) * CFrame.Angles(0, 0, math.rad(90 + (14 * (index - 2)))),
            CanCollide = false,
        })
        crystal.Shape = Enum.PartType.Cylinder
    end
end

local function createBiomeLandmarks(parent, biome, center)
    local landmarks = Instance.new("Model")
    landmarks.Name = biome.Name:gsub("%s+", "") .. "Landmarks"
    landmarks.Parent = parent
    if biome.Name == "Ember Drift" then
        for index = 1, 4 do
            local angle = math.rad(30 + (index * 82))
            local position = center + Vector3.new(math.cos(angle) * 27, 4.8, math.sin(angle) * 27)
            local vent = createPart(landmarks, {
                Name = "CinderVent",
                Size = Vector3.new(4.5, 2.2, 4.5),
                Color = Theme.Ink:Lerp(Theme.Coral, 0.18),
                Material = Enum.Material.Slate,
                CFrame = CFrame.new(position),
                CanCollide = false,
            })
            vent.Shape = Enum.PartType.Ball
            local flame = createPart(landmarks, {
                Name = "CinderFlame",
                Size = Vector3.new(1.25, 5 + (index % 2), 1.25),
                Color = Theme.Coral:Lerp(Theme.Gold, 0.34),
                Material = Enum.Material.Neon,
                CFrame = vent.CFrame * CFrame.new(0, 3.1, 0),
                CanCollide = false,
            })
            local light = Instance.new("PointLight")
            light.Color = Theme.Coral
            light.Range = 10
            light.Brightness = 1.1
            light.Parent = flame
            TweenService:Create(flame, TweenInfo.new(1.05 + (index * 0.12), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                Size = flame.Size + Vector3.new(0.32, 1.15, 0.32),
            }):Play()
        end
    elseif biome.Name == "Aurora Shelf" then
        for index = 1, 5 do
            local angle = math.rad(18 + (index * 68))
            local position = center + Vector3.new(math.cos(angle) * 26, 4.8, math.sin(angle) * 26)
            local spire = createPart(landmarks, {
                Name = "AuroraSpire",
                Size = Vector3.new(7 + (index % 2) * 2, 1.2, 1.2),
                Color = index % 2 == 0 and Theme.Aqua:Lerp(Theme.Text, 0.22) or Theme.Violet:Lerp(Theme.Text, 0.2),
                Material = Enum.Material.Neon,
                CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(index * 28), math.rad(56 + (index * 4))),
                CanCollide = false,
            })
            spire.Shape = Enum.PartType.Cylinder
            local light = Instance.new("PointLight")
            light.Color = spire.Color
            light.Range = 11
            light.Brightness = 0.85
            light.Parent = spire
        end
        for index = 1, 3 do
            local ribbon = createPart(landmarks, {
                Name = "AuroraRibbon",
                Size = Vector3.new(0.22, 8 + index, 4.5),
                Color = index % 2 == 0 and Theme.Violet or Theme.Aqua,
                Material = Enum.Material.Neon,
                CFrame = CFrame.new(center + Vector3.new(-10 + (index * 10), 13 + (index % 2) * 2, -20 + (index * 4))) * CFrame.Angles(0, math.rad(22 * index), math.rad(8 * (index - 2))),
                CanCollide = false,
            })
            ribbon.Transparency = 0.44
        end
    end
end

local function createWreckLandmark(parent, position)
    local wreck = Instance.new("Model")
    wreck.Name = "SkyshipWreck"
    wreck.Parent = parent
    local hull = createPart(wreck, {
        Name = "BrokenHull",
        Size = Vector3.new(15, 2.4, 5),
        Color = Color3.fromRGB(105, 72, 48),
        Material = Enum.Material.WoodPlanks,
        CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(-24), math.rad(8)),
        CanCollide = false,
    })
    local mast = createPart(wreck, {
        Name = "BrokenMast",
        Size = Vector3.new(14, 1.15, 1.15),
        Color = Color3.fromRGB(79, 55, 39),
        Material = Enum.Material.Wood,
        CFrame = CFrame.new(position + Vector3.new(-1, 7, 0)),
        CanCollide = false,
    })
    mast.Shape = Enum.PartType.Cylinder
    mast.Orientation = Vector3.new(0, 0, 90)
    local sail = createPart(wreck, {
        Name = "TornSail",
        Size = Vector3.new(0.35, 8, 8),
        Color = Color3.fromRGB(235, 224, 190),
        Material = Enum.Material.Fabric,
        CFrame = CFrame.new(position + Vector3.new(0.6, 8, 0)) * CFrame.Angles(0, math.rad(16), math.rad(-4)),
        CanCollide = false,
    })
    sail.Transparency = 0.12
    createCrystalCluster(wreck, position + Vector3.new(5, 1.5, 2), Theme.Gold)
end

local function createCrewExpeditionLandmark(parent, position)
    local landmark = Instance.new("Model")
    landmark.Name = "CrewExpeditionLandmark"
    landmark.Parent = parent
    local wood = Color3.fromRGB(91, 62, 43)
    for _, offset in ipairs({ -2.2, 2.2 }) do
        local post = createPart(landmark, {
            Name = "ExpeditionPost",
            Size = Vector3.new(0.45, 6.8, 0.45),
            Color = wood,
            Material = Enum.Material.Wood,
            CFrame = CFrame.new(position + Vector3.new(offset, 0.4, 1.35)),
            CanCollide = false,
        })
        local lantern = createPart(landmark, {
            Name = "ExpeditionLantern",
            Size = Vector3.new(1.1, 1.1, 1.1),
            Color = Theme.Aqua,
            Material = Enum.Material.Neon,
            CFrame = post.CFrame * CFrame.new(0, 3.15, -0.2),
            CanCollide = false,
        })
        lantern.Shape = Enum.PartType.Ball
        local light = Instance.new("PointLight")
        light.Color = Theme.Aqua
        light.Range = 10
        light.Brightness = 1.1
        light.Parent = lantern
    end
    createPart(landmark, {
        Name = "ExpeditionCrossbeam",
        Size = Vector3.new(5.2, 0.45, 0.45),
        Color = wood,
        Material = Enum.Material.Wood,
        CFrame = CFrame.new(position + Vector3.new(0, 3.55, 1.35)),
        CanCollide = false,
    })
    local pennant = createPart(landmark, {
        Name = "ExpeditionPennant",
        Size = Vector3.new(3.2, 2.25, 0.18),
        Color = Theme.Aqua:Lerp(Theme.Text, 0.18),
        Material = Enum.Material.Fabric,
        CFrame = CFrame.new(position + Vector3.new(0, 2.25, 1.05)),
        CanCollide = false,
    })
    local bannerLight = Instance.new("PointLight")
    bannerLight.Color = Theme.Aqua
    bannerLight.Range = 8
    bannerLight.Brightness = 0.45
    bannerLight.Parent = pennant
    for index, offset in ipairs({ Vector3.new(-3, -2.25, 0.35), Vector3.new(3, -2.25, 0.35) }) do
        local crate = createPart(landmark, {
            Name = "ExpeditionSupplyCrate",
            Size = Vector3.new(1.8, 1.8, 1.8),
            Color = index == 1 and Theme.Aqua:Lerp(wood, 0.5) or Theme.Gold:Lerp(wood, 0.45),
            Material = Enum.Material.WoodPlanks,
            CFrame = CFrame.new(position + offset),
            CanCollide = false,
        })
        crate.Orientation = Vector3.new(0, index == 1 and 18 or -14, 0)
    end
end

local function createSkywayCache(parent, position, accent)
    local cache = Instance.new("Model")
    cache.Name = "SkywayRouteCache"
    cache.Parent = parent
    local crate = createPart(cache, {
        Name = "RouteCache",
        Size = Vector3.new(2.3, 2.1, 2.3),
        Color = Theme.Gold:Lerp(accent, 0.22),
        Material = Enum.Material.Metal,
        CFrame = CFrame.new(position),
    })
    local band = createPart(cache, {
        Name = "RouteCacheBand",
        Size = Vector3.new(2.45, 0.28, 2.45),
        Color = Theme.Ink,
        Material = Enum.Material.Metal,
        CFrame = crate.CFrame * CFrame.new(0, 0.25, 0),
        CanCollide = false,
    })
    local light = Instance.new("PointLight")
    light.Color = Theme.Gold
    light.Range = 7
    light.Brightness = 0.75
    light.Parent = crate
    addBillboard(crate, "ROUTE CACHE\n+" .. Config.SkywayCacheValue .. " SALVAGE", Theme.Gold:Lerp(Theme.Text, 0.25))
    local prompt = addPrompt(crate, "Search", "Route Cache", 0.3)
    local opened = false
    prompt.Triggered:Connect(function(player)
        if opened or not playerData[player] then return end
        if not PlayerRuntime.canInteract(player, crate, prompt.MaxActivationDistance) then return end
        opened = true
        local chainBonus, chainCount = registerDiscoveryChain(player)
        local earned = salvageRewardFor(player, Config.SkywayCacheValue, false) + chainBonus
        setSalvage(player, playerData[player].Salvage + earned)
        local rankedUp = awardExplorerXp(player, earned)
        local message = "Route cache found! +" .. earned .. " salvage."
        if chainCount >= 2 then message ..= " Chain x" .. chainCount .. "." end
        if rankedUp then message ..= " Rank up!" end
        sendStatus(player, message, "Success")
        cache:Destroy()
        task.delay(Config.SkywayCacheRespawnSeconds, function()
            if parent.Parent then createSkywayCache(parent, position, accent) end
        end)
    end)
    TweenService:Create(crate, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        CFrame = crate.CFrame * CFrame.new(0, 0.35, 0),
    }):Play()
    TweenService:Create(band, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        CFrame = band.CFrame * CFrame.new(0, 0.35, 0),
    }):Play()
end

local function createSkyway(parent, startPosition, endPosition, accent, index)
    local skyway = Instance.new("Model")
    skyway.Name = "HarborSkyway" .. index
    skyway.Parent = parent
    local span = endPosition - startPosition
    local length = span.Magnitude
    local segments = math.max(5, math.ceil(length / 7))
    local segmentLength = length / segments
    local wood = Color3.fromRGB(102, 72, 50)

    for segmentIndex = 1, segments do
        local from = startPosition:Lerp(endPosition, (segmentIndex - 1) / segments)
        local to = startPosition:Lerp(endPosition, segmentIndex / segments)
        local position = (from + to) * 0.5
        local plankFrame = CFrame.lookAt(position, to)
        createPart(skyway, {
            Name = "SkywayPlank",
            Size = Vector3.new(8.4, 0.75, segmentLength + 0.18),
            Color = segmentIndex % 2 == 0 and wood:Lerp(Theme.Ink, 0.08) or wood,
            Material = Enum.Material.WoodPlanks,
            CFrame = plankFrame,
        })
        for _, side in ipairs({ -1, 1 }) do
            createPart(skyway, {
                Name = "SkywayRail",
                Size = Vector3.new(0.24, 1.35, segmentLength),
                Color = wood:Lerp(Theme.Ink, 0.18),
                Material = Enum.Material.Wood,
                CFrame = plankFrame * CFrame.new(side * 3.95, 1.04, 0),
            })
        end
    end

    local restPosition = startPosition:Lerp(endPosition, 0.5) + Vector3.new(0, 0.45, 0)
    local rest = createPart(skyway, {
        Name = "SkywayRest",
        Size = Vector3.new(12, 0.9, 12),
        Color = Theme.PanelRaised:Lerp(accent, 0.38),
        Material = Enum.Material.Slate,
        CFrame = CFrame.new(restPosition),
    })
    local beacon = createPart(skyway, {
        Name = "SkywayBeacon",
        Size = Vector3.new(1.2, 4.8, 1.2),
        Color = accent,
        Material = Enum.Material.Neon,
        CFrame = rest.CFrame * CFrame.new(0, 2.75, 0),
        CanCollide = false,
    })
    local beaconLight = Instance.new("PointLight")
    beaconLight.Color = accent
    beaconLight.Range = 12
    beaconLight.Brightness = 1.35
    beaconLight.Parent = beacon
    local horizontalDirection = Vector3.new(span.X, 0, span.Z).Unit
    local side = Vector3.new(-horizontalDirection.Z, 0, horizontalDirection.X)
    createSkyTree(skyway, restPosition + (side * 3.2) + Vector3.new(0, 0.2, 0), accent, 0.32)
    createSkywayCache(skyway, restPosition - (side * 2.8) + Vector3.new(0, 1.6, 0), accent)
    createCloud(skyway, restPosition - Vector3.new(0, 8, 0), 4)
end

local function createSkywayGateway(parent, position, horizontalDirection, accent, name)
    local gateway = Instance.new("Model")
    gateway.Name = name
    gateway.Parent = parent
    local side = Vector3.new(-horizontalDirection.Z, 0, horizontalDirection.X)
    local stone = Theme.Slate:Lerp(Theme.PanelRaised, 0.36)
    createPart(gateway, {
        Name = "GatewayLanding",
        Size = Vector3.new(10.4, 0.42, 9),
        Color = stone,
        Material = Enum.Material.Slate,
        CFrame = CFrame.new(position - Vector3.new(0, 0.1, 0)),
    })
    for _, sideDirection in ipairs({ -1, 1 }) do
        local post = createPart(gateway, {
            Name = "GatewayPost",
            Size = Vector3.new(0.6, 5.4, 0.6),
            Color = stone:Lerp(accent, 0.22),
            Material = Enum.Material.Slate,
            CFrame = CFrame.new(position + (side * (sideDirection * 4.15)) + Vector3.new(0, 2.45, 0)),
        })
        local lantern = createPart(gateway, {
            Name = "GatewayLantern",
            Size = Vector3.new(0.95, 0.95, 0.95),
            Color = accent,
            Material = Enum.Material.Neon,
            CFrame = post.CFrame * CFrame.new(0, 2.9, 0),
            CanCollide = false,
        })
        lantern.Shape = Enum.PartType.Ball
        local light = Instance.new("PointLight")
        light.Color = accent
        light.Range = 9
        light.Brightness = 0.85
        light.Parent = lantern
    end
    createPart(gateway, {
        Name = "GatewayBeam",
        Size = Vector3.new(0.55, 0.55, 8.8),
        Color = stone:Lerp(accent, 0.3),
        Material = Enum.Material.Slate,
        CFrame = CFrame.lookAt(position + Vector3.new(0, 5.15, 0), position + Vector3.new(0, 5.15, 0) + side),
        CanCollide = false,
    })
end

local function createWreckSkywayPlaza(parent, center)
    local plaza = Instance.new("Model")
    plaza.Name = "WreckSkywayPlaza"
    plaza.Parent = parent
    local plazaDiameter = Config.WreckIslandDiameter - 16
    local outer = createPart(plaza, {
        Name = "PlazaDeck",
        Size = Vector3.new(0.5, plazaDiameter, plazaDiameter),
        Color = Theme.Slate:Lerp(Theme.PanelRaised, 0.3),
        Material = Enum.Material.Slate,
        CFrame = CFrame.new(center + Vector3.new(0, 4.75, 0)),
    })
    outer.Shape = Enum.PartType.Cylinder
    outer.Orientation = Vector3.new(0, 0, 90)
    local compass = createPart(plaza, {
        Name = "SkywayCompass",
        Size = Vector3.new(0.58, plazaDiameter * 0.34, plazaDiameter * 0.34),
        Color = Theme.PanelRaised:Lerp(Theme.Ink, 0.16),
        Material = Enum.Material.Metal,
        CFrame = CFrame.new(center + Vector3.new(0, 5.15, 0)),
    })
    compass.Shape = Enum.PartType.Cylinder
    compass.Orientation = Vector3.new(0, 0, 90)
    for index = 1, Config.PlotCount do
        local angle = (math.pi * 2 / Config.PlotCount) * (index - 1)
        local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local spoke = createPart(plaza, {
            Name = "SkywaySpoke",
            Size = Vector3.new(4.5, 0.14, plazaDiameter * 0.25),
            Color = index % 2 == 0 and Theme.Aqua:Lerp(Theme.Slate, 0.7) or Theme.Mint:Lerp(Theme.Slate, 0.72),
            Material = Enum.Material.Neon,
            CFrame = CFrame.lookAt(center + (direction * (plazaDiameter * 0.38)) + Vector3.new(0, 5.37, 0), center + (direction * (plazaDiameter * 0.39)) + Vector3.new(0, 5.37, 0)),
            CanCollide = false,
        })
        spoke.Transparency = 0.24
    end
    local core = createPart(plaza, {
        Name = "SkywayCompassCore",
        Size = Vector3.new(4.4, 0.42, 4.4),
        Color = Theme.Gold,
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(center + Vector3.new(0, 5.66, 0)),
        CanCollide = false,
    })
    local coreLight = Instance.new("PointLight")
    coreLight.Color = Theme.Gold
    coreLight.Range = 12
    coreLight.Brightness = 0.7
    coreLight.Parent = core
end

local function createHarborArrivalDeck(parent, center, outwardDirection, accent)
    local arrival = Instance.new("Model")
    arrival.Name = "HarborArrivalDeck"
    arrival.Parent = parent
    local position = center - (outwardDirection * 17) + Vector3.new(0, 4, 0)
    local deckFrame = CFrame.lookAt(position, position + outwardDirection)
    local deck = createPart(arrival, {
        Name = "ArrivalWalkway",
        Size = Vector3.new(8, 0.68, 28),
        Color = Color3.fromRGB(104, 74, 51),
        Material = Enum.Material.WoodPlanks,
        CFrame = deckFrame,
    })
    for _, side in ipairs({ -1, 1 }) do
        createPart(arrival, {
            Name = "ArrivalRail",
            Size = Vector3.new(0.22, 1.2, 27.6),
            Color = Theme.HarborDark:Lerp(Theme.Ink, 0.14),
            Material = Enum.Material.Wood,
            CFrame = deckFrame * CFrame.new(side * 3.72, 1, 0),
        })
        local lantern = createPart(arrival, {
            Name = "ArrivalLantern",
            Size = Vector3.new(0.78, 0.78, 0.78),
            Color = accent,
            Material = Enum.Material.Neon,
            CFrame = deckFrame * CFrame.new(side * 3.72, 1.8, 3.8),
            CanCollide = false,
        })
        lantern.Shape = Enum.PartType.Ball
        local light = Instance.new("PointLight")
        light.Color = accent
        light.Range = 7
        light.Brightness = 0.65
        light.Parent = lantern
    end
    local inlay = createPart(arrival, {
        Name = "ArrivalInlay",
        Size = Vector3.new(1.2, 0.08, 26),
        Color = accent,
        Material = Enum.Material.Neon,
        CFrame = deckFrame * CFrame.new(0, 0.39, 0),
        CanCollide = false,
    })
    inlay.Transparency = 0.28
end

local function createCollectible(parent, position, value, isStorm)
    local salvageColor = Theme.Gold
    if not isStorm and value >= Config.Biomes[3].SalvageValue then
        salvageColor = Theme.Aqua
    elseif not isStorm and value >= Config.Biomes[2].SalvageValue then
        salvageColor = Theme.Coral
    end
    local collectible = createPart(parent, {
        Name = isStorm and "StormCore" or "SalvageCrate",
        Size = isStorm and Vector3.new(3.2, 3.2, 3.2) or Vector3.new(3, 3, 3),
        Color = isStorm and Theme.Violet or salvageColor,
        Material = isStorm and Enum.Material.Neon or Enum.Material.Metal,
        CFrame = CFrame.new(position),
    })
    if isStorm then collectible.Shape = Enum.PartType.Ball end
    addBillboard(collectible, "+" .. value .. " SALVAGE", (isStorm and Theme.Violet or salvageColor):Lerp(Theme.Text, 0.35))
    if not isStorm and value >= Config.Biomes[3].SalvageValue then
        local light = Instance.new("PointLight")
        light.Color = salvageColor
        light.Range = 7
        light.Brightness = 0.8
        light.Parent = collectible
    end
    local prompt = addPrompt(collectible, "Recover", isStorm and "Storm Core" or "Lost Salvage", 0.25)
    local collected = false

    prompt.Triggered:Connect(function(player)
        if collected or not playerData[player] then return end
        if not PlayerRuntime.canInteract(player, collectible, prompt.MaxActivationDistance) then return end
        if isStorm and (not stormActive or os.time() >= stormEndsAt) then return end
        collected = true
        local chainBonus, chainCount = 0, 0
        if not isStorm then chainBonus, chainCount = registerDiscoveryChain(player) end
        local earned = salvageRewardFor(player, value, isStorm) + chainBonus
        setSalvage(player, playerData[player].Salvage + earned)
        local rankedUp = awardExplorerXp(player, earned)
        local completedContract = not isStorm and registerNormalRecovery(player)
        local completedCrew = not isStorm and crew:RegisterRecovery(player)
        local completedStorm = isStorm and registerStormCore()
        local message = (isStorm and "Storm core recovered! " or "Salvage recovered! ") .. "+" .. earned
        if completedContract then message ..= "  •  Contract complete—return home!" end
        if completedCrew then message ..= "  •  Crew cache recovered!" end
        if completedStorm then message ..= "  •  Crew target complete!" end
        if rankedUp then message ..= "  •  " .. Config.explorerTitleForLevel(playerData[player].ExplorerLevel) .. " Rank " .. playerData[player].ExplorerLevel .. " reached!" end
        if chainCount >= 2 then message ..= "  •  Chain x" .. chainCount .. " ( +" .. chainBonus .. " )" end
        sendStatus(player, message, "Success")
        collectible:Destroy()
        if not isStorm then
            task.delay(Config.NormalRespawnSeconds, function()
                if parent.Parent then createCollectible(parent, position, value, false) end
            end)
        end
    end)

    local goal = { CFrame = collectible.CFrame * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, math.rad(180), 0) }
    TweenService:Create(collectible, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal):Play()
end

local function createExpeditionCache(parent, position, biome)
    local cache = Instance.new("Model")
    cache.Name = "ExpeditionCache"
    cache.Parent = parent
    local chest = createPart(cache, {
        Name = "AncientCache",
        Size = Vector3.new(5.5, 3.2, 3.4),
        Color = Theme.Gold:Lerp(biome.Color, 0.22),
        Material = Enum.Material.Metal,
        CFrame = CFrame.new(position),
    })
    local band = createPart(cache, {
        Name = "CacheBand",
        Size = Vector3.new(5.7, 0.4, 3.6),
        Color = Theme.Ink,
        Material = Enum.Material.Metal,
        CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)),
        CanCollide = false,
    })
    local plinth = createPart(cache, {
        Name = "CachePlinth",
        Size = Vector3.new(6.8, 0.6, 4.8),
        Color = Theme.Ink:Lerp(biome.Color, 0.22),
        Material = Enum.Material.Slate,
        CFrame = CFrame.new(position - Vector3.new(0, 1.9, 0)),
    })
    local aura = createPart(cache, {
        Name = "CacheSignalAura",
        Size = Vector3.new(8.2, 8.2, 8.2),
        Color = Theme.Gold:Lerp(biome.Color, 0.3),
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(position + Vector3.new(0, 1.3, 0)),
        CanCollide = false,
    })
    aura.Shape = Enum.PartType.Ball
    aura.Transparency = 0.86
    for index, offset in ipairs({
        Vector3.new(-3.0, 0.2, -2.0), Vector3.new(3.0, 0.2, -2.0),
        Vector3.new(-3.0, 0.2, 2.0), Vector3.new(3.0, 0.2, 2.0),
    }) do
        local marker = createPart(cache, {
            Name = "CacheSignal",
            Size = Vector3.new(0.72, 0.72, 0.72),
            Color = biome.Color:Lerp(Theme.Text, 0.26),
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(position + offset),
            CanCollide = false,
        })
        marker.Shape = Enum.PartType.Ball
        TweenService:Create(marker, TweenInfo.new(1.05 + (index * 0.12), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            CFrame = marker.CFrame * CFrame.new(0, 0.7, 0),
        }):Play()
    end
    addBillboard(chest, "ANCIENT CACHE\n+" .. (biome.SalvageValue * 4) .. " SALVAGE", Theme.Gold:Lerp(Theme.Text, 0.3))
    local prompt = addPrompt(chest, "Open", biome.Name .. " Cache", 0.7)
    local opened = false
    prompt.Triggered:Connect(function(player)
        local data = playerData[player]
        if opened or not data then return end
        if not PlayerRuntime.canInteract(player, chest, prompt.MaxActivationDistance) then return end
        if data.HarborLevel < biome.RequiredHarborLevel then
            sendStatus(player, biome.Name .. " requires Harbor Level " .. biome.RequiredHarborLevel .. ".", "Warning")
            return
        end
        opened = true
        local chainBonus, chainCount = registerDiscoveryChain(player)
        local earned = salvageRewardFor(player, biome.SalvageValue * 4, false) + chainBonus
        setSalvage(player, data.Salvage + earned)
        local rankedUp = awardExplorerXp(player, earned)
        local completedContract = registerNormalRecovery(player)
        local message = "Ancient cache opened! +" .. earned
        if chainCount >= 2 then message ..= "  •  Chain x" .. chainCount end
        if completedContract then message ..= "  •  Contract complete—return home!" end
        if rankedUp then message ..= "  •  " .. Config.explorerTitleForLevel(data.ExplorerLevel) .. " Rank " .. data.ExplorerLevel .. " reached!" end
        sendStatus(player, message, "Success")
        cache:Destroy()
        task.delay(Config.ExpeditionCacheRespawnSeconds, function()
            if parent.Parent then createExpeditionCache(parent, position, biome) end
        end)
    end)
    local light = Instance.new("PointLight")
    light.Color = Theme.Gold
    light.Range = 12
    light.Brightness = 1.1
    light.Parent = chest
    TweenService:Create(aura, TweenInfo.new(1.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        Size = Vector3.new(9.4, 9.4, 9.4),
        Transparency = 0.93,
    }):Play()
    TweenService:Create(chest, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        CFrame = chest.CFrame * CFrame.new(0, 0.45, 0),
    }):Play()
    TweenService:Create(band, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        CFrame = band.CFrame * CFrame.new(0, 0.45, 0),
    }):Play()
end

local function decoratePlot(plot, level)
    local upgrades = plot:FindFirstChild("Upgrades")
    if upgrades then upgrades:Destroy() end
    upgrades = Instance.new("Folder")
    upgrades.Name = "Upgrades"
    upgrades.Parent = plot

    local center = plot:GetAttribute("Center")
    for index = 1, level do
        local angle = (math.pi * 2 / math.max(level, 3)) * index
        local position = center + Vector3.new(math.cos(angle) * 18, 5, math.sin(angle) * 18)
        local tower = createPart(upgrades, {
            Name = "HarborBeacon",
            Size = Vector3.new(3, 5 + index, 3),
            Color = Theme.Aqua,
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(position),
        })
        local light = Instance.new("PointLight")
        light.Range = 12
        light.Brightness = 1.5
        light.Color = tower.Color
        light.Parent = tower
    end

    -- Harbor tiers are visible home-base milestones, not just stat increases.
    if level >= 2 then
        local dock = createPart(upgrades, {
            Name = "AirshipDock",
            Size = Vector3.new(13, 1, 7),
            Color = Color3.fromRGB(111, 79, 54),
            Material = Enum.Material.WoodPlanks,
            CFrame = CFrame.new(center + Vector3.new(-11, 4, -4)) * CFrame.Angles(0, math.rad(-22), 0),
            CanCollide = false,
        })
        local mast = createPart(upgrades, {
            Name = "DockMast",
            Size = Vector3.new(10, 1.1, 1.1),
            Color = Color3.fromRGB(77, 54, 38),
            Material = Enum.Material.Wood,
            CFrame = CFrame.new(center + Vector3.new(-11, 9, -4)),
            CanCollide = false,
        })
        mast.Shape = Enum.PartType.Cylinder
        mast.Orientation = Vector3.new(0, 0, 90)
        local pennant = createPart(upgrades, {
            Name = "HarborPennant",
            Size = Vector3.new(0.25, 4, 5),
            Color = Theme.Aqua,
            Material = Enum.Material.Fabric,
            CFrame = CFrame.new(center + Vector3.new(-10.4, 10, -4)),
            CanCollide = false,
        })
        pennant.Transparency = 0.08
        dock:SetAttribute("Tier", 2)
    end

    if level >= 3 then
        for _, offset in ipairs({ Vector3.new(16, 4, -7), Vector3.new(7, 4, -18) }) do
            local post = createPart(upgrades, {
                Name = "HarborLantern",
                Size = Vector3.new(6, 0.8, 0.8),
                Color = Color3.fromRGB(82, 60, 43),
                Material = Enum.Material.Wood,
                CFrame = CFrame.new(center + offset + Vector3.new(0, 3, 0)),
                CanCollide = false,
            })
            post.Shape = Enum.PartType.Cylinder
            post.Orientation = Vector3.new(0, 0, 90)
            local lamp = createPart(upgrades, {
                Name = "WarmLantern",
                Size = Vector3.new(1.7, 1.7, 1.7),
                Color = Theme.Gold,
                Material = Enum.Material.Neon,
                CFrame = CFrame.new(center + offset + Vector3.new(0, 6.2, 0)),
                CanCollide = false,
            })
            lamp.Shape = Enum.PartType.Ball
            local light = Instance.new("PointLight")
            light.Range = 10
            light.Brightness = 1.2
            light.Color = Theme.Gold
            light.Parent = lamp
        end
    end

    if level >= 4 then
        local lookoutBase = createPart(upgrades, {
            Name = "LookoutPlatform",
            Size = Vector3.new(2, 9, 9),
            Color = Theme.PanelRaised,
            Material = Enum.Material.Slate,
            CFrame = CFrame.new(center + Vector3.new(-3, 6, 18)),
            CanCollide = false,
        })
        lookoutBase.Shape = Enum.PartType.Cylinder
        lookoutBase.Orientation = Vector3.new(0, 0, 90)
        local lookoutGlow = createPart(upgrades, {
            Name = "LookoutLens",
            Size = Vector3.new(4.5, 4.5, 4.5),
            Color = Theme.Violet,
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(center + Vector3.new(-3, 9, 18)),
            CanCollide = false,
        })
        lookoutGlow.Shape = Enum.PartType.Ball
        local light = Instance.new("PointLight")
        light.Range = 16
        light.Brightness = 1.6
        light.Color = Theme.Violet
        light.Parent = lookoutGlow
    end

    local ownerId = plot:GetAttribute("OwnerId")
    local owner = ownerId and Players:GetPlayerByUserId(ownerId)
    local mate = owner and crewMateFor(owner)
    if mate then
        local accent = Theme[mate.Accent] or Theme.Aqua
        local flagPole = createPart(upgrades, {
            Name = "CaptainFlagPole",
            Size = Vector3.new(8, 0.75, 0.75),
            Color = Color3.fromRGB(75, 53, 38),
            Material = Enum.Material.Wood,
            CFrame = CFrame.new(center + Vector3.new(17, 8, -13)),
            CanCollide = false,
        })
        flagPole.Shape = Enum.PartType.Cylinder
        flagPole.Orientation = Vector3.new(0, 0, 90)
        local captainFlag = createPart(upgrades, {
            Name = "CaptainPennant",
            Size = Vector3.new(0.2, 3.5, 4.5),
            Color = accent,
            Material = Enum.Material.Fabric,
            CFrame = CFrame.new(center + Vector3.new(17.35, 9.2, -13)),
            CanCollide = false,
        })
        captainFlag.Transparency = 0.08
    end
end

local function refreshHarborForPlayer(player)
    local data = playerData[player]
    local plot = playerPlots[player]
    if not data or not plot or plot:GetAttribute("OwnerId") ~= player.UserId then return end
    decoratePlot(plot, data.HarborLevel)
end

refreshHarborProgress = function(player)
    local data = playerData[player]
    local plot = playerPlots[player]
    if not data or not plot or plot:GetAttribute("OwnerId") ~= player.UserId then return end
            local terminal = plot:FindFirstChild("UpgradeTerminal")
            local terminalGui = terminal and terminal:FindFirstChildOfClass("BillboardGui")
            local terminalLabel = terminalGui and terminalGui:FindFirstChildOfClass("TextLabel")
            local terminalPrompt = terminal and terminal:FindFirstChildOfClass("ProximityPrompt")
            local cost = upgradeCostFor(player, data.HarborLevel)
            if data.HarborLevel >= Config.MaxHarborLevel then
                if terminalLabel then terminalLabel.Text = "HARBOR UPLINK\nALL ROUTES CHARTED" end
                if terminalPrompt then terminalPrompt.ObjectText = "Harbor Uplink • complete" end
            else
                if terminalLabel then terminalLabel.Text = "HARBOR UPLINK\nNEXT: " .. cost .. " SALVAGE" end
                if terminalPrompt then terminalPrompt.ObjectText = "Harbor Uplink • " .. cost .. " salvage" end
            end

            for biomeIndex = 2, #Config.Biomes do
                local biome = Config.Biomes[biomeIndex]
                local route = plot:FindFirstChild(biome.Name:gsub("%s+", "") .. "HarborRoute")
                local routeGui = route and route:FindFirstChildOfClass("BillboardGui")
                local routeLabel = routeGui and routeGui:FindFirstChildOfClass("TextLabel")
                local routePrompt = route and route:FindFirstChildOfClass("ProximityPrompt")
                local routeLight = route and route:FindFirstChildOfClass("PointLight")
                local unlocked = data.HarborLevel >= biome.RequiredHarborLevel
                if routeLabel then
                    routeLabel.Text = unlocked and (biome.Name:upper() .. "\nROUTE OPEN") or (biome.Name:upper() .. "\nHARBOR LEVEL " .. biome.RequiredHarborLevel)
                end
                if routePrompt then
                    routePrompt.ObjectText = unlocked and (biome.Name .. " • route open") or (biome.Name .. " • Harbor Level " .. biome.RequiredHarborLevel)
                end
                if routeLight then routeLight.Brightness = unlocked and 1.35 or 0.28 end
                for _, decoration in ipairs(plot:GetChildren()) do
                    if decoration.Name == biome.Name:gsub("%s+", "") .. "RoutePylon"
                        or decoration.Name == biome.Name:gsub("%s+", "") .. "RouteCrown"
                        or decoration.Name == biome.Name:gsub("%s+", "") .. "RouteArch" then
                        decoration.Transparency = unlocked and 0.04 or 0.48
                    end
                end
            end

            local sanctuary = plot:FindFirstChild("SkylingSanctuary")
            local sanctuaryGui = sanctuary and sanctuary:FindFirstChildOfClass("BillboardGui")
            local sanctuaryLabel = sanctuaryGui and sanctuaryGui:FindFirstChildOfClass("TextLabel")
            local sanctuaryPrompt = sanctuary and sanctuary:FindFirstChildOfClass("ProximityPrompt")
            local sanctuaryGlow = sanctuary and sanctuary:FindFirstChild("ReadyGlow")
            if sanctuaryLabel then sanctuaryLabel.Text = "SKYLING SANCTUARY\n" .. data.RescueBeacons .. " BEACON READY" end
            if sanctuaryPrompt then sanctuaryPrompt.ObjectText = "Skyling Sanctuary • " .. data.RescueBeacons .. " beacon" end
            if sanctuaryGlow then sanctuaryGlow.Enabled = data.RescueBeacons > 0 end

            local training = plot:FindFirstChild("CrewTraining")
            local trainingGui = training and training:FindFirstChildOfClass("BillboardGui")
            local trainingLabel = trainingGui and trainingGui:FindFirstChildOfClass("TextLabel")
            local trainingPrompt = training and training:FindFirstChildOfClass("ProximityPrompt")
            local trainingGlow = training and training:FindFirstChild("ReadyGlow")
            if data.CrewMate == "" then
                if trainingLabel then trainingLabel.Text = "CREW TRAINING\nCHOOSE A MATE" end
                if trainingPrompt then trainingPrompt.ObjectText = "Crew Training • choose a mate" end
                if trainingGlow then trainingGlow.Enabled = false end
            elseif data.CrewTrainingLevel >= Config.CrewTrainingMax then
                if trainingLabel then trainingLabel.Text = "CREW TRAINING\nMAXED • +" .. data.CrewTrainingLevel .. " SALVAGE" end
                if trainingPrompt then trainingPrompt.ObjectText = "Crew Training • complete" end
                if trainingGlow then trainingGlow.Enabled = false end
            else
                local trainingCost = Config.crewTrainingCost(data.CrewTrainingLevel)
                if trainingLabel then trainingLabel.Text = "CREW TRAINING\nT" .. data.CrewTrainingLevel .. " • " .. trainingCost .. " SALVAGE" end
                if trainingPrompt then trainingPrompt.ObjectText = "Crew Training • " .. trainingCost .. " salvage" end
                if trainingGlow then trainingGlow.Enabled = data.Salvage >= trainingCost end
            end

            local captainLog = plot:FindFirstChild("CaptainLog")
            local logGui = captainLog and captainLog:FindFirstChildOfClass("BillboardGui")
            local logLabel = logGui and logGui:FindFirstChildOfClass("TextLabel")
            local logPrompt = captainLog and captainLog:FindFirstChildOfClass("ProximityPrompt")
            local logGlow = captainLog and captainLog:FindFirstChild("ReadyGlow")
            local today = currentDay()
            if data.LastDailyClaimDay == today then
                if logLabel then logLabel.Text = "CAPTAIN'S LOG\nRETURN TOMORROW" end
                if logPrompt then logPrompt.ObjectText = "Captain's Log • claimed today" end
                if logGlow then logGlow.Enabled = false end
            else
                local streak = nextDailyStreak(data, today)
                local reward = Config.dailyRewardFor(streak)
                local streakLabel = streak >= Config.DailyRewardStreakMax and "MAX STREAK" or "DAY " .. streak
                if logLabel then logLabel.Text = "CAPTAIN'S LOG\n+" .. reward .. " SALVAGE • " .. streakLabel end
                if logPrompt then logPrompt.ObjectText = "Claim daily reward • +" .. reward .. " salvage" end
                if logGlow then logGlow.Enabled = true end
            end

            local ledger = plot:FindFirstChild("ContractLedger")
            local ledgerGui = ledger and ledger:FindFirstChildOfClass("BillboardGui")
            local ledgerLabel = ledgerGui and ledgerGui:FindFirstChildOfClass("TextLabel")
            local ledgerPrompt = ledger and ledger:FindFirstChildOfClass("ProximityPrompt")
            if ledgerLabel then ledgerLabel.Text = "CAPTAIN'S CONTRACT\n" .. data.ContractProgress .. " / " .. Config.ContractGoal .. " CRATES" end
            if ledgerPrompt then ledgerPrompt.ObjectText = "Captain's Contract • " .. data.ContractProgress .. " / " .. Config.ContractGoal end

            local guestBook = plot:FindFirstChild("GuestBook")
            local guestGui = guestBook and guestBook:FindFirstChildOfClass("BillboardGui")
            local guestLabel = guestGui and guestGui:FindFirstChildOfClass("TextLabel")
            if guestLabel then guestLabel.Text = "GUEST LOG\n" .. data.HarborVisits .. " VISITS" end

            local sign = plot:FindFirstChild("HarborSign")
            local signGui = sign and sign:FindFirstChildOfClass("BillboardGui")
            local signLabel = signGui and signGui:FindFirstChildOfClass("TextLabel")
            if signLabel then signLabel.Text = player.DisplayName .. "'S HARBOR\n" .. Config.explorerTitleForLevel(data.ExplorerLevel):upper() end
end

local function decorateSkylings(plot, rescuedCount)
    local existing = plot:FindFirstChild("Skylings")
    if existing then existing:Destroy() end
    local skylings = Instance.new("Folder")
    skylings.Name = "Skylings"
    skylings.Parent = plot

    local center = plot:GetAttribute("Center")
    local visibleCount = math.min(rescuedCount, Config.MaxVisibleSkylings)
    for index = 1, visibleCount do
        local name, color = Config.skylingFor(index)
        local angle = math.rad(220 + ((index - 1) * (100 / math.max(visibleCount, 1))))
        local position = center + Vector3.new(math.cos(angle) * 13, 5.5, math.sin(angle) * 13)
        local skyling = Instance.new("Model")
        skyling.Name = name
        skyling.Parent = skylings

        local body = createPart(skyling, {
            Name = "Body",
            Size = Vector3.new(3.2, 3.2, 3.2),
            Color = color,
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(position),
            CanCollide = false,
        })
        body.Shape = Enum.PartType.Ball
        local wing = createPart(skyling, {
            Name = "Wing",
            Size = Vector3.new(4, 0.35, 1.6),
            Color = color:Lerp(Color3.new(1, 1, 1), 0.35),
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(position + Vector3.new(0, 0, 0.25)),
            CanCollide = false,
        })
        addBillboard(body, name, color:Lerp(Color3.new(1, 1, 1), 0.45))
        TweenService:Create(body, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            CFrame = body.CFrame * CFrame.new(0, 0.7, 0),
        }):Play()
        TweenService:Create(wing, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            CFrame = wing.CFrame * CFrame.new(0, 0.7, 0),
        }):Play()
    end

    if rescuedCount >= 3 then
        local totem = createPart(skylings, {
            Name = "SkylingBondTotem",
            Size = Vector3.new(7, 1.2, 1.2),
            Color = Theme.Violet,
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(center + Vector3.new(2, 6.5, 4)),
            CanCollide = false,
        })
        totem.Shape = Enum.PartType.Cylinder
        totem.Orientation = Vector3.new(0, 0, 90)
        local light = Instance.new("PointLight")
        light.Color = Theme.Violet
        light.Range = 12
        light.Brightness = 1.25
        light.Parent = totem
        if rescuedCount >= 6 then
            for index = 1, 3 do
                local angle = (math.pi * 2 / 3) * index
                local halo = createPart(skylings, {
                    Name = "SkylingHalo",
                    Size = Vector3.new(1.5, 1.5, 1.5),
                    Color = Theme.Mint,
                    Material = Enum.Material.Neon,
                    CFrame = CFrame.new(center + Vector3.new(2 + math.cos(angle) * 3, 8.5, 4 + math.sin(angle) * 3)),
                    CanCollide = false,
                })
                halo.Shape = Enum.PartType.Ball
            end
        end
    end
end

pulseSanctuary = function(player)
    for _, plot in ipairs(plots) do
        if plot:GetAttribute("OwnerId") == player.UserId then
            local sanctuary = plot:FindFirstChild("SkylingSanctuary")
            if not sanctuary then return end
            local originalSize = sanctuary.Size
            local light = sanctuary:FindFirstChild("BeaconPulse") or Instance.new("PointLight")
            light.Name = "BeaconPulse"
            light.Color = Theme.Violet
            light.Range = 15
            light.Brightness = 0
            light.Parent = sanctuary
            TweenService:Create(sanctuary, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = originalSize + Vector3.new(1.2, 0, 1.2),
            }):Play()
            TweenService:Create(light, TweenInfo.new(0.22), { Brightness = 2.4 }):Play()
            task.delay(0.28, function()
                if sanctuary.Parent then
                    TweenService:Create(sanctuary, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = originalSize }):Play()
                    TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
                end
            end)
            return
        end
    end
end

local function buildPlot(world, index)
    local angle = (math.pi * 2 / Config.PlotCount) * (index - 1)
    local center = Vector3.new(math.cos(angle) * Config.PlotRadius, 35, math.sin(angle) * Config.PlotRadius)
    local plot = Instance.new("Model")
    plot.Name = "HarborPlot" .. index
    plot:SetAttribute("Center", center)
    plot.Parent = world

    local island = createPart(plot, {
        Name = "SkyHarbor",
        -- A Roblox cylinder's length is its X dimension. After rotating it
        -- upright, this makes a 5-stud-thick circular island, not a tall pole.
        Size = Vector3.new(5, Config.HarborIslandDiameter, Config.HarborIslandDiameter),
        Color = Theme.Harbor,
        Material = Enum.Material.Grass,
        CFrame = CFrame.new(center),
    })
    island.Shape = Enum.PartType.Cylinder
    island.Orientation = Vector3.new(0, 0, 90)
    createIslandUnderside(plot, center, Config.HarborIslandDiameter, Theme.HarborDark)
    createCloud(plot, center - Vector3.new(0, 9, 0), 10)
    createRockCluster(plot, center, 30, 6, Theme.HarborDark)
    createSkyTree(plot, center + Vector3.new(18, 4, 5), Theme.Harbor, 0.75)
    createSkyTree(plot, center + Vector3.new(-17, 4, 10), Theme.Mint, 0.62)
    local outwardDirection = Vector3.new(center.X, 0, center.Z).Unit
    createHarborArrivalDeck(plot, center, outwardDirection, index % 2 == 0 and Theme.Aqua or Theme.Mint)

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "HarborSpawn"
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.CFrame = CFrame.new(center + Vector3.new(0, 4, 0))
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Transparency = 0.25
    spawn.Color = Theme.Mint
    spawn.Parent = plot

    local sign = createPart(plot, {
        Name = "HarborSign",
        Size = Vector3.new(1, 5, 7),
        Color = Theme.HarborDark,
        CFrame = CFrame.new(center + Vector3.new(0, 5, -20)),
    })
    addBillboard(sign, "UNCLAIMED SKY HARBOR", Theme.Text)

    local terminal = createPart(plot, {
        Name = "UpgradeTerminal",
        Size = Vector3.new(4, 5, 4),
        Color = Theme.PanelRaised,
        Material = Enum.Material.Metal,
        CFrame = CFrame.new(center + Vector3.new(13, 4, 11)),
    })
    addBillboard(terminal, "HARBOR UPLINK", Theme.Aqua)
    local prompt = addPrompt(terminal, "Upgrade", "Harbor Uplink", 0.5)
    prompt.Triggered:Connect(function(player)
        if not playerData[player] or not PlayerRuntime.canInteract(player, terminal, prompt.MaxActivationDistance) then return end
        if plot:GetAttribute("OwnerId") ~= player.UserId then
            sendStatus(player, "This harbor belongs to another salvager.", "Warning")
            return
        end
        local data = playerData[player]
        if data.HarborLevel >= Config.MaxHarborLevel then
            sendStatus(player, "Your harbor has charted every available route.", "Info")
            return
        end
        local cost = upgradeCostFor(player, data.HarborLevel)
        if data.Salvage < cost then
            sendStatus(player, "You need " .. cost .. " salvage for the next upgrade.", "Warning")
            return
        end
        setSalvage(player, data.Salvage - cost)
        setLevel(player, data.HarborLevel + 1)
        decoratePlot(plot, data.HarborLevel)
        refreshHarborProgress(player)
        local landmark = ({
            [2] = "Airship dock added.",
            [3] = "Harbor lanterns lit.",
            [4] = "Sky lookout raised.",
        })[data.HarborLevel]
        sendStatus(player, "Harbor upgraded to level " .. data.HarborLevel .. "!" .. (landmark and "  •  " .. landmark or ""), "Success")
    end)

    local navigator = createPart(plot, {
        Name = "ExpeditionNavigator",
        Size = Vector3.new(5, 1, 5),
        Color = Theme.Gold,
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(center + Vector3.new(-14, 4, 12)),
    })
    addBillboard(navigator, "WRECK NAVIGATOR\nBEGIN YOUR FIRST CONTRACT", Theme.Gold:Lerp(Theme.Text, 0.35))
    local navigatorPrompt = addPrompt(navigator, "Travel", "Whispering Wreck", 0.25)
    navigatorPrompt.Triggered:Connect(function(player)
        if not playerData[player] or not PlayerRuntime.canInteract(player, navigator, navigatorPrompt.MaxActivationDistance) then return end
        if plot:GetAttribute("OwnerId") ~= player.UserId then
            sendStatus(player, "Only the harbor captain may use this navigator.", "Warning")
            return
        end
        teleportPlayer(player, Vector3.new(0, 35, -12))
    end)

    -- Higher-value biomes remain visible from home as aspirational routes, and
    -- become direct travel pads once the captain reaches the required level.
    local routeOffsets = {
        [2] = Vector3.new(17, 4, -13),
        [3] = Vector3.new(20, 4, -5),
    }
    for biomeIndex = 2, #Config.Biomes do
        local routeBiomeIndex = biomeIndex
        local biome = Config.Biomes[biomeIndex]
        local routePosition = center + routeOffsets[biomeIndex]
        local route = createPart(plot, {
            Name = biome.Name:gsub("%s+", "") .. "HarborRoute",
            Size = Vector3.new(4, 1, 4),
            Color = biome.Color:Lerp(Theme.Ink, 0.18),
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(routePosition),
        })
        for _, side in ipairs({ -1, 1 }) do
            local pylon = createPart(plot, {
                Name = biome.Name:gsub("%s+", "") .. "RoutePylon",
                Size = Vector3.new(0.5, 5, 0.5),
                Color = biome.Color:Lerp(Theme.Text, 0.12),
                Material = Enum.Material.Neon,
                CFrame = CFrame.new(routePosition + Vector3.new(side * 2.15, 2.4, 0)),
                CanCollide = false,
            })
            local crown = createPart(plot, {
                Name = biome.Name:gsub("%s+", "") .. "RouteCrown",
                Size = Vector3.new(0.9, 0.9, 0.9),
                Color = Theme.Text,
                Material = Enum.Material.Neon,
                CFrame = pylon.CFrame * CFrame.new(0, 2.8, 0),
                CanCollide = false,
            })
            crown.Shape = Enum.PartType.Ball
        end
        local arch = createPart(plot, {
            Name = biome.Name:gsub("%s+", "") .. "RouteArch",
            Size = Vector3.new(4.8, 0.35, 0.35),
            Color = biome.Color:Lerp(Theme.Text, 0.16),
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(routePosition + Vector3.new(0, 5, 0)),
            CanCollide = false,
        })
        addBillboard(route, biome.Name:upper() .. "\nROUTE • HARBOR LEVEL " .. biome.RequiredHarborLevel, Theme.Text)
        local routeLight = Instance.new("PointLight")
        routeLight.Color = biome.Color
        routeLight.Brightness = 0.8
        routeLight.Range = 8
        routeLight.Shadows = false
        routeLight.Parent = route
        local routePrompt = addPrompt(route, "Travel", biome.Name, 0.35)
        routePrompt.Triggered:Connect(function(player)
            if not playerData[player] or not PlayerRuntime.canInteract(player, route, routePrompt.MaxActivationDistance) then return end
            if plot:GetAttribute("OwnerId") ~= player.UserId then
                sendStatus(player, "Only the harbor captain may use this route.", "Warning")
                return
            end
            travelToBiome(player, routeBiomeIndex)
        end)
    end

    local sanctuary = createPart(plot, {
        Name = "SkylingSanctuary",
        Size = Vector3.new(5, 1, 5),
        Color = Theme.Violet,
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(center + Vector3.new(0, 4, 15)),
    })
    addBillboard(sanctuary, "SKYLING SANCTUARY", Theme.Violet:Lerp(Theme.Text, 0.4))
    local sanctuaryGlow = Instance.new("PointLight")
    sanctuaryGlow.Name = "ReadyGlow"
    sanctuaryGlow.Color = Theme.Violet
    sanctuaryGlow.Brightness = 1.4
    sanctuaryGlow.Range = 13
    sanctuaryGlow.Shadows = false
    sanctuaryGlow.Enabled = false
    sanctuaryGlow.Parent = sanctuary
    local sanctuaryPrompt = addPrompt(sanctuary, "Welcome", "Skyling Sanctuary", 0.4)
    sanctuaryPrompt.Triggered:Connect(function(player)
        if not playerData[player] or not PlayerRuntime.canInteract(player, sanctuary, sanctuaryPrompt.MaxActivationDistance) then return end
        if plot:GetAttribute("OwnerId") ~= player.UserId then
            sendStatus(player, "Only the harbor captain may use this sanctuary.", "Warning")
            return
        end
        local data = playerData[player]
        if data.RescueBeacons < 1 then
            sendStatus(player, "Complete your expedition contract to earn a rescue beacon.", "Warning")
            return
        end
        local previousBonus = Config.skylingSalvageBonus(data.SkylingsRescued)
        data.RescueBeacons -= 1
        data.SkylingsRescued += 1
        local name = Config.skylingFor(data.SkylingsRescued)
        decorateSkylings(plot, data.SkylingsRescued)
        syncAdventure(player)
        local newBonus = Config.skylingSalvageBonus(data.SkylingsRescued)
        local message = name .. " joined your sky harbor!"
        if newBonus > previousBonus then message ..= "  •  Skyling bond: +" .. newBonus .. " salvage." end
        sendStatus(player, message, "Success")
    end)

    local trainingTable = createPart(plot, {
        Name = "CrewTraining",
        Size = Vector3.new(4, 3.5, 4),
        Color = Theme.Coral:Lerp(Theme.PanelRaised, 0.34),
        Material = Enum.Material.WoodPlanks,
        CFrame = CFrame.new(center + Vector3.new(-16, 5, -5)),
    })
    addBillboard(trainingTable, "CREW TRAINING\nCHOOSE A MATE", Theme.Coral:Lerp(Theme.Text, 0.35))
    local trainingGlow = Instance.new("PointLight")
    trainingGlow.Name = "ReadyGlow"
    trainingGlow.Color = Theme.Coral
    trainingGlow.Brightness = 1.1
    trainingGlow.Range = 10
    trainingGlow.Shadows = false
    trainingGlow.Enabled = false
    trainingGlow.Parent = trainingTable
    local trainingPrompt = addPrompt(trainingTable, "Train", "Crew Training", 0.5)
    trainingPrompt.Triggered:Connect(function(player)
        if not playerData[player] or not PlayerRuntime.canInteract(player, trainingTable, trainingPrompt.MaxActivationDistance) then return end
        if plot:GetAttribute("OwnerId") ~= player.UserId then
            sendStatus(player, "Only the harbor captain can train their crew mate.", "Warning")
            return
        end
        local data = playerData[player]
        if not data then return end
        if data.CrewMate == "" then
            sendStatus(player, "Choose a crew mate before starting training.", "Warning")
            return
        end
        if data.CrewTrainingLevel >= Config.CrewTrainingMax then
            sendStatus(player, "Your crew mate's training is already complete.", "Info")
            return
        end
        local cost = Config.crewTrainingCost(data.CrewTrainingLevel)
        if data.Salvage < cost then
            sendStatus(player, "You need " .. cost .. " salvage for crew training.", "Warning")
            return
        end
        setSalvage(player, data.Salvage - cost)
        data.CrewTrainingLevel += 1
        syncAdventure(player)
        sendStatus(player, "Crew training level " .. data.CrewTrainingLevel .. " complete! +" .. data.CrewTrainingLevel .. " salvage on recoveries.", "Success")
    end)

    local captainLog = createPart(plot, {
        Name = "CaptainLog",
        Size = Vector3.new(2.8, 3.5, 2.8),
        Color = Theme.Gold:Lerp(Theme.HarborDark, 0.36),
        Material = Enum.Material.WoodPlanks,
        CFrame = CFrame.new(center + Vector3.new(8, 4, 16)),
    })
    addBillboard(captainLog, "CAPTAIN'S LOG", Theme.Gold:Lerp(Theme.Text, 0.35))
    local logGlow = Instance.new("PointLight")
    logGlow.Name = "ReadyGlow"
    logGlow.Color = Theme.Gold
    logGlow.Brightness = 1.25
    logGlow.Range = 11
    logGlow.Shadows = false
    logGlow.Enabled = false
    logGlow.Parent = captainLog
    local logPrompt = addPrompt(captainLog, "Claim", "Captain's Log", 0.4)
    logPrompt.Triggered:Connect(function(player)
        if not playerData[player] or not PlayerRuntime.canInteract(player, captainLog, logPrompt.MaxActivationDistance) then return end
        if plot:GetAttribute("OwnerId") ~= player.UserId then
            sendStatus(player, "Only the harbor captain may claim this log.", "Warning")
            return
        end
        local data = playerData[player]
        if not data then return end
        local today = currentDay()
        if data.LastDailyClaimDay == today then
            sendStatus(player, "Today's captain's log is already claimed. Return tomorrow.", "Info")
            return
        end
        data.DailyStreak = nextDailyStreak(data, today)
        data.LastDailyClaimDay = today
        local reward = Config.dailyRewardFor(data.DailyStreak)
        setSalvage(player, data.Salvage + reward)
        syncAdventure(player)
        local streakStatus = data.DailyStreak >= Config.DailyRewardStreakMax and "Max daily streak!" or ("Day " .. data.DailyStreak .. " streak.")
        sendStatus(player, "Captain's log claimed! +" .. reward .. " salvage • " .. streakStatus, "Success")
    end)

    local contractLedger = createPart(plot, {
        Name = "ContractLedger",
        Size = Vector3.new(3.5, 4.5, 1),
        Color = Color3.fromRGB(104, 75, 48),
        Material = Enum.Material.WoodPlanks,
        CFrame = CFrame.new(center + Vector3.new(12, 5, -10)),
    })
    addBillboard(contractLedger, "CAPTAIN'S CONTRACT\n0 / " .. Config.ContractGoal .. " CRATES", Theme.Mint:Lerp(Theme.Text, 0.35))
    local contractPrompt = addPrompt(contractLedger, "Review", "Captain's Contract", 0.2)
    contractPrompt.Triggered:Connect(function(player)
        if not playerData[player] or not PlayerRuntime.canInteract(player, contractLedger, contractPrompt.MaxActivationDistance) then return end
        if plot:GetAttribute("OwnerId") ~= player.UserId then
            sendStatus(player, "This contract belongs to another harbor captain.", "Warning")
            return
        end
        local data = playerData[player]
        if not data then return end
        sendStatus(player, "Contract: " .. data.ContractProgress .. " / " .. Config.ContractGoal .. " crates. Complete it for a rescue beacon.", "Info")
    end)

    local guestBook = createPart(plot, {
        Name = "GuestBook",
        Size = Vector3.new(2.5, 3, 2.5),
        Color = Theme.Gold:Lerp(Theme.HarborDark, 0.28),
        Material = Enum.Material.WoodPlanks,
        CFrame = CFrame.new(center + Vector3.new(-10, 4, -13)),
    })
    addBillboard(guestBook, "GUEST LOG\n0 VISITS", Theme.Gold:Lerp(Theme.Text, 0.35))
    local guestPrompt = addPrompt(guestBook, "Sign", "Harbor Guest Log", 0.4)
    guestPrompt.Triggered:Connect(function(player)
        if not playerData[player] or not PlayerRuntime.canInteract(player, guestBook, guestPrompt.MaxActivationDistance) then return end
        local ownerId = plot:GetAttribute("OwnerId")
        if not ownerId or ownerId == player.UserId then
            sendStatus(player, "Invite another salvager to sign your guest log.", "Info")
            return
        end
        local owner = Players:GetPlayerByUserId(ownerId)
        if not owner or not playerData[owner] then return end
        guestBookEntries[player.UserId] = guestBookEntries[player.UserId] or {}
        if guestBookEntries[player.UserId][ownerId] then
            sendStatus(player, "You have already signed this harbor's log this session.", "Info")
            return
        end
        guestBookEntries[player.UserId][ownerId] = true
        playerData[owner].HarborVisits += 1
        syncAdventure(owner)
        setSalvage(player, playerData[player].Salvage + Config.HarborVisitReward)
        sendStatus(player, "Guest log signed! +" .. Config.HarborVisitReward .. " salvage.", "Success")
        sendStatus(owner, player.DisplayName .. " visited your harbor!", "Info")
    end)
    plots[index] = plot
end

local function returnToHarbor(player)
    local plot = playerPlots[player]
    if plot and plot:GetAttribute("OwnerId") == player.UserId then
        return teleportPlayer(player, plot:GetAttribute("Center") + Vector3.new(0, 7, 0))
    end
    sendStatus(player, "You do not have an assigned harbor in this server.", "Warning")
    return false
end

local function rescueFromSkyfall(player)
    local plot = playerPlots[player]
    local destination = plot and plot:GetAttribute("Center") + Vector3.new(0, 8, 0) or Vector3.new(0, 35, -12)
    if not teleportPlayer(player, destination) then return end
    sendStatus(player, "Skyway rescue line engaged—back on solid ground.", "Info")
end

travelToBiome = function(player, biomeIndex)
    local data = playerData[player]
    local biome = Config.Biomes[biomeIndex]
    local destination = biomePositions[biomeIndex]
    if not data or not biome or not destination then return end
    if data.HarborLevel < biome.RequiredHarborLevel then
        sendStatus(player, biome.Name .. " unlocks at Harbor Level " .. biome.RequiredHarborLevel .. ".", "Warning")
        return
    end
    if not teleportPlayer(player, destination + Vector3.new(0, 8, -10)) then return end
    sendStatus(player, "Welcome to " .. biome.Name .. ". Salvage is more valuable here!", "Info")
end

local function createBiomeGuardian(parent, position, biome)
    local guardian = Instance.new("Model")
    guardian.Name = biome.GuardianName:gsub("%s+", "")
    guardian.Parent = parent
    local body = createPart(guardian, {
        Name = "GuardianBody",
        Size = Vector3.new(5, 5, 5),
        Color = biome.Color:Lerp(Theme.Ink, 0.12),
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(position),
        CanCollide = false,
    })
    body.Shape = Enum.PartType.Ball
    local bodyColor = body.Color
    local eye = createPart(guardian, {
        Name = "GuardianEye",
        Size = Vector3.new(1.5, 1.5, 1.5),
        Color = Theme.Gold,
        Material = Enum.Material.Neon,
        CFrame = body.CFrame * CFrame.new(0, 0, -2.25),
        CanCollide = false,
    })
    eye.Shape = Enum.PartType.Ball
    local animatedParts = { body, eye }
    for _, direction in ipairs({ -1, 1 }) do
        local horn = createPart(guardian, {
            Name = "GuardianHorn",
            Size = Vector3.new(3.6, 0.45, 0.45),
            Color = biome.Color:Lerp(Theme.Text, 0.2),
            Material = Enum.Material.Neon,
            CFrame = body.CFrame * CFrame.new(direction * 2.1, 1.3, 0) * CFrame.Angles(0, 0, math.rad(direction * 28)),
            CanCollide = false,
        })
        horn.Shape = Enum.PartType.Cylinder
        table.insert(animatedParts, horn)
    end
    local light = Instance.new("PointLight")
    light.Color = biome.Color
    light.Range = 13
    light.Brightness = 1.4
    light.Parent = body
    -- One rhythm and world-space offset keep rotated horns attached to the body.
    local hoverInfo = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    for _, part in ipairs(animatedParts) do
        TweenService:Create(part, hoverInfo, {
            CFrame = part.CFrame + Vector3.new(0, 0.62, 0),
        }):Play()
    end
    local guardianLabel = addBillboard(body, biome.GuardianName:upper() .. "\nHEALTH " .. biome.GuardianHealth .. " • +" .. biome.GuardianReward .. " SALVAGE", Theme.Gold:Lerp(Theme.Text, 0.2))
    local strike = addPrompt(body, "Strike", biome.GuardianName, 0.35)
    local health = biome.GuardianHealth
    local alive = true
    local attack = GuardianAttack.new()
    local attackWarning
    local lastStrikeByPlayer = {}
    strike.Triggered:Connect(function(player)
        if not alive or not playerData[player] then return end
        if not PlayerRuntime.canInteract(player, body, strike.MaxActivationDistance) then return end
        local now = os.clock()
        if now - (lastStrikeByPlayer[player] or 0) < 0.45 then return end
        lastStrikeByPlayer[player] = now
        local mate = crewMateFor(player)
        local strikeDamage = mate and mate.GuardianStrike or 1
        health -= strikeDamage
        body.Color = Theme.Text
        task.delay(0.1, function()
            if body.Parent and alive then body.Color = bodyColor end
        end)
        if health > 0 then
            local interruptedNow = attack:Interrupt(now, mate and mate.GuardianInterruptCooldown)
            if interruptedNow then
                if attackWarning then attackWarning.Transparency = 1 end
                eye.Color = Theme.Aqua
            end
            guardianLabel.Text = biome.GuardianName:upper() .. "\nHEALTH " .. health .. " • +" .. biome.GuardianReward .. " SALVAGE"
            sendStatus(player, biome.GuardianName .. ": " .. health .. " health left."
                .. (interruptedNow and " Harpoon interrupt! Charged attack cancelled."
                    or (strikeDamage > 1 and " " .. mate.Name .. " hits for " .. strikeDamage .. "!" or "")), "Info")
            return
        end
        alive = false
        local rewardMultiplier = mate and mate.GuardianRewardMultiplier or 1
        local earned = math.floor(salvageRewardFor(player, biome.GuardianReward, false) * rewardMultiplier + 0.5)
        setSalvage(player, playerData[player].Salvage + earned)
        local rankedUp = awardExplorerXp(player, earned)
        if crew:IsMember(player) then
            local assistReward = math.max(1, math.floor(earned * Config.GuardianAssistRewardPercent + 0.5))
            for _, teammate in ipairs(crew:GetPlayers()) do
                if teammate ~= player and playerData[teammate] and PlayerRuntime.canInteract(teammate, body, 32) then
                    setSalvage(teammate, playerData[teammate].Salvage + assistReward)
                    sendStatus(teammate, "Guardian assist! +" .. assistReward .. " salvage for backing " .. player.DisplayName .. ".", "Success")
                end
            end
        end
        sendStatus(player, biome.GuardianName .. " defeated! +" .. earned .. " salvage." .. (rewardMultiplier > 1 and " " .. mate.Name .. "'s Prize Rig boosted the payout!" or "") .. (rankedUp and " Rank up!" or ""), "Success")
        guardian:Destroy()
        task.delay(55, function()
            if parent.Parent then createBiomeGuardian(parent, position, biome) end
        end)
    end)
    local warning = createPart(guardian, {
        Name = "AttackWarning", Size = Vector3.new(20, 20, 20),
        Color = Theme.Coral, Material = Enum.Material.Neon,
        CFrame = CFrame.new(position), CanCollide = false,
    })
    warning.Shape = Enum.PartType.Ball
    attackWarning = warning
    warning.Transparency = 1
    warning.CanTouch = false
    warning.CanQuery = false
    warning.CastShadow = false
    local function targetsInRange()
        local targets = {}
        for _, player in ipairs(Players:GetPlayers()) do
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if playerData[player] and root and humanoid and humanoid.Health > 0
                and (root.Position - position).Magnitude <= 10 then
                table.insert(targets, { Player = player, Humanoid = humanoid })
            end
        end
        return targets
    end
    task.spawn(function()
        while alive and guardian.Parent do
            local targets = targetsInRange()
            if #targets > 0 then
                attack:Begin()
                -- One shared wind-up: the visible sphere is the exact damage radius.
                warning.Transparency = 0.82
                eye.Size = Vector3.new(2.1, 2.1, 2.1)
                light.Brightness = 3.1
                for _, target in ipairs(targets) do
                    sendStatus(target.Player, biome.GuardianName .. " is charging! Move outside the red sphere!", "Warning")
                end
                task.wait(0.9)
                if not alive or not guardian.Parent then break end
                local canDamage = attack:Resolve()
                -- Re-evaluate at impact: escaping or defeating it cancels damage.
                for _, target in ipairs(canDamage and targetsInRange() or {}) do
                    local mate = crewMateFor(target.Player)
                    local multiplier = mate and mate.GuardianDamageMultiplier or 1
                    local damage = math.max(1, math.floor(biome.GuardianDamage * multiplier + 0.5))
                    target.Humanoid:TakeDamage(damage)
                    sendStatus(target.Player, biome.GuardianName .. " hits for " .. damage .. ". Attack while it recovers!", "Warning")
                end
                warning.Transparency = 1
                eye.Size = Vector3.new(1.5, 1.5, 1.5)
                eye.Color = Theme.Gold
                light.Brightness = 1.4
                task.wait(2) -- Safe opening to approach and strike.
            else
                task.wait(0.25)
            end
        end
    end)
end

local function buildBiome(world, biome, center)
    local expedition = Instance.new("Model")
    expedition.Name = biome.Name:gsub("%s+", "")
    expedition.Parent = world

    local island = createPart(expedition, {
        Name = "ExpeditionIsland",
        Size = Vector3.new(9, Config.BiomeIslandDiameter, Config.BiomeIslandDiameter),
        Color = biome.Color,
        Material = Enum.Material.Slate,
        CFrame = CFrame.new(center),
    })
    island.Shape = Enum.PartType.Cylinder
    island.Orientation = Vector3.new(0, 0, 90)
    createIslandUnderside(expedition, center, Config.BiomeIslandDiameter, biome.Color)
    createCloud(expedition, center - Vector3.new(0, 14, 0), 13)
    createRockCluster(expedition, center, 43, 8, biome.Color)
    createCrystalCluster(expedition, center + Vector3.new(16, 3, 14), biome.Color)
    createBiomeLandmarks(expedition, biome, center)

    local landingNest = createPart(expedition, {
        Name = "ExpeditionLandingNest",
        Size = Vector3.new(1.1, 15, 15),
        Color = biome.Color:Lerp(Theme.PanelRaised, 0.34),
        Material = Enum.Material.Metal,
        CFrame = CFrame.new(center + Vector3.new(0, 4.65, -10)),
    })
    landingNest.Shape = Enum.PartType.Cylinder
    landingNest.Orientation = Vector3.new(0, 0, 90)
    local landingLight = Instance.new("PointLight")
    landingLight.Color = biome.Color
    landingLight.Range = 12
    landingLight.Brightness = 0.8
    landingLight.Parent = landingNest

    local beacon = createPart(expedition, {
        Name = "BiomeBeacon",
        Size = Vector3.new(4, 12, 4),
        Color = biome.Color:Lerp(Color3.new(1, 1, 1), 0.3),
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(center + Vector3.new(0, 10, 0)),
    })
    addBillboard(beacon, biome.Name:upper() .. "\n+" .. biome.SalvageValue .. " SALVAGE", Theme.Text, { MaxDistance = 110 })
    createExpeditionCache(expedition, center + Vector3.new(0, 7, 12), biome)
    for index = 1, biome.GuardianCount do
        local angle = (math.pi * 2 / biome.GuardianCount) * index
        createBiomeGuardian(expedition, center + Vector3.new(math.cos(angle) * 20, 7, math.sin(angle) * 20), biome)
    end
    for index = 1, 9 do
        local angle = (math.pi * 2 / 9) * index
        createCollectible(expedition, center + Vector3.new(math.cos(angle) * 24, 7, math.sin(angle) * 24), biome.SalvageValue, false)
    end

    local returnPad = createPart(expedition, {
        Name = "ReturnNavigator",
        Size = Vector3.new(6, 1, 6),
        Color = Theme.Mint,
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(center + Vector3.new(0, 6, -15)),
    })
    addBillboard(returnPad, "RETURN TO HARBOR", Theme.Mint:Lerp(Theme.Text, 0.4))
    addPrompt(returnPad, "Return", "Harbor Navigator", 0.25).Triggered:Connect(returnToHarbor)
end

local function buildWorld()
    local existing = workspace:FindFirstChild("SkyboundWorld")
    if existing then existing:Destroy() end
    local world = Instance.new("Folder")
    world.Name = "SkyboundWorld"
    world.Parent = workspace

    Lighting.ClockTime = 13.5
    Lighting.Brightness = 2.1
    Lighting.Ambient = Theme.Sky:Lerp(Theme.Ink, 0.44)
    Lighting.OutdoorAmbient = Theme.Sky:Lerp(Theme.Cloud, 0.15)
    Lighting.ColorShift_Top = Theme.Sky:Lerp(Theme.Cloud, 0.2)
    Lighting.ColorShift_Bottom = Theme.Sky:Lerp(Theme.Ink, 0.15)

    local atmosphere = Lighting:FindFirstChild("SkyboundAtmosphere") or Instance.new("Atmosphere")
    atmosphere.Name = "SkyboundAtmosphere"
    atmosphere.Color = Theme.SkyHaze
    atmosphere.Decay = Theme.Sky
    atmosphere.Density = 0.26
    atmosphere.Haze = 1.1
    atmosphere.Glare = 0.08
    atmosphere.Parent = Lighting

    local correction = Lighting:FindFirstChild("SkyboundColor") or Instance.new("ColorCorrectionEffect")
    correction.Name = "SkyboundColor"
    correction.Brightness = 0.02
    correction.Contrast = 0.07
    correction.Saturation = -0.03
    correction.TintColor = Theme.SkyHaze
    correction.Parent = Lighting

    local bloom = Lighting:FindFirstChild("SkyboundBloom") or Instance.new("BloomEffect")
    bloom.Name = "SkyboundBloom"
    bloom.Intensity = 0.22
    bloom.Size = 18
    bloom.Threshold = 1.4
    bloom.Parent = Lighting

    local sunRays = Lighting:FindFirstChild("SkyboundSunRays") or Instance.new("SunRaysEffect")
    sunRays.Name = "SkyboundSunRays"
    sunRays.Intensity = 0.055
    sunRays.Spread = 0.72
    sunRays.Parent = Lighting

    -- The playable space is split across islands. Streaming keeps distant
    -- scenery from costing clients the same as the island they are exploring.
    pcall(function()
        workspace.StreamingEnabled = true
        workspace.StreamingTargetRadius = 384
        workspace.StreamingMinRadius = 128
    end)

    for index = 1, Config.PlotCount do buildPlot(world, index) end

    local expedition = Instance.new("Model")
    expedition.Name = "WhisperingWreck"
    expedition.Parent = world
    local islandCenter = Vector3.new(0, 24, 0)
    local island = createPart(expedition, {
        Name = "ExpeditionIsland",
        Size = Vector3.new(9, Config.WreckIslandDiameter, Config.WreckIslandDiameter),
        Color = Theme.Slate,
        Material = Enum.Material.Slate,
        CFrame = CFrame.new(islandCenter),
    })
    island.Shape = Enum.PartType.Cylinder
    island.Orientation = Vector3.new(0, 0, 90)
    createIslandUnderside(expedition, islandCenter, Config.WreckIslandDiameter, Theme.Slate)
    createCloud(expedition, islandCenter - Vector3.new(0, 14, 0), 15)
    createRockCluster(expedition, islandCenter, 50, 11, Theme.Slate)
    createWreckSkywayPlaza(expedition, islandCenter)
    createSkyTree(expedition, islandCenter + Vector3.new(26, 4, 15), Theme.Harbor, 0.85)
    createSkyTree(expedition, islandCenter + Vector3.new(-26, 4, -8), Theme.Mint, 0.7)
    createWreckLandmark(expedition, islandCenter + Vector3.new(-17, 5, 13))
    local beacon = createPart(expedition, {
        Name = "ExpeditionBeacon",
        Size = Vector3.new(4, 12, 4),
        Color = Theme.Gold,
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(islandCenter + Vector3.new(0, 10, 0)),
    })
    addBillboard(beacon, "WHISPERING WRECK\nEXPEDITION ZONE", Theme.Gold:Lerp(Theme.Text, 0.35), { MaxDistance = 110 })
    createExpeditionCache(expedition, islandCenter + Vector3.new(0, 7, 10), Config.Biomes[1])
    createBiomeGuardian(expedition, islandCenter + Vector3.new(-4, 7, -28), Config.Biomes[1])

    local guideBoard = createPart(expedition, {
        Name = "IslandGuide",
        Size = Vector3.new(4, 6, 2),
        Color = Theme.PanelRaised,
        Material = Enum.Material.WoodPlanks,
        CFrame = CFrame.new(islandCenter + Vector3.new(0, 6, 19)),
    })
    addBillboard(guideBoard, "ISLAND GUIDE", Theme.Text)
    local guidePrompt = addPrompt(guideBoard, "Read", "Island Guide", 0.2)
    guidePrompt.Triggered:Connect(function(player)
        guideEvent:FireClient(player)
    end)
    for index = 1, 10 do
        local wreckAngle = math.rad(index * 36)
        createCollectible(expedition, islandCenter + Vector3.new(math.cos(wreckAngle) * 42, 7, math.sin(wreckAngle) * 42), Config.NormalSalvageValue, false)
    end

    local returnPad = createPart(expedition, {
        Name = "ReturnNavigator",
        Size = Vector3.new(6, 1, 6),
        Color = Theme.Mint,
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(islandCenter + Vector3.new(0, 6, -17)),
    })
    addBillboard(returnPad, "RETURN TO HARBOR", Theme.Mint:Lerp(Theme.Text, 0.4))
    local returnPrompt = addPrompt(returnPad, "Return", "Harbor Navigator", 0.25)
    returnPrompt.Triggered:Connect(returnToHarbor)

    local crewBoard = createPart(expedition, {
        Name = "CrewBoard",
        Size = Vector3.new(3, 6, 4),
        Color = Theme.PanelRaised,
        Material = Enum.Material.WoodPlanks,
        CFrame = CFrame.new(islandCenter + Vector3.new(13, 6, -13)),
    })
    createCrewExpeditionLandmark(expedition, crewBoard.Position)
    addBillboard(crewBoard, "CREW EXPEDITION\n1–4 PLAYERS • +" .. Config.CrewReward .. " SALVAGE EACH", Theme.Aqua:Lerp(Theme.Text, 0.35))
    local crewPrompt = addPrompt(crewBoard, "Join / Leave", "Crew Expedition", 0.4)
    crewPrompt.Triggered:Connect(function(player)
        if not playerData[player] or not PlayerRuntime.canInteract(player, crewBoard, crewPrompt.MaxActivationDistance) then return end
        if playerData[player].CrewMate == "" then
            sendStatus(player, "Choose your crew mate before joining an expedition.", "Info")
            return
        end
        local joined, warning = crew:ToggleMembership(player)
        if warning then
            sendStatus(player, warning, "Warning")
            return
        end
        sendStatus(player, joined and "Joined the Crew Expedition. Recover regular crates together for shared rewards!" or "You left the Crew Expedition.", "Info")
    end)

    local directory = createPart(expedition, {
        Name = "HarborDirectory",
        Size = Vector3.new(4, 5, 4),
        Color = Theme.Mint:Lerp(Theme.Harbor, 0.25),
        Material = Enum.Material.Metal,
        CFrame = CFrame.new(islandCenter + Vector3.new(-14, 5, -13)),
    })
    addBillboard(directory, "HARBOR DIRECTORY", Theme.Mint:Lerp(Theme.Text, 0.35))
    local directoryPrompt = addPrompt(directory, "Visit", "Another Salvager", 0.35)
    directoryPrompt.Triggered:Connect(function(player)
        if not playerData[player] or not PlayerRuntime.canInteract(player, directory, directoryPrompt.MaxActivationDistance) then return end
        local candidates = {}
        for _, candidate in ipairs(Players:GetPlayers()) do
            local candidatePlot = playerPlots[candidate]
            if candidate ~= player and playerData[candidate] and candidatePlot
                and candidatePlot:GetAttribute("OwnerId") == candidate.UserId then
                table.insert(candidates, candidate)
            end
        end
        if #candidates == 0 then
            sendStatus(player, "No other harbors are online. Invite a friend to visit!", "Info")
            return
        end
        table.sort(candidates, function(a, b) return a.UserId < b.UserId end)
        local nextIndex = (player:GetAttribute("DirectoryIndex") or 0) % #candidates + 1
        player:SetAttribute("DirectoryIndex", nextIndex)
        local host = candidates[nextIndex]
        for _, plot in ipairs(plots) do
            if plot:GetAttribute("OwnerId") == host.UserId then
                if not teleportPlayer(player, plot:GetAttribute("Center") + Vector3.new(0, 7, -5)) then return end
                sendStatus(player, "Visiting " .. host.DisplayName .. "'s sky harbor. Sign their guest log!", "Info")
                return
            end
        end
    end)

    for index = 2, #Config.Biomes do
        local gateBiomeIndex = index
        local biome = Config.Biomes[index]
        local gatePosition = islandCenter + Vector3.new(index == 2 and 31 or -31, 5, 17)
        local gate = createPart(expedition, {
            Name = biome.Name:gsub("%s+", "") .. "Gate",
            Size = Vector3.new(5, 7, 2),
            Color = biome.Color:Lerp(Color3.new(1, 1, 1), 0.2),
            Material = Enum.Material.Neon,
            CFrame = CFrame.new(gatePosition),
        })
        addBillboard(gate, biome.Name:upper() .. "\nHARBOR LEVEL " .. biome.RequiredHarborLevel, Theme.Text)
        local gatePrompt = addPrompt(gate, "Chart Route", biome.Name, 0.35)
        gatePrompt.MaxActivationDistance = 16
        gatePrompt.Triggered:Connect(function(player)
            if not PlayerRuntime.canInteract(player, gate, gatePrompt.MaxActivationDistance) then return end
            travelToBiome(player, gateBiomeIndex)
        end)
        buildBiome(world, biome, biomePositions[index])
    end

    local skyways = Instance.new("Folder")
    skyways.Name = "HarborSkyways"
    skyways.Parent = world
    for index, plot in ipairs(plots) do
        local harborCenter = plot:GetAttribute("Center")
        local horizontalDirection = Vector3.new(harborCenter.X, 0, harborCenter.Z).Unit
        local skywayStart = (horizontalDirection * 59) + Vector3.new(0, 29.2, 0)
        local skywayEnd = harborCenter - (horizontalDirection * 31) + Vector3.new(0, 4.4, 0)
        local accent = index % 2 == 0 and Theme.Aqua or Theme.Mint
        createSkywayGateway(skyways, skywayStart, horizontalDirection, accent, "WreckSkywayGateway" .. index)
        createSkywayGateway(skyways, skywayEnd, horizontalDirection, accent, "HarborSkywayGateway" .. index)
        createSkyway(skyways, skywayStart, skywayEnd, accent, index)
    end

    local stormZone = Instance.new("Folder")
    stormZone.Name = "StormZone"
    stormZone.Parent = world
    local stormBeacon = createPart(stormZone, {
        Name = "StormBeacon",
        Size = Vector3.new(6, 20, 6),
        Color = Theme.Violet:Lerp(Theme.Ink, 0.2),
        Material = Enum.Material.Neon,
        CFrame = CFrame.new(0, 12, -105),
    })
    stormBeacon.Transparency = 0.55
    addBillboard(stormBeacon, "CALM SKIES", Theme.Violet:Lerp(Theme.Text, 0.4))
    createStormCloudRun(stormZone, Vector3.new(0, 4.4, -105))
    createAmbientSkyLife(world)
end

local function claimPlot(player)
    for index, plot in ipairs(plots) do
        if not usedPlots[index] then
            usedPlots[index] = player
            plot:SetAttribute("OwnerId", player.UserId)
            local sign = plot:FindFirstChild("HarborSign")
            local gui = sign and sign:FindFirstChildOfClass("BillboardGui")
            local label = gui and gui:FindFirstChildOfClass("TextLabel")
            if label then label.Text = player.DisplayName .. "'S SKY HARBOR" end
            playerPlots[player] = plot
            decoratePlot(plot, playerData[player].HarborLevel)
            decorateSkylings(plot, playerData[player].SkylingsRescued)
            refreshHarborProgress(player)
            return plot
        end
    end
end

local function savePlayer(player)
    local data = playerData[player]
    if not data or player:GetAttribute("ProgressSaveEnabled") ~= true or not dataStoreAvailable or not dataStore then return end
    local success, err = pcall(function()
        dataStore:SetAsync("Player_" .. player.UserId, data)
    end)
    if not success then warn("Could not save " .. player.Name .. ": " .. tostring(err)) end
end

local function loadPlayer(player)
    -- Only a successful read (including a new-player nil) permits later writes.
    player:SetAttribute("ProgressSaveEnabled", false)
    local data = {
        Salvage = Config.StartingSalvage,
        HarborLevel = Config.StartingLevel,
        ContractProgress = 0,
        RescueBeacons = 0,
        SkylingsRescued = 0,
        HarborVisits = 0,
        CrewMate = "",
        CrewTrainingLevel = 0,
        DailyStreak = 0,
        LastDailyClaimDay = -1,
        ExplorerXP = 0,
        ExplorerLevel = 1,
        FirstFlightComplete = false,
    }
    local success, saved = false, nil
    if dataStoreAvailable and dataStore then
        success, saved = pcall(function()
            return dataStore:GetAsync("Player_" .. player.UserId)
        end)
        if success then
            local decoded = ProgressData.decode(saved, data, Config.crewMateById)
            success = decoded ~= nil
            if decoded then data = decoded end
        end
    end
    -- GetAsync yields: do not create state for someone who left during loading.
    if player.Parent ~= Players then return end
    if not success and not RunService:IsStudio() then
        player:Kick("Your progress could not be loaded safely. Please rejoin shortly. No progress was overwritten by this session.")
        return
    end
    player:SetAttribute("ProgressSaveEnabled", success)
    player:SetAttribute("ProgressSessionOnly", not success)
    if not success then
        warn("Studio session-only mode for " .. player.Name .. ": progress will not be saved.")
    end
    playerData[player] = data

    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"
    stats.Parent = player
    local salvage = Instance.new("IntValue")
    salvage.Name = "Salvage"
    salvage.Value = data.Salvage
    salvage.Parent = stats
    local level = Instance.new("IntValue")
    level.Name = "Harbor Level"
    level.Value = data.HarborLevel
    level.Parent = stats
    local explorerLevel = Instance.new("IntValue")
    explorerLevel.Name = "Explorer Level"
    explorerLevel.Value = data.ExplorerLevel
    explorerLevel.Parent = stats
    player:SetAttribute("InCrew", false)
    player:SetAttribute("DiscoveryChain", 0)
    player:SetAttribute("DiscoveryChainEndsAt", 0)
    syncAdventure(player)
    player.CharacterAdded:Connect(function(character)
        task.defer(function()
            character:WaitForChild("HumanoidRootPart", 5)
            applyCrewMateVisual(player, character)
        end)
    end)
    if player.Character then
        applyCrewMateVisual(player, player.Character)
    end

    local plot = claimPlot(player)
    if plot then
        player.RespawnLocation = plot:FindFirstChild("HarborSpawn")
        if player.Character then
            task.defer(function()
                local character = player.Character
                local root = character and character:WaitForChild("HumanoidRootPart", 5)
                if root then teleportPlayer(player, plot:GetAttribute("Center") + Vector3.new(0, 7, 0)) end
            end)
        end
        sendStatus(player, "Welcome aboard. Recover salvage at the central wreck, then upgrade your harbor.", "Info")
    else
        sendStatus(player, "All harbor plots are occupied. You can still explore the wreck.", "Warning")
    end
end

crewMateEvent.OnServerEvent:Connect(function(player, mateId)
    local data = playerData[player]
    local mate = type(mateId) == "string" and Config.crewMateById(mateId)
    if not data or not mate then return end
    if data.CrewMate ~= "" then
        -- A retry must acknowledge the existing choice, never replace it.
        syncAdventure(player)
        return
    end
    data.CrewMate = mate.Id
    syncAdventure(player)
    applyCrewMateVisual(player, player.Character)
    refreshHarborForPlayer(player)
    sendStatus(player, mate.Name .. " aboard! Claim your Log, then ride the Wreck Navigator.", "Success")
end)

local function beginStorm()
    if stormActive then return end
    stormActive = true
    stormCompleted = false
    stormProgress = 0
    stormGoal = math.max(3, #Players:GetPlayers() * Config.StormCoresPerPlayer)
    stormEndsAt = os.time() + Config.StormDurationSeconds
    syncStormState()
    local world = workspace:FindFirstChild("SkyboundWorld")
    local stormZone = world and world:FindFirstChild("StormZone")
    if not stormZone then
        stormActive = false
        stormGoal = 0
        stormEndsAt = 0
        syncStormState()
        return
    end
    local beacon = stormZone:FindFirstChild("StormBeacon")
    if beacon then
        beacon.Color = Theme.Violet
        beacon.Transparency = 0
        local gui = beacon:FindFirstChildOfClass("BillboardGui")
        local label = gui and gui:FindFirstChildOfClass("TextLabel")
        if label then label.Text = "STORM FRONT!\nRECOVER THE CORES" end
    end
    local stormVisuals = Instance.new("Folder")
    stormVisuals.Name = "StormVisuals"
    stormVisuals.Parent = stormZone
    for index = 1, 6 do
        local angle = (math.pi * 2 / 6) * index
        createStormCloud(stormVisuals, Vector3.new(math.cos(angle) * 42, 27 + ((index % 2) * 5), -105 + math.sin(angle) * 42), 9)
    end
    local atmosphere = Lighting:FindFirstChild("SkyboundAtmosphere")
    if atmosphere then
        atmosphere.Color = Theme.Violet:Lerp(Theme.Ink, 0.3)
        atmosphere.Density = 0.34
        atmosphere.Haze = 2.2
    end
    local correction = Lighting:FindFirstChild("SkyboundColor")
    if correction then correction.TintColor = Theme.Violet:Lerp(Theme.SkyHaze, 0.35) end
    for _, player in ipairs(Players:GetPlayers()) do
        sendStatus(player, "Storm front! Recover " .. stormGoal .. " cores together for a crew reward.", "Storm")
    end
    local coreCount = stormGoal + 2
    for index = 1, coreCount do
        local stormAngle = (math.pi * 2 / coreCount) * index
        createCollectible(stormZone, Vector3.new(math.cos(stormAngle) * 25, 8, -105 + math.sin(stormAngle) * 25), Config.StormCoreValue, true)
    end
    task.wait(Config.StormDurationSeconds)
    for _, item in ipairs(stormZone:GetChildren()) do
        if item.Name == "StormCore" then item:Destroy() end
    end
    stormVisuals:Destroy()
    if beacon then
        beacon.Color = Theme.Violet:Lerp(Theme.Ink, 0.2)
        beacon.Transparency = 0.55
        local gui = beacon:FindFirstChildOfClass("BillboardGui")
        local label = gui and gui:FindFirstChildOfClass("TextLabel")
        if label then label.Text = "CALM SKIES" end
    end
    stormActive = false
    stormProgress = 0
    stormGoal = 0
    stormEndsAt = 0
    if atmosphere then
        atmosphere.Color = Theme.SkyHaze
        atmosphere.Density = 0.26
        atmosphere.Haze = 1.1
    end
    if correction then correction.TintColor = Theme.SkyHaze end
    syncStormState()
end

buildWorld()
crew:Sync()

returnHomeEvent.OnServerEvent:Connect(function(player)
    returnToHarbor(player)
end)

Players.PlayerAdded:Connect(loadPlayer)
Players.PlayerRemoving:Connect(function(player)
    savePlayer(player)
    crew:Remove(player)
    voidRescueCooldowns[player] = nil
    guestBookEntries[player.UserId] = nil
    discoveryChains[player] = nil
    for index, owner in pairs(usedPlots) do
        if owner == player then
            usedPlots[index] = nil
            local plot = plots[index]
            plot:SetAttribute("OwnerId", nil)
            local sign = plot:FindFirstChild("HarborSign")
            local gui = sign and sign:FindFirstChildOfClass("BillboardGui")
            local label = gui and gui:FindFirstChildOfClass("TextLabel")
            if label then label.Text = "UNCLAIMED SKY HARBOR" end
            local upgrades = plot:FindFirstChild("Upgrades")
            if upgrades then upgrades:Destroy() end
            local skylings = plot:FindFirstChild("Skylings")
            if skylings then skylings:Destroy() end

            local terminal = plot:FindFirstChild("UpgradeTerminal")
            local terminalGui = terminal and terminal:FindFirstChildOfClass("BillboardGui")
            local terminalLabel = terminalGui and terminalGui:FindFirstChildOfClass("TextLabel")
            local terminalPrompt = terminal and terminal:FindFirstChildOfClass("ProximityPrompt")
            if terminalLabel then terminalLabel.Text = "HARBOR UPLINK\nCLAIM TO UPGRADE" end
            if terminalPrompt then terminalPrompt.ObjectText = "Harbor Uplink • captain only" end

            for biomeIndex = 2, #Config.Biomes do
                local biome = Config.Biomes[biomeIndex]
                local route = plot:FindFirstChild(biome.Name:gsub("%s+", "") .. "HarborRoute")
                local routeGui = route and route:FindFirstChildOfClass("BillboardGui")
                local routeLabel = routeGui and routeGui:FindFirstChildOfClass("TextLabel")
                local routePrompt = route and route:FindFirstChildOfClass("ProximityPrompt")
                local routeLight = route and route:FindFirstChildOfClass("PointLight")
                if routeLabel then routeLabel.Text = biome.Name:upper() .. "\nCLAIM A HARBOR" end
                if routePrompt then routePrompt.ObjectText = biome.Name .. " • captain only" end
                if routeLight then routeLight.Brightness = 0.28 end
                for _, decoration in ipairs(plot:GetChildren()) do
                    if decoration.Name == biome.Name:gsub("%s+", "") .. "RoutePylon"
                        or decoration.Name == biome.Name:gsub("%s+", "") .. "RouteCrown"
                        or decoration.Name == biome.Name:gsub("%s+", "") .. "RouteArch" then
                        decoration.Transparency = 0.48
                    end
                end
            end

            local sanctuary = plot:FindFirstChild("SkylingSanctuary")
            local sanctuaryGui = sanctuary and sanctuary:FindFirstChildOfClass("BillboardGui")
            local sanctuaryLabel = sanctuaryGui and sanctuaryGui:FindFirstChildOfClass("TextLabel")
            local sanctuaryPrompt = sanctuary and sanctuary:FindFirstChildOfClass("ProximityPrompt")
            if sanctuaryLabel then sanctuaryLabel.Text = "SKYLING SANCTUARY\nCAPTAIN ACCESS" end
            if sanctuaryPrompt then sanctuaryPrompt.ObjectText = "Skyling Sanctuary • captain only" end
            local sanctuaryGlow = sanctuary and sanctuary:FindFirstChild("ReadyGlow")
            if sanctuaryGlow then sanctuaryGlow.Enabled = false end

            local captainLog = plot:FindFirstChild("CaptainLog")
            local logGui = captainLog and captainLog:FindFirstChildOfClass("BillboardGui")
            local logLabel = logGui and logGui:FindFirstChildOfClass("TextLabel")
            local logPrompt = captainLog and captainLog:FindFirstChildOfClass("ProximityPrompt")
            if logLabel then logLabel.Text = "CAPTAIN'S LOG\nCLAIM A HARBOR" end
            if logPrompt then logPrompt.ObjectText = "Captain's Log • captain only" end
            local logGlow = captainLog and captainLog:FindFirstChild("ReadyGlow")
            if logGlow then logGlow.Enabled = false end

            local training = plot:FindFirstChild("CrewTraining")
            local trainingGlow = training and training:FindFirstChild("ReadyGlow")
            if trainingGlow then trainingGlow.Enabled = false end

            local ledger = plot:FindFirstChild("ContractLedger")
            local ledgerGui = ledger and ledger:FindFirstChildOfClass("BillboardGui")
            local ledgerLabel = ledgerGui and ledgerGui:FindFirstChildOfClass("TextLabel")
            if ledgerLabel then ledgerLabel.Text = "CAPTAIN'S CONTRACT\nCLAIM A HARBOR" end

            local guestBook = plot:FindFirstChild("GuestBook")
            local guestGui = guestBook and guestBook:FindFirstChildOfClass("BillboardGui")
            local guestLabel = guestGui and guestGui:FindFirstChildOfClass("TextLabel")
            if guestLabel then guestLabel.Text = "GUEST LOG\nCLAIM A HARBOR" end
        end
    end
    playerPlots[player] = nil
    playerData[player] = nil
end)

task.spawn(function()
    task.wait(25)
    while true do
        beginStorm()
        task.wait(Config.StormIntervalSeconds)
    end
end)

task.spawn(function()
    while true do
        task.wait(Config.AutoSaveSeconds)
        for _, player in ipairs(Players:GetPlayers()) do savePlayer(player) end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.4)
        for _, player in ipairs(Players:GetPlayers()) do
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if root and humanoid and humanoid.Health > 0 and root.Position.Y < -18 then
                local lastRescue = voidRescueCooldowns[player] or 0
                if os.clock() - lastRescue >= 3 then
                    voidRescueCooldowns[player] = os.clock()
                    rescueFromSkyfall(player)
                end
            end
        end
    end
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do savePlayer(player) end
end)
