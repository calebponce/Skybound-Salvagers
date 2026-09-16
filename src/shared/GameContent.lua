-- Static content that designers can tune without touching gameplay systems.
return {
    ExplorerTitles = {
        { Level = 1, Name = "Deckhand" },
        { Level = 3, Name = "Wayfinder" },
        { Level = 5, Name = "Stormchaser" },
        { Level = 8, Name = "Sky Captain" },
    },
    CrewMates = {
        {
            Id = "Rook", Name = "Rook", Role = "SALVAGE RUNNER",
            Strength = "+2 standard salvage", Weakness = "-5 storm-core salvage",
            Battle = "2x damage • interrupts charges (8s)", BattleLabel = "HARPOON",
            Accent = "Gold", NormalBonus = 2, StormBonus = -5, UpgradeMultiplier = 1, GuardianStrike = 2, GuardianInterruptCooldown = 8,
        },
        {
            Id = "Luma", Name = "Luma", Role = "STORM NAVIGATOR",
            Strength = "+8 storm-core salvage", Weakness = "-1 standard salvage",
            Battle = "STORM WARD • -40% guardian damage", BattleLabel = "STORM WARD",
            Accent = "Violet", NormalBonus = -1, StormBonus = 8, UpgradeMultiplier = 1, GuardianDamageMultiplier = 0.6,
        },
        {
            Id = "Briggs", Name = "Briggs", Role = "HARBOR BUILDER",
            Strength = "15% cheaper harbor upgrades", Weakness = "-1 standard salvage",
            Battle = "PRIZE RIG • +35% guardian salvage", BattleLabel = "PRIZE RIG",
            Accent = "Mint", NormalBonus = -1, StormBonus = 0, UpgradeMultiplier = 0.85, GuardianRewardMultiplier = 1.35,
        },
    },
    Biomes = {
        {
            Name = "Whispering Wreck", RequiredHarborLevel = 1, SalvageValue = 5,
            Color = Color3.fromRGB(94, 94, 74), GuardianName = "Wreck Wisp",
            GuardianHealth = 2, GuardianDamage = 7, GuardianReward = 8, GuardianCount = 1,
        },
        {
            Name = "Ember Drift", RequiredHarborLevel = 2, SalvageValue = 9,
            Color = Color3.fromRGB(126, 72, 54), GuardianName = "Cinder Maw",
            GuardianHealth = 4, GuardianDamage = 11, GuardianReward = 16, GuardianCount = 2,
        },
        {
            Name = "Aurora Shelf", RequiredHarborLevel = 4, SalvageValue = 14,
            Color = Color3.fromRGB(75, 115, 150), GuardianName = "Aurora Stalker",
            GuardianHealth = 6, GuardianDamage = 15, GuardianReward = 26, GuardianCount = 3,
        },
    },
    SkylingNames = { "Pip", "Comet", "Moss", "Glint", "Nimbus", "Ember" },
    SkylingColors = {
        Color3.fromRGB(112, 225, 255),
        Color3.fromRGB(255, 193, 91),
        Color3.fromRGB(129, 235, 156),
        Color3.fromRGB(211, 147, 255),
        Color3.fromRGB(244, 246, 255),
        Color3.fromRGB(255, 129, 108),
    },
}
