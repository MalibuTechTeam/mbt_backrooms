MBT = MBT or {}

-------------------------------------------------------------------------------
-- [ SECTION 1: GLOBAL ] --
-------------------------------------------------------------------------------

MBT.Language = 'en'  -- 'en' | 'it' | 'es' (add your own in locales/)
MBT.Debug    = false  -- MBTLog.Debug output + debug commands + zone markers

MBT.General = {
    InteractKey = 'E', -- pass through Enter points / pick up / drink
}

MBT.Notification = function(data)
    -- Default: native GTA feed (works with no framework)
    -- BeginTextCommandThefeedPost('STRING')
    -- AddTextComponentSubstringPlayerName(data.description or data.title or '')
    -- EndTextCommandThefeedPostTicker(false, true)

    -- ox_lib:
    -- exports.ox_lib:notify({ title = data.title, description = data.description, type = data.type or 'inform', duration = data.duration or 4000 })
    
    -- ESX:
    -- ESX.ShowNotification(data.description or data.title)
    
    -- QBCore:
    -- QBCore.Functions.Notify(data.description or data.title, data.type or 'primary')
    
    -- mbt_visual (our own notification system):
    -- exports.mbt_visual:notify({ title = data.title, description = data.description, type = data.type or 'inform', duration = data.duration or 5000 })
end

-------------------------------------------------------------------------------
-- [ SECTION 2: GAMEPLAY ] --
-------------------------------------------------------------------------------

-- Fall below this Z while falling -> pulled in. 0.0 = only under-map glitches.
MBT.FallingPoint = 0.0

-- Weighted exit destinations (relative weights). `default` applies to every exit;
-- add a numeric key (MBT.CuratedExits/BackRooms index) to override one.
MBT.ExitRules = {
    default = { surface = 30, backroom = 70 }, -- ~70% stay trapped (v1 feel)
}

-- On death inside a level, drop the player back to a surface point on respawn (so
-- they never wake up stuck in the now-empty backroom). Set false on framework
-- servers whose medical/hospital system should own the respawn instead.
MBT.OnDeathReturnSurface = true

-- Interior spawn coords, one per level.
MBT.Coords = {
    vector3(1026.88, 801.66, 25.88),   -- lvl_01 Iakko
    vector3(1780.18, -274.04, 20.66),  -- lvl_02 Iakko
    vector3(356.42, 5530.52, 14.37),   -- lvl_03 Iakko
    vector3(-2284.94, 1432.59, 81.70)  -- lvl_04 Iakko
}

-- Surface points a player can be spit back out to on escape.
MBT.RandomExitPoint = {
    vector3(-3090.44, 3322.13, 11.41),
    vector3(1163.97, 5964.91, 407.65),
    vector3(-557.24, 1890.37, 123.75),
    vector3(-54.04, 33.76, 1924.76),
    vector3(-159.57, -975.7, 115.28),
    vector3(1753.06, 4228.73, -5.85)
}

-- Manual interaction points. Enter = deliberate [E] door into a random backroom.
-- Exit = manual [E] exit door (LEGACY — in-level exits now use MBT.CuratedExits);
-- the four real exit-door coords are kept commented for anyone who wants them back.
MBT.BackRooms = {
    -- { Type = "Exit",  Coords = vector3(310.52, 5522.78, 14.51),   Range = 1.5 }, -- lv03 door
    -- { Type = "Exit",  Coords = vector3(1779.16, -260.81, 20.86),  Range = 1.5 }, -- lv02 door
    -- { Type = "Exit",  Coords = vector3(-2301.72, 1416.78, 81.92), Range = 1.5 }, -- lv04 door
    -- { Type = "Exit",  Coords = vector3(1017.94, 800.23, 25.92),   Range = 1.5 }, -- lv01 door
    { Type = "Enter", Coords = vector3(1112.08, 2188.65, 46.39),  Range = 2.0 },
    { Type = "Enter", Coords = vector3(-220.38, 3649.13, 51.75),  Range = 2.0 },
    { Type = "Enter", Coords = vector3(-440.85, 1598.89, 358.47), Range = 2.0 },
    { Type = "Enter", Coords = vector3(1665.08, -28.03, 196.94),  Range = 2.0 },
    { Type = "Enter", Coords = vector3(3426.76, 5174.49, 7.41),   Range = 2.0 }
}

