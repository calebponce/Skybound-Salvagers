local runtime = dofile("src/server/PlayerRuntime.lua")({})
local function position(x)
    return setmetatable({x = x}, {__sub = function(a, b) return {Magnitude = math.abs(a.x - b.x)} end})
end
local root = {Position = position(0)}
local humanoid = {Health = 100}
local character = {
    FindFirstChild = function() return root end,
    FindFirstChildOfClass = function() return humanoid end,
}
local player = {Character = character}
local target = {Parent = {}, Position = position(11)}
assert(runtime.canInteract(player, target, 11), "Inclusive interaction boundary")
target.Position = position(11.01)
assert(not runtime.canInteract(player, target, 11), "Out-of-range strike rejected")
target.Position = position(0)
humanoid.Health = 0
assert(not runtime.canInteract(player, target, 11), "Dead character rejected")
humanoid.Health = 100
target.Parent = nil
assert(not runtime.canInteract(player, target, 11), "Destroyed target rejected")
target.Parent = {}
root = nil
assert(not runtime.canInteract(player, target, 11), "Missing root rejected")
player.Character = nil
assert(not runtime.canInteract(player, target, 11), "Missing character rejected")
print("Player runtime interaction tests passed")
