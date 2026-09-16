local createCrew = dofile("src/server/CrewExpedition.lua")
local players, attributes, balances = {}, {}, {}
for id = 1, 5 do
    players[id] = {UserId = id, SetAttribute = function() end}
    balances[id] = 0
end
local crew = createCrew({
    Players = {GetPlayerByUserId = function(_, id) return players[id] end},
    Config = {CrewGoalBase = 12, CrewSuppliesPerMember = 4, CrewMaxMembers = 4, CrewReward = 10},
    Remotes = {SetAttribute = function(_, key, value) attributes[key] = value end},
    FindBoard = function() return nil end,
    GetSalvage = function(player) return balances[player.UserId] end,
    SetSalvage = function(player, value) balances[player.UserId] = value end,
    SendStatus = function() end,
})
for id = 1, 3 do assert(crew:ToggleMembership(players[id])) end
assert(not crew:RegisterRecovery(players[5]), "Non-members cannot contribute")
crew:RegisterRecovery(players[1])
assert(attributes.CrewProgress == 1 and attributes.CrewGoal == 12)
assert(crew:ToggleMembership(players[4]))
assert(attributes.CrewGoal == 12, "Joining cannot increase active target")
assert(crew:ToggleMembership(players[5]) == nil, "Capacity remains enforced")
for index = 2, 12 do crew:RegisterRecovery(players[1]) end
assert(attributes.CrewProgress == 0 and attributes.CrewGoal == 16, "Next round uses current crew size")
for id = 1, 4 do assert(balances[id] == 10, "Exactly one payout per member") end
assert(balances[5] == 0)
crew:RegisterRecovery(players[1])
crew:Remove(players[4])
assert(attributes.CrewGoal == 16 and attributes.CrewProgress == 1, "Leaving cannot shorten active target")
for index = 2, 16 do crew:RegisterRecovery(players[1]) end
assert(balances[1] == 20 and balances[4] == 10, "Only current members get next payout")
assert(attributes.CrewGoal == 12 and attributes.CrewProgress == 0)
print("Crew expedition regression tests passed")
