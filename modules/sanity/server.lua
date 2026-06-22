-- Sanity (F4) — server-authoritative. Decays while inside a level (faster when
-- alone), regenerates on the surface. Exposed Sanity.Hit() for entity sightings.

Sanity = Sanity or {}

local cfg = MBT.Sanity
local SANITY  = 'mbt_backrooms:sanity'
local INLEVEL = 'mbt_backrooms:inLevel'
local TICK = 4000 -- ms

local function get(src)
    local v = Player(src).state[SANITY]
    return v == nil and 100 or v
end

local function set(src, v)
    Player(src).state:set(SANITY, math.max(0, math.min(100, v)), true)
end

-- Discrete sanity loss (entity glimpse, etc.). Called by F6.
function Sanity.Hit(src, amount)
    if not cfg.Enabled then return end
    set(src, get(src) - (amount or cfg.SmilerHit or 10))
end

if cfg.Enabled then
    CreateThread(function()
        local perMinToTick = TICK / 60000
        while true do
            Wait(TICK)
            local players = GetPlayers()

            -- Count occupancy per level for the isolation modifier.
            local occupancy = {}
            for _, id in ipairs(players) do
                local lvl = Player(tonumber(id)).state[INLEVEL]
                if lvl then occupancy[lvl] = (occupancy[lvl] or 0) + 1 end
            end

            for _, id in ipairs(players) do
                local src = tonumber(id)
                local lvl = Player(src).state[INLEVEL]
                if lvl then
                    local decay = (cfg.DecayPerMinute or 8) * perMinToTick
                    if (occupancy[lvl] or 1) <= 1 then decay = decay * (cfg.IsolationMult or 1.5) end
                    set(src, get(src) - decay)
                else
                    local cur = get(src)
                    if cur < 100 then set(src, cur + (cfg.RegenOnSurface or 20) * perMinToTick) end
                end
            end
        end
    end)

    -- Debug: force a sanity value to test the presentation. /brsanity 10
    if MBT.Debug then
        RegisterCommand('brsanity', function(src, args)
            local v = tonumber(args[1]) or 100
            set(src, v)
            Utils.MbtDebugger('sanity set', src, v)
        end, false)
    end
end
