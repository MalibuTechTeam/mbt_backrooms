MBT = MBT or {}

-------------------------------------------------------------------------------
-- [ SECTION 1: GLOBAL SETTINGS ] --
-------------------------------------------------------------------------------

MBT.Language = 'en' -- Options: 'en', 'it', 'es' (loads from locales/*.lua — add your own there)
MBT.Debug    = false -- Enable MBTLog.Debug output (gated)

-- (Logger config lives in modules/utils/logger.lua's PER-RESOURCE IDENTITY block,
-- not here — the [BR] badge is the resource's identity, not a server-owner setting.)

MBT.General = {
    InteractKey = 'E', -- Key used to pass through Enter/Exit points
}

-------------------------------------------------------------------------------
-- [ SECTION 2: GAMEPLAY ] --
-------------------------------------------------------------------------------

-- Players that clip BELOW this Z while falling are pulled into the backrooms.
-- Kept at 0.0 so it only triggers when you glitch under the map, NOT when you
-- fall from buildings / great heights.
MBT.FallingPoint = 0.0

-- Weighted destinations rolled when a player uses an Exit point. Faithful to
-- the lore: getting out is not guaranteed. Weights are RELATIVE (any numbers).
--   surface  -> escape to a random MBT.RandomExitPoint
--   backroom -> dumped into a random backroom (stay trapped)
-- `default` applies to every Exit; add a numeric key (the MBT.BackRooms index)
-- to override a specific Exit point — e.g. make one exit rarely let you out.
-- (Finer categories like 'deeper'/'poolrooms' arrive once levels have identity.)
MBT.ExitRules = {
    default = { surface = 30, backroom = 70 }, -- reproduces the v1 ~70% trapped
    -- [1] = { surface = 5, backroom = 95 },   -- example: a near-inescapable exit
}

-- Interior spawn coords, one entry per backroom level.
MBT.Coords = {
    vector3(1026.88, 801.66, 25.88),   -- lvl_01 Iakko
    vector3(1780.18, -274.04, 20.66),  -- lvl_02 Iakko
    vector3(356.42, 5530.52, 14.37),   -- lvl_03 Iakko
    vector3(-2284.94, 1432.59, 81.70)  -- lvl_04 Iakko
}

-- Surface points a player can be spit back out to when they manage to exit.
MBT.RandomExitPoint = {
    vector3(-3090.44, 3322.13, 11.41),
    vector3(1163.97, 5964.91, 407.65),
    vector3(-557.24, 1890.37, 123.75),
    vector3(-54.04, 33.76, 1924.76),
    vector3(-159.57, -975.7, 115.28),
    vector3(1753.06, 4228.73, -5.85)
}

-- Interaction points placed around the map.
--   Type = "Enter" -> always teleports into a random backroom.
--   Type = "Exit"  -> rolls MBT.ExitRules (weighted): another backroom or a
--                     surface exit point.
MBT.BackRooms = {
    { Type = "Exit",  Coords = vector3(310.52, 5522.78, 14.51),   Range = 1.5 },
    { Type = "Exit",  Coords = vector3(1779.16, -260.81, 20.86),  Range = 1.5 },
    { Type = "Exit",  Coords = vector3(-2301.72, 1416.78, 81.92), Range = 1.5 },
    { Type = "Exit",  Coords = vector3(1017.94, 800.23, 25.92),   Range = 1.5 },
    { Type = "Enter", Coords = vector3(1112.08, 2188.65, 46.39),  Range = 2.0 },
    { Type = "Enter", Coords = vector3(-220.38, 3649.13, 51.75),  Range = 2.0 },
    { Type = "Enter", Coords = vector3(-440.85, 1598.89, 358.47), Range = 2.0 },
    { Type = "Enter", Coords = vector3(1665.08, -28.03, 196.94),  Range = 2.0 },
    { Type = "Enter", Coords = vector3(3426.76, 5174.49, 7.41),   Range = 2.0 }
}

-- "No-clip" entry zones: invisible volumes in "wrong" spots (dead-end corners,
-- behind walls, under stairs). Walking into one pulls you into the Backrooms —
-- faithful to "noclip out of reality in the wrong areas". The SERVER validates
-- your position, rolls `chance`, and enforces `dwell` (anti-exploit).
--   coords : center of the volume
--   size   : vector3 half-extents for a BOX, OR set `radius` for a SPHERE
--   chance : % to clip once dwell is satisfied (100 = always)
--   dwell  : seconds you must stay inside before clipping (0 = instant)
-- Markers for these zones are DEBUG-ONLY (drawn only while MBT.Debug is on, for
-- placement) — in production these spots stay invisible.
-- Tip: use the /brhere debug command (needs MBT.Debug) to grab coords in-game.
MBT.NoClipZones = {
    -- { coords = vector3(195.0, -934.0, 30.7), size = vector3(1.2, 1.2, 2.0), chance = 100, dwell = 0 },
    -- { coords = vector3(-1108.0, -2008.0, 13.2), radius = 1.5, chance = 30, dwell = 2 },
    -- { coords = vector3(203.91, -931.36, 30.69), size = vector3(1.5, 1.5, 2.0), chance = 100, dwell = 0 }, -- local test zone
}

-------------------------------------------------------------------------------
-- [ SECTION 3: ATMOSPHERE ] --
-------------------------------------------------------------------------------

-- Entry transition treatment, played on every teleport (the "reality shift").
-- Backrooms entry should feel like reality failing, NOT a jumpscare.
--   'glitch' (default) -> VHS/no-clip burst + postfx + shake + sting
--   'fade'             -> simple screen fade
--   'cut'              -> hard cut (the original v1 behaviour)
MBT.Transition = 'glitch'

-- Camera while inside a level. First person is the found-footage / Backrooms
-- view: more immersive and the VHS overlay reads as "your eyes". Restored to
-- the player's previous view on exit.
MBT.Camera = {
    ForceFirstPerson = true, -- switch to first person on entry
    Lock             = true, -- prevent switching back to third person while inside
}

MBT.Atmosphere = {
    Enabled = true,

    -- Which effect sources to use. Native-only effects (timecycle, light flicker,
    -- camera shake) and NUI-only effects (VHS overlay, audio) ignore the
    -- non-matching mode automatically.
    --   'native' | 'nui' | 'mix' (default)
    Mode = 'mix',

    -- Global intensity per family (0.0 - 1.0).
    Intensity = { Native = 0.85, NUI = 0.75, Audio = 0.55 },

    -- Accessibility
    ReduceMotion   = false, -- disables camera shake + screen-tear displacement
    ReduceFlashing = false, -- disables light flicker + glitch strobe

    Effects = {
        -- NATIVE-ONLY ---------------------------------------------------------
        -- Timecycle tint applied to the 3D world while inside. Picks from
        -- `variants` on each entry per `select`:
        --   'random'   -> a random variant every time (most disorienting, default)
        --   'perLevel' -> each level index always gets the same variant (identity)
        --   'fixed'    -> always the first variant
        -- strength is per-variant (0.0-1.0), further scaled by Intensity.Native.
        Timecycle = {
            enabled = true,
            source = 'native',
            select = 'random',
            variants = {
                { modifier = 'scanline_cam_cheap',  strength = 1.0 },
                { modifier = 'NG_blackout',          strength = 0.4 },
                { modifier = 'prologue_ending_fog',  strength = 0.6 },
            },
        },
        LightFlicker = { enabled = true,  source = 'native', minDelayMs = 3000, maxDelayMs = 10000, burstMinMs = 60, burstMaxMs = 400 },
        EntryShake   = { enabled = true,  source = 'native', shake = 'SMALL_EXPLOSION_SHAKE', amplitude = 0.35, durationMs = 900 },
        EntryPostFx  = { enabled = true,  source = 'native', name = 'DeathFailMPDark', durationMs = 900 },

        -- NUI-ONLY ------------------------------------------------------------
        Vhs          = { enabled = true,  source = 'nui', grain = true },
        Hum          = { enabled = true,  source = 'nui', volume = 0.5 },
        Drone        = { enabled = true,  source = 'nui', volume = 0.35 },
        EntrySting   = { enabled = true,  source = 'nui', volume = 0.7 },
    },
}

-------------------------------------------------------------------------------
-- [ SECTION 4: SANITY ] --
-------------------------------------------------------------------------------

-- Server-authoritative "sanity" (0-100). Decays while inside a level (faster
-- when alone), regenerates on the surface. Drives a closing-in vignette + camera
-- shake at low values. Entities (F6) will subtract SmilerHit on a sighting.
MBT.Sanity = {
    Enabled        = true,
    DecayPerMinute = 8,    -- base erosion while inside a level
    IsolationMult  = 1.6,  -- decay multiplier when you're alone in your level
    RegenOnSurface = 25,   -- recovery per minute once back on the surface
    SmilerHit      = 15,   -- instant loss on an entity glimpse (used by F6)

    LowThreshold      = 50, -- vignette starts ramping below this sanity
    CriticalThreshold = 20, -- camera shake / heavier distortion below this

    PersistAcrossSessions = false, -- requires the framework bridge (2.1)
}

-------------------------------------------------------------------------------
-- [ SECTION 5: ENTITIES ] --
-------------------------------------------------------------------------------

-- Scripted entity GLIMPSE (F6): in darkness / low sanity, an entity appears at
-- a distance, holds while you don't look straight at it, and vanishes when you
-- stare at it / get close / time out. NOT a chasing AI (that's 2.1).
MBT.Entities = {
    Enabled       = true,
    Models        = { 'Smiler_BR', 'Stealer' }, -- bundled CutterKnight peds (stream/entities)
    MinSanityGate = 50,    -- glimpses only fire when sanity is below this
    CooldownSec   = 90,    -- minimum seconds between glimpses
    Chance        = 50,    -- % roll each eligible check
    SpawnDistance = 18.0,  -- how far away the glimpse appears
    HoldSec       = 6,     -- max seconds it lingers (static-glimpse mode)
    GazeAngle     = 14.0,  -- looking within this many degrees counts as "looking at it"
    ApproachDist  = 2.5,   -- reaching this distance ends the encounter (sanity hit + vanish) — keep < spawn min
    SanityHit     = 15,    -- sanity lost when a glimpse occurs

    -- Stalk mode (Weeping-Angel): it creeps toward you while UNOBSERVED and
    -- FREEZES while you look at it. Reaching you = sanity hit + vanish.
    Approach           = true, -- false = static glimpse (vanish when looked at)
    ApproachSpeed      = 1.2,  -- move speed (1.0 walk, 2.0 run)
    ApproachTimeoutSec = 15,   -- max stalk duration before it gives up / vanishes

    -- Don't-Blink (stalk mode only): staring FREEZES the entity but drains your
    -- focus; at zero you blink (forced black-out) and it LUNGES closer. Breaks the
    -- "stare forever and it can't move" exploit. Looking away regenerates focus —
    -- but then it creeps toward you. Either way it closes the gap: it's a curve.
    DontBlink = {
        Enabled         = true,
        DrainPerSec     = 0.5,  -- focus drained per second while staring (1.0 = full meter)
        RegenPerSec     = 0.4,  -- focus recovered per second while NOT staring
        BlinkMs         = 220,  -- blink (black-screen) duration
        BlinkAdvance    = 3.0,  -- metres it lunges closer during the blink
        FocusAfterBlink = 0.5,  -- focus restored right after a blink (anti instant re-blink)
    },

    -- Sound cues (web/public/sounds/<file>.ogg). tape_warble = subtle "presence
    -- arrives" on spawn; sting = the sharper "it sees you" beat on first look.
    Sound = { OnSpawn = true, OnLook = true, SpawnFile = 'tape_warble', LookFile = 'sting', Volume = 0.7 },
}

-------------------------------------------------------------------------------
-- [ SECTION 6: CURATED EXITS ] --
-------------------------------------------------------------------------------

-- Curated, AMBIENT exits (distinct from the deliberate [E] doors in MBT.BackRooms).
-- Each time you enter a level the server activates a random subset of a per-level
-- pool, so the way out changes every visit. There is NO marker and NO prompt — you
-- SENSE an active exit (tells: a screen shimmer that intensifies as you near it),
-- and lingering inside it pulls you through (soft pull-in, cancellable by leaving).
--   coords/radius : the (invisible) exit volume
--   dest          : 'surface' (escape) | 'backroom' (dumped into another level)
-- NOTE: coords below are FAKE placeholders near each level spawn until Iakko's map
-- lands — grab real ones in-game with /brhere. Pool index matches MBT.Coords level.
MBT.CuratedExits = {
    Enabled        = true,
    ActivePerVisit = 2,    -- how many pool entries go "live" each entry
    TellRange      = 9.0,  -- start sensing an active exit within this distance (m)
    Pool = {
        [1] = { -- lv01 ymap (small ~16m room, rot +60°); exits N, pickups S (~12m apart)
            { coords = vector3(1025.84, 807.09, 25.9), radius = 1.6, dest = 'surface'  },
            { coords = vector3(1015.84, 807.09, 25.9), radius = 1.6, dest = 'backroom' },
        },
        [2] = { -- lv02 ymap (med room, rot -30°); spread around the real spawn
            { coords = vector3(1792.18, -266.04, 20.7), radius = 1.6, dest = 'surface'  },
            { coords = vector3(1768.18, -282.04, 20.7), radius = 1.6, dest = 'backroom' },
        },
        [3] = { -- lv03 ymap (big room, MLO @ 336.5,5533 rot -30°); spread around the real spawn
            { coords = vector3(370.4, 5540.5, 14.4), radius = 1.6, dest = 'surface'  },
            { coords = vector3(342.4, 5520.5, 14.4), radius = 1.6, dest = 'backroom' },
        },
        [4] = { -- REAL coords from lv04 ymap (MLO @ -2287.88,1430.96 no-rot); exits at opposite edges
            { coords = vector3(-2298.88, 1441.96, 81.7), radius = 1.6, dest = 'surface'  },
            { coords = vector3(-2276.88, 1419.96, 81.7), radius = 1.6, dest = 'backroom' },
        },
    },
}

-- Soft pull-in: a curated exit doesn't teleport instantly. Linger inside it and a
-- warp builds over DurationMs (screen smear) then it pulls you through. Step out
-- to cancel — exits never "steal" a run by a single accidental touch.
MBT.SoftPullIn = {
    Enabled    = true,
    DurationMs = 3000,
    -- A localized "the room is losing pressure" swirl during the pull-in ONLY —
    -- never at rest, so the exit stays unmarked. Paper/litter lifts and spins,
    -- growing as you're pulled through, then hard-cuts on the teleport. Staged so
    -- nothing shows until the player has already committed (StartAt).
    Ptfx = {
        Enabled  = true,
        Dict     = 'core',
        Name     = 'env_dust_devil_urban_lrg', -- urban dust devil (lifts paper litter)
        StartAt  = 0.1,  -- pull progress (0..1) before any particle appears
        MinScale = 0.5,
        MaxScale = 1.5,
    },
}

-------------------------------------------------------------------------------
-- [ SECTION 7: ARTIFACTS — found tapes / logs ] --
-------------------------------------------------------------------------------

-- The narrative spine (faithful to the film): scattered tapes/logs left by those
-- who came before. You enter to DOCUMENT the impossible / recover them. Each visit
-- the server scatters a random subset of a per-level pool as in-world props; pick
-- one up with [E] and its text flashes as a found-footage caption — the reward is
-- LORE, not loot. Carry them to the surface to "recover" them.
-- FAKE placeholder coords until Iakko's map — grab real ones with /brhere. Pool
-- index matches the level (MBT.Coords). `text` is the found-footage caption shown.
MBT.Artifacts = {
    Enabled       = true,
    SpawnPerVisit = 2,                   -- how many from the pool spawn each visit
    PickupRange   = 1.8,
    PropModel     = 'prop_notepad_01',   -- in-world prop (swap if it doesn't spawn)
    Pool = {
        [1] = { -- lv01: tapes on the S side, away from the N exits
            { coords = vector3(1024.84, 795.09, 25.9), type = 'tape', text = "TAPE 04 — \"the lights hum in B-flat. counted 1,400 before i stopped.\"" },
            { coords = vector3(1016.84, 795.09, 25.9), type = 'log',  text = "NOTE — \"don't go back the way you came. it isn't there anymore.\"" },
            { coords = vector3(1020.84, 793.50, 25.9), type = 'tape', text = "TAPE 09 — \"found a door. almond water on the other side. i think.\"" },
        },
        [2] = { -- lv02: tapes on the far diagonal from the exits
            { coords = vector3(1770.18, -264.04, 20.7), type = 'log',  text = "MEMO — \"the walls are warm here. that means something is awake.\"" },
            { coords = vector3(1790.18, -284.04, 20.7), type = 'tape', text = "TAPE 12 — \"i keep hearing my own footsteps a half-second late.\"" },
        },
        [3] = { -- lv03: tapes on the far diagonal from the exits
            { coords = vector3(344.4, 5542.5, 14.4), type = 'tape', text = "TAPE 02 — \"if you're watching this, i never made it back. keep moving.\"" },
            { coords = vector3(368.4, 5518.5, 14.4), type = 'log',  text = "NOTE — \"the exits move. learn the hum, not the map.\"" },
        },
        [4] = { -- REAL coords from lv04 ymap; tapes on the far diagonal from the exits
            { coords = vector3(-2278.88, 1439.96, 81.7), type = 'log',  text = "PAGE 7 — \"day 19. the smiling one only moves when i blink.\"" },
            { coords = vector3(-2296.88, 1421.96, 81.7), type = 'tape', text = "TAPE 17 — \"there's a pool. it's the only warm sound left.\"" },
        },
    },
}

-------------------------------------------------------------------------------
-- [ SECTION 8: ALMOND WATER — survival counterplay ] --
-------------------------------------------------------------------------------

-- Almond Water (canon): the only thing that keeps you coherent down here. Bottles
-- are scattered per visit (server pool); walk up and press [E] to DRINK on the
-- spot — restores sanity. Standalone-first: no inventory needed (drinking is a
-- deliberate [E], so it's never force-wasted; a near-full drink is just refused).
-- (Framework-inventory mode — Almond Water as a real, stockpilable/tradeable item
-- via the F8 bridge — is an additive 2.1 layer, not wired here.)
-- FAKE placeholder coords until Iakko's map — grab real ones with /brhere.
MBT.AlmondWater = {
    Enabled       = true,
    SpawnPerVisit = 2,
    PickupRange   = 1.8,
    SanityRestore = 35,                 -- sanity points per bottle (capped at 100)
    PropModel     = 'prop_ld_flow_bottle', -- water bottle (swap if it doesn't spawn)
    Pool = {
        [1] = { -- lv01: bottles S side near the tapes
            { coords = vector3(1022.84, 796.09, 25.9) },
            { coords = vector3(1018.84, 796.09, 25.9) },
        },
        [2] = { -- lv02: bottles mid, ≥10m from exits
            { coords = vector3(1776.18, -270.04, 20.7) },
            { coords = vector3(1784.18, -278.04, 20.7) },
        },
        [3] = { -- lv03: bottles near the spawn (≥10m from exits)
            { coords = vector3(360.4, 5534.5, 14.4) },
            { coords = vector3(352.4, 5526.5, 14.4) },
        },
        [4] = { -- REAL coords from lv04 ymap; bottles near centre (≥10m from exits)
            { coords = vector3(-2284.88, 1427.96, 81.7) },
            { coords = vector3(-2290.88, 1433.96, 81.7) },
        },
    },
}

-------------------------------------------------------------------------------
-- [ SECTION 9: LIGHT — torch + darkness pressure ] --
-------------------------------------------------------------------------------

-- A torch you toggle inside a level. The tension (no dominant strategy):
--   torch OFF -> darker + sanity decays faster (DarkDecayMult), but the entity is
--                LESS likely (it's drawn to light).
--   torch ON  -> you can see, normal decay, BUT the entity is MORE likely
--                (LightEntityMult) — "the lights attract it".
-- It does NOT touch the timecycle (that's the atmosphere's job) — the torch is a
-- separate light source + a gameplay state ('mbt_backrooms:torch').
MBT.Light = {
    Enabled         = true,
    Key             = 'F',          -- toggle key
    Mode            = 'spotlight',  -- 'spotlight' (drawn cone — drop-in safe) | 'weapon' (WEAPON_FLASHLIGHT: real light, but takes the weapon slot → may clash with RP weapon systems)
    StartOn         = false,        -- torch on at level entry?
    DarkDecayMult   = 1.5,          -- sanity decay ×this while torch OFF
    LightEntityMult = 1.6,          -- entity glimpse chance ×this while torch ON
    -- 'spotlight' mode tuning (drawn cone from the camera)
    Range           = 25.0,
    Brightness      = 4.0,
    Radius          = 7.0,
}