-- Invisible "no-clip" entry zones (server-validated). size = box half-extents, or
-- set `radius` for a sphere. chance = % to clip once `dwell` (s inside) is met.
-- Markers are DEBUG-ONLY. Tip: /brhere (Debug) grabs coords in-game.
MBT.NoClipZones = {
    -- { coords = vector3(195.0, -934.0, 30.7), size = vector3(1.2, 1.2, 2.0), chance = 100, dwell = 0 },
    -- { coords = vector3(-1108.0, -2008.0, 13.2), radius = 1.5, chance = 30, dwell = 2 }, -- sphere
    -- { coords = vector3(203.91, -931.36, 30.69), size = vector3(1.5, 1.5, 2.0), chance = 100, dwell = 0 }, -- local test zone
}

-------------------------------------------------------------------------------
-- [ SECTION 3: ATMOSPHERE ] --
-------------------------------------------------------------------------------

-- Entry transition (no jumpscare): 'glitch' (VHS burst) | 'fade' | 'cut' (v1).
MBT.Transition = 'glitch'

-- First-person found-footage view while inside; restored on exit.
MBT.Camera = {
    ForceFirstPerson = true,
    Lock             = true, -- block switching back to third person
}

MBT.Atmosphere = {
    Enabled = true,
    Mode    = 'mix', -- effect sources: 'native' | 'nui' | 'mix'

    Intensity = { Native = 0.85, NUI = 0.75, Audio = 0.55 }, -- 0..1 per family

    -- Level darkness = a linear NUI gloom (so the torch matters), 0 = off .. 1 = very
    -- dark. ~0.4–0.55 = dim/oppressive.
    Darkness = { Enabled = true, Strength = 0.45 },

    ReduceMotion   = false, -- kills shake + screen-tear + grain jitter
    ReduceFlashing = false, -- kills light flicker + glitch strobe

    Effects = {
        -- Native ----------------------------------------------------------------
        -- Timecycle tint, picked per entry by `select`: 'random' | 'perLevel' | 'fixed'.
        Timecycle = {
            enabled = true, source = 'native', select = 'random',
            variants = {
                { modifier = 'scanline_cam_cheap',  strength = 1.0 },
                { modifier = 'prologue_ending_fog', strength = 0.6 },
            },
        },
        LightFlicker = { enabled = true, source = 'native', minDelayMs = 3000, maxDelayMs = 10000, burstMinMs = 60, burstMaxMs = 400 },
        EntryShake   = { enabled = true, source = 'native', shake = 'SMALL_EXPLOSION_SHAKE', amplitude = 0.35, durationMs = 900 },
        EntryPostFx  = { enabled = true, source = 'native', name = 'DeathFailMPDark', durationMs = 900 },
        -- NUI -------------------------------------------------------------------
        Vhs        = { enabled = true, source = 'nui', grain = true },
        Hum        = { enabled = true, source = 'nui', volume = 0.5 },
        Drone      = { enabled = true, source = 'nui', volume = 0.35 },
        EntrySting = { enabled = true, source = 'nui', volume = 0.7 },
    },
}

-------------------------------------------------------------------------------
-- [ SECTION 4: SANITY ] --
-------------------------------------------------------------------------------

-- Server-authoritative (0-100): decays inside (faster alone), regens on surface;
-- drives the vignette + critical shake. Entity glimpse subtracts SmilerHit.
MBT.Sanity = {
    Enabled        = true,
    DecayPerMinute = 8,
    IsolationMult  = 1.6,  -- ×decay when alone in your level
    RegenOnSurface = 25,
    SmilerHit      = 15,
    LowThreshold      = 50, -- vignette ramps below this
    CriticalThreshold = 20, -- shake/distortion below this
    FullThreshold     = 98, -- Almond Water won't drink at/above this (no waste)
    PersistAcrossSessions = false, -- needs the framework bridge (2.1)
}

-- First-contact dread (lore-faithful): the first time another lost player comes
-- close in your level, a reality-jolt fires + a sanity spike — "is that a person
-- or the entity?". No nameplate/marker; re-arms once they move away (Range+Linger)
-- and after CooldownSec. Other players slow your decay (occupancy, above) but the
-- first sighting still costs — the Backrooms make every presence unnerving first.
MBT.PlayerContact = {
    Enabled     = true,
    Range       = 22.0, -- another wanderer this close triggers the startle (m)
    Linger      = 6.0,  -- must move beyond Range+Linger to re-arm a later approach
    SanitySpike = 8,    -- the nervous-system jolt on first contact
    CooldownSec = 25,   -- min seconds between startles from the SAME player
    Sound       = true, -- play the entry sting on contact
}

