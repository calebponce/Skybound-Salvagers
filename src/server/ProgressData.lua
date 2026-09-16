-- Validate before merging so malformed saves never become writable defaults.
local ProgressData = {}

function ProgressData.decode(saved, defaults, validCrewMate)
    if saved ~= nil and type(saved) ~= "table" then return nil end
    local result = {}
    for key, defaultValue in pairs(defaults) do
        local value = saved and saved[key]
        if value == nil then
            value = defaultValue -- Older saves may predate a field.
        elseif type(defaultValue) == "number" then
            value = tonumber(value)
            local minimum = key == "LastDailyClaimDay" and -1 or 0
            if not value or value ~= value or value == math.huge or value == -math.huge
                or value < minimum or value % 1 ~= 0 then return nil end
            if (key == "HarborLevel" or key == "ExplorerLevel") and value < 1 then return nil end
        elseif type(defaultValue) == "boolean" then
            if type(value) ~= "boolean" then return nil end
        elseif key == "CrewMate" then
            if type(value) ~= "string" or (value ~= "" and not validCrewMate(value)) then return nil end
        end
        result[key] = value
    end
    if not result.FirstFlightComplete and (result.ContractProgress > 0 or result.RescueBeacons > 0) then
        result.FirstFlightComplete = true
    end
    return result
end

return ProgressData
