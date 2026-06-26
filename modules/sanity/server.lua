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

-- Discrete sanity gain (Almond Water). Returns false if already (near) full so the
-- caller can avoid consuming the item for nothing.
function Sanity.Restore(src, amount)
    if not cfg.Enabled then return false end
    if get(src) >= (cfg.FullThreshold or 98) then return false end
    set(src, get(src) + (amount or 0))
    return true
end

function Sanity.Get(src) return get(src) end

-- F6: client reports an entity glimpse. Rate-limited so it can't drain sanity.
RegisterNetEvent('mbt_backrooms:glimpseSeen', function()
    local src = source
    if not Utils.RateLimit(src, 'glimpse', 5000) then return end
    if not Player(src).state['mbt_backrooms:inLevel'] then return end
    Sanity.Hit(src, (MBT.Entities and MBT.Entities.SanityHit) or cfg.SmilerHit or 15)
end)

-- First-contact dread: client reports another lost player came close. Server owns
-- the spike + rate-limits per CooldownSec so it can't be spammed into a drain.
RegisterNetEvent('mbt_backrooms:playerContact', function()
    local src = source
    local pc = MBT.PlayerContact
    if not (pc and pc.Enabled) then return end
    if not Utils.RateLimit(src, 'contact', (pc.CooldownSec or 25) * 1000) then return end
    if not Player(src).state['mbt_backrooms:inLevel'] then return end
    Sanity.Hit(src, pc.SanitySpike or 8)
end)

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
                    -- torch OFF (or never set) = dark = faster erosion (F4 light tension)
                    if MBT.Light and MBT.Light.Enabled and not Player(src).state['mbt_backrooms:torch'] then
                        decay = decay * (MBT.Light.DarkDecayMult or 1.0)
                    end
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
