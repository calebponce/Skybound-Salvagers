local warnings = 0
local runtime = dofile("src/server/PlayerRuntime.lua")({FireClient = function() warnings = warnings + 1 end})
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
CFrame = {new = function(destination) return destination end}
Vector3 = {zero = {}}
root = {Position = position(0)}
player.Character = character
local destination = position(50)
assert(runtime.teleportPlayer(player, destination) == true)
assert(root.CFrame == destination and root.AssemblyLinearVelocity == Vector3.zero)
assert(root.AssemblyAngularVelocity == Vector3.zero)
humanoid.Health = 0
assert(runtime.teleportPlayer(player, position(100)) == false)
assert(root.CFrame == destination, "Dead characters must not move")
player.Character = nil
assert(runtime.teleportPlayer(player, destination) == false)
assert(warnings == 2, "Failed travel gives one warning per attempt")
print("Player runtime teleport tests passed")
