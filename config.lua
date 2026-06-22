MBT = MBT or {}

-------------------------------------------------------------------------------
-- [ SECTION 1: GLOBAL SETTINGS ] --
-------------------------------------------------------------------------------

MBT.Language = 'en' -- Options: 'en', 'it', 'es' (loads from locales/*.lua — add your own there)
MBT.Debug    = false -- Enable Utils.MbtDebugger logs

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
--   marker : (optional) true -> draw a visible marker for this zone for everyone.
--            All zones also show a marker automatically while MBT.Debug is on.
-- Tip: use the /brhere debug command (needs MBT.Debug) to grab coords in-game.
MBT.NoClipZones = {
    -- { coords = vector3(195.0, -934.0, 30.7), size = vector3(1.2, 1.2, 2.0), chance = 100, dwell = 0 },
    -- { coords = vector3(-1108.0, -2008.0, 13.2), radius = 1.5, chance = 30, dwell = 2 },
    -- { coords = vector3(203.91, -931.36, 30.69), size = vector3(1.5, 1.5, 2.0), chance = 100, dwell = 0, marker = true },
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