-------------------------------------------------------------------------------
-- [ SECTION 5: ENTITIES ] --
-------------------------------------------------------------------------------

-- Scripted GLIMPSE: at low sanity an entity appears at a distance, holds, and
-- vanishes when stared at / reached / timed out. Not a chasing AI (2.1).
MBT.Entities = {
    Enabled       = true,
    Models        = { 'Smiler_BR', 'Stealer' }, -- bundled peds (stream/entities)
    MinSanityGate = 50,    -- glimpses only fire below this sanity
    CooldownSec   = 90,    -- min seconds between glimpses
    Chance        = 50,    -- % roll each eligible check
    SpawnDistance = 18.0,
    HoldSec       = 6,     -- max linger (static-glimpse mode)
    GazeAngle     = 14.0,  -- within this many degrees = "looking at it"
    ApproachDist  = 2.5,   -- reaching you ends it (sanity hit + vanish)
    SanityHit     = 15,

    -- Weeping-Angel stalk: creeps toward you while unobserved, freezes when watched.
    Approach           = true, -- false = static glimpse
    ApproachSpeed      = 1.2,
    ApproachTimeoutSec = 15,

    -- Don't-Blink (stalk only): staring freezes it but drains focus; at zero you
    -- blink and it lunges closer. Looking away regenerates focus but it creeps in.
    DontBlink = {
        Enabled         = true,
        DrainPerSec     = 0.5,
        RegenPerSec     = 0.4,
        BlinkMs         = 220,
        BlinkAdvance    = 3.0,  -- metres it lunges during the blink
        FocusAfterBlink = 0.5,
    },

    -- Sound cues (web/public/sounds/<file>.ogg): spawn = presence, look = it sees you.
    Sound = { OnSpawn = true, OnLook = true, SpawnFile = 'tape_warble', LookFile = 'sting', Volume = 0.7 },
}

-------------------------------------------------------------------------------
-- [ SECTION 6: CURATED EXITS ] --
-------------------------------------------------------------------------------

-- Ambient exits (no marker/prompt): the server makes a random subset live per visit;
-- you SENSE them (a screen tell that swells as you near) and lingering inside pulls
-- you through. dest = 'surface' (escape) | 'backroom' (dumped deeper). Pool index =
-- level. Coords derived from Iakko's ymaps; verify/replace in-game with /brhere.
MBT.CuratedExits = {
    Enabled        = true,
    ActivePerVisit = 2,    -- pool entries live each entry
    TellRange      = 9.0,  -- start sensing within this distance (m)
    Pool = {
        [1] = { -- small ~16m room: exits N, pickups S
            { coords = vector3(1025.84, 807.09, 25.9), radius = 1.6, dest = 'surface'  },
            { coords = vector3(1015.84, 807.09, 25.9), radius = 1.6, dest = 'backroom' },
        },
        [2] = {
            { coords = vector3(1792.18, -266.04, 20.7), radius = 1.6, dest = 'surface'  },
            { coords = vector3(1768.18, -282.04, 20.7), radius = 1.6, dest = 'backroom' },
        },
        [3] = { -- big room
            { coords = vector3(370.4, 5540.5, 14.4), radius = 1.6, dest = 'surface'  },
            { coords = vector3(342.4, 5520.5, 14.4), radius = 1.6, dest = 'backroom' },
        },
        [4] = {
            { coords = vector3(-2298.88, 1441.96, 81.7), radius = 1.6, dest = 'surface'  },
            { coords = vector3(-2276.88, 1419.96, 81.7), radius = 1.6, dest = 'backroom' },
        },
    },
}

-- Soft pull-in: linger inside an active exit and a warp builds over DurationMs, then
-- pulls you through (step out to cancel). Ptfx = a paper-swirl during the pull only
-- (StartAt = pull progress before it shows), so the exit stays unmarked at rest.
MBT.SoftPullIn = {
    Enabled    = true,
    DurationMs = 3000,
    Ptfx = {
        Enabled  = true,
        Dict     = 'core',
        Name     = 'env_dust_devil_urban_lrg',
        StartAt  = 0.1,
        MinScale = 0.5,
        MaxScale = 1.5,
    },
}

-------------------------------------------------------------------------------
-- [ SECTION 7: ARTIFACTS — found tapes / logs ] --
-------------------------------------------------------------------------------

