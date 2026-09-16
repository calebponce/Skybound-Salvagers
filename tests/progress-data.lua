-- Plain Lua test: runs without Roblox services or access to real player data.
local ProgressData = dofile("src/server/ProgressData.lua")
local defaults = {
    Salvage = 0, HarborLevel = 1, ExplorerLevel = 1,
    ContractProgress = 0, RescueBeacons = 0,
    CrewMate = "", FirstFlightComplete = false, LastDailyClaimDay = -1,
}
local function decode(saved)
    return ProgressData.decode(saved, defaults, function(id) return id == "Rook" end)
end
assert(decode(nil).HarborLevel == 1, "New players receive defaults")
assert(decode({Salvage = 123}).Salvage == 123, "Legacy saves retain progress")
assert(decode({Salvage = "123"}).Salvage == 123, "Legacy numeric strings remain supported")
assert(decode({ContractProgress = 2}).FirstFlightComplete, "Existing-player intro migration")
assert(decode({CrewMate = "Rook"}).CrewMate == "Rook")
assert(decode({LastDailyClaimDay = -1}).LastDailyClaimDay == -1)
assert(decode("invalid") == nil)
for _, value in ipairs({-1, 1.5, math.huge, -math.huge, "broken", false}) do
    assert(decode({Salvage = value}) == nil, "Invalid numeric value must reject entire save")
end
assert(decode({Salvage = 0/0}) == nil, "NaN rejected")
assert(decode({HarborLevel = 0}) == nil)
assert(decode({ExplorerLevel = 0}) == nil)
assert(decode({CrewMate = "MissingMate"}) == nil)
assert(decode({FirstFlightComplete = "false"}) == nil)
assert(defaults.Salvage == 0, "Defaults must never be mutated")
assert(decode({Salvage = 123, CrewMate = "MissingMate"}) == nil, "No partial merge")
print("ProgressData regression tests passed")
