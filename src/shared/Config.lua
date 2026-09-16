local Theme = require(script.Parent.Theme)
local GameContent = require(script.Parent.GameContent)
local attachProgression = require(script.Parent.Progression)

-- Runtime tunables live here; static content and formulas are isolated in
-- sibling modules to keep this file a quick balancing reference.
local Config = {
    Theme = Theme,
    DataStoreName = "SkyboundSalvagers_PlayerData_v1",
    PlotCount = 6,
    PlotRadius = 145,
    HarborIslandDiameter = 70,
    WreckIslandDiameter = 120,
    BiomeIslandDiameter = 108,
    StartingSalvage = 0,
    StartingLevel = 1,
    MaxHarborLevel = 4,
    UpgradeBaseCost = 25,
    UpgradeCostStep = 30,
    NormalSalvageValue = 5,
    SkywayCacheValue = 4,
    SkywayCacheRespawnSeconds = 75,
    StormCoreValue = 25,
    NormalRespawnSeconds = 14,
    ExpeditionCacheRespawnSeconds = 90,
    AutoSaveSeconds = 120,
    StormDurationSeconds = 75,
    StormIntervalSeconds = 240,
    StormCoresPerPlayer = 3,
    StormCoopReward = 15,
    CrewGoalBase = 12,
    CrewSuppliesPerMember = 4,
    CrewMaxMembers = 4,
    CrewReward = 10,
    GuardianAssistRewardPercent = 0.4,
    CrewTrainingMax = 3,
    CrewTrainingBaseCost = 40,
    CrewTrainingCostStep = 35,
    HarborVisitReward = 5,
    DailyRewardBase = 20,
    DailyRewardStreakStep = 5,
    DailyRewardStreakMax = 7,
    ExplorerXpBase = 45,
    ExplorerXpStep = 20,
    ExplorerSalvageBonusPerLevel = 0.02,
    ExplorerSalvageBonusCap = 0.20,
    DiscoveryChainWindow = 18,
    DiscoveryChainMax = 5,
    DiscoveryChainBonusMax = 4,
    ContractGoal = 8,
    MaxVisibleSkylings = 6,
    SkylingBonusEvery = 2,
    SkylingSalvageBonusCap = 3,
    ExplorerTitles = GameContent.ExplorerTitles,
    CrewMates = GameContent.CrewMates,
    Biomes = GameContent.Biomes,
    SkylingNames = GameContent.SkylingNames,
    SkylingColors = GameContent.SkylingColors,
}

attachProgression(Config)

return Config