-- Narrative spine: tapes/logs scattered per visit; [E] to record one -> its `text`
-- flashes as a found-footage caption (reward = lore, no HUD counter). Carry them to
-- the surface to "recover" them. Pool index = level; coords from ymaps (verify /brhere).
MBT.Artifacts = {
    Enabled       = true,
    SpawnPerVisit = 2,
    PickupRange   = 1.8,
    PropModel     = 'prop_notepad_01', -- fallback (used for type='log')
    -- Distinct prop per artifact type (falls back to PropModel). Verify in-game and
    -- swap any that don't spawn (a warn fires on load failure). 'tape' is a CANDIDATE
    -- cassette model — confirm it exists on your build or pick your own.
    PropModelByType = {
        log  = 'prop_notepad_01',
        tape = 'm23_2_prop_m32_cassette_01a',
    },
    -- Crouch-and-grab animation when you record/pick one up (cosmetic). time = ms
    -- the collect request fires at the end so the prop vanishes as you "grab" it.
    PickupAnim = { dict = 'anim@mp_snowball', clip = 'pickup_snowball', time = 900 },
    -- `id` is a stable unique key; `category` feeds the Archive's per-category
    -- confidence (entity | exits | personnel | geometry | contamination).
    Pool = {
        [1] = {
            { id = 'tape04', category = 'geometry',      coords = vector3(1024.84, 795.09, 25.9), type = 'tape', text = "TAPE 04 — \"the lights hum in B-flat. counted 1,400 before i stopped.\"" },
            { id = 'note01', category = 'exits',         coords = vector3(1016.84, 795.09, 25.9), type = 'log',  text = "NOTE — \"don't go back the way you came. it isn't there anymore.\"" },
            { id = 'tape09', category = 'exits',         coords = vector3(1020.84, 793.50, 25.9), type = 'tape', text = "TAPE 09 — \"found a door. almond water on the other side. i think.\"" },
        },
        [2] = {
            { id = 'memo01', category = 'entity',        coords = vector3(1770.18, -264.04, 20.7), type = 'log',  text = "MEMO — \"the walls are warm here. that means something is awake.\"" },
            { id = 'tape12', category = 'entity',        coords = vector3(1790.18, -284.04, 20.7), type = 'tape', text = "TAPE 12 — \"i keep hearing my own footsteps a half-second late.\"" },
        },
        [3] = {
            { id = 'tape02', category = 'personnel',     coords = vector3(344.4, 5542.5, 14.4), type = 'tape', text = "TAPE 02 — \"if you're watching this, i never made it back. keep moving.\"" },
            { id = 'note02', category = 'exits',         coords = vector3(368.4, 5518.5, 14.4), type = 'log',  text = "NOTE — \"the exits move. learn the hum, not the map.\"" },
        },
        [4] = {
            { id = 'page07', category = 'entity',        coords = vector3(-2278.88, 1439.96, 81.7), type = 'log',  text = "PAGE 7 — \"day 19. the smiling one only moves when i blink.\"" },
            { id = 'tape17', category = 'contamination', coords = vector3(-2296.88, 1421.96, 81.7), type = 'tape', text = "TAPE 17 — \"there's a pool. it's the only warm sound left.\"" },
        },
    },
}

-------------------------------------------------------------------------------
-- [ SECTION 8: ALMOND WATER — survival counterplay ] --
-------------------------------------------------------------------------------

-- Canon item that keeps you coherent. Bottles scattered per visit; [E] plays the
-- drink anim for UseTime then restores sanity (refused when near-full, so never
-- wasted). Standalone — no inventory. Pool index = level (verify /brhere).
MBT.AlmondWater = {
    Enabled       = true,
    SpawnPerVisit = 2,
    PickupRange   = 1.8,
    SanityRestore = 35,
    PropModel     = 'prop_ld_flow_bottle', -- swap if it doesn't spawn
    UseTime  = 2500,
    Anim     = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
    HeldProp = { model = 'prop_ld_flow_bottle', pos = vector3(0.03, 0.03, 0.02), rot = vector3(0.0, 0.0, -1.5) },
    Pool = {
        [1] = {
            { coords = vector3(1022.84, 796.09, 25.9) },
            { coords = vector3(1018.84, 796.09, 25.9) },
        },
        [2] = {
            { coords = vector3(1776.18, -270.04, 20.7) },
            { coords = vector3(1784.18, -278.04, 20.7) },
        },
        [3] = {
            { coords = vector3(360.4, 5534.5, 14.4) },
            { coords = vector3(352.4, 5526.5, 14.4) },
        },
        [4] = {
            { coords = vector3(-2284.88, 1427.96, 81.7) },
            { coords = vector3(-2290.88, 1433.96, 81.7) },
        },
    },
}

