-- No-clip entry zones (F5). Detects when the LOCAL player walks into a
-- configured volume and reports enter/exit to the server, which validates
-- position, rolls `chance`, and enforces `dwell`. No teleport decided here.

local zones = MBT.NoClipZones or {}
local inside = {} -- zone index -> true while the player is within it

local function within(coords, z)
    if z.radius then
        return #(coords - z.coords) <= z.radius
    end
    local d = coords - z.coords
    return math.abs(d.x) <= z.size.x and math.abs(d.y) <= z.size.y and math.abs(d.z) <= z.size.z
end

-- Marker dimensions for a zone (box half-extents -> full size; radius -> diameter).
local function dims(z)
    if z.radius then return z.radius * 2, z.radius * 2, z.radius * 2 end
    return z.size.x * 2, z.size.y * 2, z.size.z * 2
end

-- DEBUG-ONLY marker (for placing/testing zones). No-clip spots are meant to be
-- invisible in production — markers never render unless MBT.Debug is on.
CreateThread(function()
    if not MBT.Debug or MBT.DebugMarkers == false or #zones == 0 then return end
    while true do
        local sleep = 1000
        local pc = GetEntityCoords(PlayerPedId())
        for i = 1, #zones do
            local z = zones[i]
            if #(pc - z.coords) < 50.0 then
                sleep = 0
                local sx, sy, sz = dims(z)
                DrawMarker(z.radius and 28 or 1,
                    z.coords.x, z.coords.y, z.coords.z - (z.radius and 0.0 or sz * 0.5),
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    sx, sy, sz,
                    80, 255, 200, 90,
                    false, false, 2, false, nil, nil, false)
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    if #zones == 0 then return end

    while true do
        local sleep = 500
        local state = LocalPlayer.state
        -- Only look for entry zones while OUTSIDE a level and not mid-transition.
        if not state['mbt_backrooms:exitLocked'] and not state['mbt_backrooms:inLevel'] then
            local coords = GetEntityCoords(PlayerPedId())
            for i = 1, #zones do
                local isIn = within(coords, zones[i])
                if isIn and not inside[i] then
                    inside[i] = true
                    Utils.MbtDebugger('noclip zoneEnter ->', i)
                    TriggerServerEvent('mbt_backrooms:zoneEnter', i)
                elseif not isIn and inside[i] then
                    inside[i] = nil
                    Utils.MbtDebugger('noclip zoneExit ->', i)
                    TriggerServerEvent('mbt_backrooms:zoneExit', i)
                end
                if isIn then sleep = 200 end -- responsive exit detection while inside
            end
        elseif next(inside) then
            -- In a level / locked: reset tracking so re-entry re-fires cleanly.
            inside = {}
        end

        Wait(sleep)
    end
end)
