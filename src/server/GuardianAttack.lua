-- Service-independent attack state. The world loop owns timing and visuals.
local GuardianAttack = {}

function GuardianAttack.new()
    local windingUp = false
    local cancelled = false
    local lastInterruptAt = -math.huge
    local attack = {}

    function attack:Begin()
        if windingUp then return false end
        windingUp = true
        cancelled = false
        return true
    end

    function attack:Interrupt(now, cooldown)
        if not windingUp or cancelled or not cooldown or now - lastInterruptAt < cooldown then
            return false
        end
        cancelled = true
        lastInterruptAt = now
        return true
    end

    function attack:Resolve()
        if not windingUp then return false end
        windingUp = false
        return not cancelled
    end

    return attack
end

return GuardianAttack