-------------------------------------------------------------------------------
-- [ SECTION 9: LIGHT — torch + darkness pressure ] --
-------------------------------------------------------------------------------

-- Torch (toggle). OFF = sanity decays ×DarkDecayMult, entity rarer; ON = you see but
-- the entity is likelier (×LightEntityMult). A separate light, not a timecycle.
MBT.Light = {
    Enabled         = true,
    Key             = 'F',
    Mode            = 'spotlight', -- 'spotlight' (drawn, drop-in safe) | 'weapon' (WEAPON_FLASHLIGHT, takes the weapon slot)
    StartOn         = false,
    DarkDecayMult   = 1.5,
    LightEntityMult = 1.6,
    Range           = 25.0, -- spotlight mode tuning
    Brightness      = 4.0,
    Radius          = 7.0,
}

-- In-level HUD: torch-key hint + opt-in stylized sanity signal (no number/bar — the
-- vignette/shake stay the real tell). ShowSanity off by default to keep the no-HUD tone.
MBT.HUD = {
    Enabled    = true,
    TorchHint  = true,  -- show the "[F] torch" key hint while inside a level
    ShowSanity = false, -- stylized signal indicator (no numbers); opt-in
}

-------------------------------------------------------------------------------
-- [ SECTION 10: ARCHIVE — review recovered tapes on an in-world TV screen ] --
-------------------------------------------------------------------------------

-- Surface TV terminal to review recovered tapes/logs (Section 7): walk up, [E] frames
-- the screen and projects a crisp NUI onto it. Placed in-game with /brsetarchive (popup)
-- and persisted server-side (KVP) — shared by everyone.
MBT.Archive = {
    Enabled      = true,
    PromptRange  = 2.0,
    Prop         = 'xm_prop_x17_tv_flat_01', -- flat TV (RT 'tv_flat_01'); placed via /brsetarchive
    DefaultSpawn = nil, -- nil = placement-only; set { x,y,z,h } to pre-place one
    RenderTarget = 'tv_flat_01',
    RenderRange  = 25.0, -- draw the screen within this distance (m)
    -- [E] framing + screen-face geometry (m, vs prop) for the NUI projection. Both tuned
    -- live via /brsetarchive; side = screen facing vs heading (flip if cam ends up behind).
    Camera = { dist = 1.8, side = -1.0, aimZ = 1.1, height = 1.1, fov = 42.0 },
    Screen = { offX = 0.0, offY = 0.04, offZ = 0.0, w = 1.05, h = 0.6 },
    -- Optional decorative prop by the TV (cassette/VCR), relative offset. nil = none.
    Decor = nil, -- e.g. { model = 'm23_2_prop_m32_cassette_01a', offX = 0.0, offY = 0.1, offZ = -0.5, heading = 0.0 }

    -- Research mode: recovered tapes raise a per-category "confidence" that unlocks
    -- diegetic knowledge in the archive. Reward = knowing, not loot. Per-player for
    -- now (communal/ARG + payout = 2.1). Enabled=false -> archive is pure-lore.
    ResearchMode = {
        Enabled = true,
        -- Hints unlock when confidence (distinct recovered tapes of that category)
        -- reaches `at`. Text-only field notes — shown in the archive, never on HUD.
        Hints = {
            exits = {
                { at = 1, text = "Warmer air near service doors before egress." },
                { at = 3, text = "Exit Class B: maintenance signage, low hum, a yellowed threshold." },
            },
            entity        = { { at = 1, text = "Blink-loss clusters in long, straight corridors. Don't fixate." } },
            personnel     = { { at = 1, text = "Most who file a final tape describe the same calm. Then they stop moving." } },
            geometry      = { { at = 1, text = "The hum repeats; the layout doesn't. Map the sound, not the walls." } },
            contamination = { { at = 1, text = "Almond scent precedes partial boundary thinning." } },
        },
        -- `exits` ONLY gets a small mechanical edge ("sensory literacy"): your exit
        -- confidence makes the existing curated-exit tell start earlier / read clearer.
        -- No markers, no new exits — capped. Keyed by confidence threshold.
        ExitLiteracy = {
            Enabled  = true,
            [1] = { rangeBonus = 1.0, tellMult = 1.10 }, -- Pattern Noted
            [3] = { rangeBonus = 2.0, tellMult = 1.20 }, -- Corroborated
        },
    },
}
