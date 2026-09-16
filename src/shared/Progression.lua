-- Attaches formulas to Config so server and client always calculate rewards
-- and unlock states from the same source of truth.
return function(Config)
    function Config.upgradeCost(level)
        return Config.UpgradeBaseCost + ((level - 1) * Config.UpgradeCostStep)
    end

    function Config.crewTrainingCost(level)
        return Config.CrewTrainingBaseCost + (level * Config.CrewTrainingCostStep)
    end

    function Config.dailyRewardFor(streak)
        local cappedStreak = math.clamp(streak, 1, Config.DailyRewardStreakMax)
        return Config.DailyRewardBase + ((cappedStreak - 1) * Config.DailyRewardStreakStep)
    end

    function Config.skylingFor(index)
        local listIndex = ((index - 1) % #Config.SkylingNames) + 1
        return Config.SkylingNames[listIndex], Config.SkylingColors[listIndex]
    end

    function Config.crewMateById(id)
        for _, mate in ipairs(Config.CrewMates) do
            if mate.Id == id then return mate end
        end
    end

    function Config.explorerXpForLevel(level)
        return Config.ExplorerXpBase + ((level - 1) * Config.ExplorerXpStep)
    end

    function Config.explorerSalvageMultiplier(level)
        local bonus = math.min((level - 1) * Config.ExplorerSalvageBonusPerLevel, Config.ExplorerSalvageBonusCap)
        return 1 + bonus
    end

    function Config.explorerTitleForLevel(level)
        local title = Config.ExplorerTitles[1].Name
        for _, entry in ipairs(Config.ExplorerTitles) do
            if level >= entry.Level then title = entry.Name end
        end
        return title
    end

    function Config.skylingSalvageBonus(rescuedCount)
        return math.min(math.floor(rescuedCount / Config.SkylingBonusEvery), Config.SkylingSalvageBonusCap)
    end
end
