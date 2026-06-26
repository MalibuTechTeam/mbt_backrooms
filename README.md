# MBT Backrooms — Liminal Horror Map & Script for FiveM

<p align="center">
  <img src="https://img.shields.io/badge/FiveM-Ready-00e676?style=for-the-badge&logo=fivem&logoColor=white" alt="FiveM Ready" />
  <img src="https://img.shields.io/badge/Framework-ESX%20%7C%20ox__lib%20%7C%20QBCore%20%7C%20QBox%20%7C%20Standalone-blue?style=for-the-badge" alt="Framework" />
  <img src="https://img.shields.io/badge/Version-2.0.0-informational?style=for-the-badge" alt="Version" />
  <img src="https://img.shields.io/badge/Lua-5.4-purple?style=for-the-badge&logo=lua" alt="Lua 5.4" />
  <img src="https://img.shields.io/badge/React-TypeScript-61DAFB?style=for-the-badge&logo=react" alt="React + TS" />
  <img src="https://img.shields.io/badge/Map%20%2B%20Script-OneSync-orange?style=for-the-badge" alt="Map + Script" />
</p>

<p align="center">
  <img src="https://dunb17ur4ymx4.cloudfront.net/packages/images/824f127b2432767bde2afa0b13e1443ca0e03b12.png" alt="MBT Backrooms" />
</p>

**mbt_backrooms** turns the classic "fall out of reality" map into a full liminal-horror **survival loop**. Glitch into the Backrooms through hidden no-clip spots or a bad clip under the map, then survive a found-footage VHS world that erodes your **sanity**, watches you from the dark with a **Don't-Blink entity**, and rarely lets you back out. Toggle a **torch** to see (but the dark hides you), drink **Almond Water** to stay coherent, find your way out through **invisible curated exits** you have to *sense* — and recover **found-footage tapes** to review on an in-world **archive terminal** back on the surface. Server-authoritative, multi-framework, and standalone-first — built with a modern React + TypeScript NUI overlay tuned for FiveM's CEF.

> **Free & community-first.** This project is and always will be free. Our goal is to involve as many FiveM mappers as possible so the Backrooms keep growing, level after level — every contributor gets added to the credits. It rides the liminal/Backrooms aesthetic (4chan → Kane Pixels → the 2026 film) without claiming any affiliation.

---

## Features

### Atmosphere (the "reality shift")
- **Entry transition** — every teleport plays a no-jumpscare **VHS / no-clip glitch** (postfx + camera shake + audio sting). Switchable to a simple `fade` or the original hard `cut`.
- **First-person found-footage view** — forced (and optionally locked) first person while inside, so the VHS overlay reads as *your eyes*. Your previous camera is restored on exit.
- **Native + NUI effects** — timecycle tints (random / per-level / fixed), neon **light flicker**, full-screen **VHS scanlines + grain + vignette**, and a continuous **hum / drone** audio bed. Everything scales by per-family intensity and has `native` / `nui` / `mix` modes.
- **Accessibility** — `ReduceMotion` (kills shake + screen-tear + grain jitter) and `ReduceFlashing` (kills the strobe/flicker) honor both the config and the OS `prefers-reduced-motion`.

### Entering & escaping
- **No-clip entry zones** — invisible volumes in "wrong" spots (dead-end corners, behind walls, under stairs). Walk in and reality fails. Server-validated with `chance` + `dwell` anti-exploit. Markers are **debug-only** — in production these spots stay invisible.
- **Fall-through** — clip *under the map* and you're pulled in (tuned so falling off buildings never triggers it).
- **Curated exits (sensed, not seen)** — the in-level way out: **invisible** exits with no marker and no prompt. A screen/audio **tell** intensifies as you near one, and lingering inside builds a **soft pull-in** (a paper-swirl warp) that pulls you through — step out to cancel. You learn the hum, not the map.
- **Weighted destinations** — every exit rolls `MBT.ExitRules`: escape to the surface or get dumped back into another Backroom. Faithful to the lore — getting out is never guaranteed (default ~70% trapped). Per-exit overrides supported.
- **Death returns you to the surface** — dying inside spits you back out on respawn instead of leaving you stuck in the void (`MBT.OnDeathReturnSurface`; turn off to defer to a framework medical system).

### Sanity
- **Server-authoritative sanity (0–100)** — decays while inside (faster when you're **alone** in your level), regenerates on the surface.
- **Diegetic feedback** — a closing-in vignette ramps at low sanity; camera shake + heavier distortion kick in when critical. No HUD meter — the dread is sensory.
- **Entity sightings** cost sanity instantly.

### The Entity (Don't-Blink)
- **Weeping-Angel mechanic** — in darkness / low sanity an entity appears at a distance, **freezes while you look at it**, and **creeps toward you while unobserved**. Reaching you = sanity hit + vanish.
- **Don't-Blink** — staring at it *drains your focus*: vision tunnels in, then a **forced blink** blacks the screen for a beat — and it lunges closer while your eyes are shut.
- **Light attracts** — toggling the torch on makes a glimpse more likely (a deliberate risk/reward with seeing in the dark).
- **Polished presence** — camera-raycast placement (never spawns in your face), a soft alpha fade-out, and a gaze-deferred despawn so it never pops out while you're staring at it.
- **Model-agnostic** — ships with two bundled Backrooms peds (Smiler + Skin Stealer) and falls back gracefully; swap in your own via `MBT.Entities.Models`.

### Survival — Almond Water & torch
- **Almond Water** — canon item scattered through the levels: walk up, `[E]`, a drinking animation plays and your **sanity is restored** (refused when you're near-full, so it's never wasted). Standalone — no inventory needed.
- **Torch + darkness** — levels are genuinely dark (a tunable NUI gloom, so the torch *matters*). Toggle a torch to see — but the dark keeps the entity at bay, and the light draws it in.

### Found tapes & the Archive
- **Found-footage tapes/logs** — scattered per visit; `[E]` to record one (a found-footage caption flashes — the reward is **lore, not loot**, no HUD counter). Carry them out to the surface to **recover** them.
- **The Archive terminal** — an in-world TV on the surface: walk up, `[E]`, the camera frames the screen and it **powers on** (CRT-style) to play back your recovered footage as a crisp, projected NUI. Place/position the terminal in-game with an admin popup; it persists server-side.
- **Research Mode** — recovered tapes raise a per-category **confidence** that unlocks diegetic **field notes** in the archive (knowledge, not loot). The `exits` category grants a small "sensory literacy" that makes the curated-exit tells read a touch earlier/clearer (capped — never a marker). Config-gated; off → the archive is pure-lore.

### In-level HUD
- A minimal, diegetic HUD: a **torch-key hint** and an **opt-in, non-numeric sanity signal** (a degrading indicator, not a bar) — off by default to keep the no-HUD tone.

### Architecture
- **Server-authoritative** — all entry/exit/state lives on the server via OneSync state bags (`inLevel` / `entryTime` / `exitLocked` / `sanity` / `torch` / active sets), token-matched and rate-limited. Clients can't teleport themselves. The archive terminal's placement persists via KVP.
- **One config-driven notification** — every notification flows through a single `MBT.Notification(data)` you wire once (native GTA feed by default; ox_lib / ESX / QBCore / `mbt_visual` presets commented in config). The framework bridge now only **detects** the stack (auto: ESX → ox_lib → QBCore → QBox → standalone) + holds an inventory abstraction, dormant until 2.1.
- **Admin tooling** — ACE-gated commands to inspect and manage players in the Backrooms.
- **MBT modular pattern** — `core/`, `modules/{atmosphere,sanity,entities,exits,artifacts,almondwater,light,archive,hud,interaction,bridge,inventory,admin,utils}`, `locales/`, `web/`.

### Localization
Built-in translations for **English, Italian, Spanish**. Add your own by dropping a file in `locales/`.

---

## Requirements

| Dependency | Requirement |
|---|---|
| [FiveM Server](https://fivem.net) | Recent artifact (build 6116+) |
| OneSync | **Enabled** (required — uses state bags) |
| Framework | **None** — standalone. ESX / ox_lib / QBCore / QBox auto-detected if present |

---

## Installation

1. Download or clone this repository into your server's `resources` folder as `mbt_backrooms`.

2. Add to your `server.cfg`:
   ```cfg
   ensure mbt_backrooms
   ```
   > Make sure **OneSync is enabled** on your server.

3. Configure `config.lua` to your liking (see Configuration below).

4. Restart your server, or run `ensure mbt_backrooms` in the live console.

> The NUI is **pre-built** (`web/dist`). To rebuild it after editing the React source: `cd web && bun install && bun run build`.

---

## Configuration

All configuration lives in `config.lua`.

### Global

```lua
MBT.Language = 'en'    -- 'en', 'it', 'es' (add your own in locales/)
MBT.Debug    = false   -- MBTLog debug output + debug commands + zone markers
MBT.General  = { InteractKey = 'E' } -- key to pass through Enter/Exit points
```

### Gameplay

```lua
MBT.FallingPoint = 0.0  -- clip BELOW this Z while falling -> pulled in (under-map only)

-- Weighted exit destinations (relative weights). Default reproduces v1's ~70% trapped.
MBT.ExitRules = {
    default = { surface = 30, backroom = 70 },
    -- [1] = { surface = 5, backroom = 95 }, -- override a specific exit point
}

MBT.OnDeathReturnSurface = true  -- die inside -> respawn on the surface (false = let a framework medical system handle it)

MBT.Coords          = { --[[ interior spawn per level ]] }
MBT.RandomExitPoint = { --[[ surface points you can be spit back out to ]] }

-- Interaction points. Enter -> always a random backroom. Exit -> rolls ExitRules.
MBT.BackRooms = {
    { Type = "Exit",  Coords = vector3(310.52, 5522.78, 14.51), Range = 1.5 },
    { Type = "Enter", Coords = vector3(1112.08, 2188.65, 46.39), Range = 2.0 },
}

-- Invisible "no-clip" entry zones (server-validated). Markers are DEBUG-ONLY.
MBT.NoClipZones = {
    { coords = vector3(195.0, -934.0, 30.7), size = vector3(1.2, 1.2, 2.0), chance = 100, dwell = 0 },
    -- { coords = vector3(-1108.0, -2008.0, 13.2), radius = 1.5, chance = 30, dwell = 2 }, -- sphere
}
```
> `chance` = % to clip once `dwell` (seconds inside) is satisfied. Use `size` for a box or `radius` for a sphere.

### Transition & Camera

```lua
MBT.Transition = 'glitch'   -- 'glitch' (VHS burst) | 'fade' | 'cut' (original v1)

MBT.Camera = {
    ForceFirstPerson = true, -- found-footage view on entry
    Lock             = true, -- block switching back to third person while inside
}
```

### Atmosphere

```lua
MBT.Atmosphere = {
    Enabled   = true,
    Mode      = 'mix',  -- 'native' | 'nui' | 'mix'
    Intensity = { Native = 0.85, NUI = 0.75, Audio = 0.55 },

    ReduceMotion   = false, -- disable camera shake + screen-tear + grain jitter
    ReduceFlashing = false, -- disable light flicker + glitch strobe

    Effects = {
        Timecycle    = { enabled = true, source = 'native', select = 'random', variants = { --[[ ... ]] } },
        LightFlicker = { enabled = true, source = 'native', minDelayMs = 3000, maxDelayMs = 10000 },
        EntryShake   = { enabled = true, source = 'native', shake = 'SMALL_EXPLOSION_SHAKE', amplitude = 0.35 },
        EntryPostFx  = { enabled = true, source = 'native', name = 'DeathFailMPDark' },
        Vhs          = { enabled = true, source = 'nui', grain = true },
        Hum          = { enabled = true, source = 'nui', volume = 0.5 },
        Drone        = { enabled = true, source = 'nui', volume = 0.35 },
        EntrySting   = { enabled = true, source = 'nui', volume = 0.7 },
    },
}
```
> `Timecycle.select`: `random` (default, most disorienting) · `perLevel` (each level keeps its tint = identity) · `fixed`.

### Sanity

```lua
MBT.Sanity = {
    Enabled        = true,
    DecayPerMinute = 8,    -- base erosion while inside
    IsolationMult  = 1.6,  -- ×decay when alone in your level
    RegenOnSurface = 25,   -- recovery/min on the surface
    LowThreshold      = 50, -- vignette starts ramping below this
    CriticalThreshold = 20, -- shake / heavy distortion below this
    FullThreshold     = 98, -- Almond Water won't drink at/above this (no waste)
    PersistAcrossSessions = false, -- needs the framework bridge (2.1)
}
```

### Entities

```lua
MBT.Entities = {
    Enabled       = true,
    Models        = { 'Smiler_BR', 'Stealer' }, -- bundled peds; swap for your own
    MinSanityGate = 50,    -- glimpses only fire below this sanity
    CooldownSec   = 90,    -- min seconds between glimpses
    Chance        = 50,    -- % roll each eligible check
    SpawnDistance = 18.0,
    GazeAngle     = 14.0,  -- looking within this many degrees = "looking at it"
    ApproachDist  = 2.5,   -- reaching you ends the encounter
    SanityHit     = 15,

    Approach           = true, -- Weeping-Angel stalk (false = static glimpse)
    ApproachSpeed      = 1.2,
    ApproachTimeoutSec = 15,

    Sound = { OnSpawn = false, OnLook = true, File = 'entry', Volume = 0.7 },
}
```

### Curated exits & soft pull-in

```lua
MBT.CuratedExits = {
    Enabled        = true,
    ActivePerVisit = 2,    -- how many pool entries are live each visit
    TellRange      = 9.0,  -- start sensing within this distance (m)
    Pool = { [1] = { { coords = vector3(...), radius = 1.6, dest = 'surface' } } }, -- per level
}
MBT.SoftPullIn = {
    Enabled    = true,
    DurationMs = 3000,     -- linger this long inside to be pulled through
    Ptfx = { Enabled = true, Dict = 'core', Name = 'env_dust_devil_urban_lrg', StartAt = 0.1 },
}
```

### Almond Water & torch

```lua
MBT.AlmondWater = {
    Enabled = true, SpawnPerVisit = 2, PickupRange = 1.8, SanityRestore = 35,
    Anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' }, UseTime = 2500,
    Pool = { [1] = { { coords = vector3(...) } } }, -- per level
}
MBT.Light = {
    Enabled = true, Key = 'F',
    Mode = 'spotlight',     -- 'spotlight' (drawn, drop-in safe) | 'weapon' (WEAPON_FLASHLIGHT)
    DarkDecayMult = 1.5,    -- ×sanity decay when the torch is OFF
    LightEntityMult = 1.6,  -- ×entity chance when the torch is ON (light attracts)
}
-- Level darkness is a linear NUI gloom (so the torch matters):
MBT.Atmosphere.Darkness = { Enabled = true, Strength = 0.45 } -- 0 = off .. 1 = very dark
```

### Found tapes, Archive & Research Mode

```lua
MBT.Artifacts = {
    Enabled = true, SpawnPerVisit = 2, PickupRange = 1.8,
    PropModelByType = { log = 'prop_notepad_01', tape = 'm23_2_prop_m32_cassette_01a' },
    PickupAnim = { dict = 'anim@mp_snowball', clip = 'pickup_snowball', time = 900 },
    Pool = { [1] = { { id = 'tape04', category = 'exits', type = 'tape', text = "..." } } },
}

MBT.Archive = {
    Enabled = true,
    Prop = 'xm_prop_x17_tv_flat_01',  -- a render-target-capable screen prop
    RenderTarget = 'tv_flat_01',      -- must match the prop's screen RT name
    Camera = { dist = 1.8, side = -1.0, aimZ = 1.1, height = 1.1, fov = 42.0 }, -- [E] framing
    Screen = { offX = 0.0, offY = 0.04, offZ = 0.0, w = 1.05, h = 0.6 },        -- NUI projection rect
    ResearchMode = {
        Enabled = true,
        Hints = { exits = { { at = 1, text = "..." } }, --[[ entity, geometry, personnel, contamination ]] },
        ExitLiteracy = { Enabled = true, [1] = { rangeBonus = 1.0, tellMult = 1.1 } },
    },
}
```
> Place the terminal in-game: `/brsetarchive` opens a popup to position the TV + tune the camera and the on-screen rect live; it persists server-side (KVP). Use a prop whose screen render target is known (e.g. `prop_tv_flat_02` → `tvscreen`).

### HUD

```lua
MBT.HUD = {
    Enabled    = true,
    TorchHint  = true,   -- show the "[F] torch" key hint while inside a level
    ShowSanity = false,  -- opt-in stylized (non-numeric) sanity signal
}
```

### Notifications

One config-driven function — wire your stack **once**:

```lua
MBT.Notification = function(data) -- { title?, description, type?, duration? }
    -- native GTA feed by default; uncomment your stack's preset:
    -- exports.ox_lib:notify({ title = data.title, description = data.description, type = data.type })
    -- ESX.ShowNotification(data.description)  ·  QBCore.Functions.Notify(data.description)
    -- exports.mbt_visual:notify({ ... })      -- our own notification system
end
```
> The framework bridge still **auto-detects** ESX / ox_lib / QBCore / QBox / standalone; notifications just no longer live in it.

---

## Commands

### Debug (require `MBT.Debug = true`)

| Command | Action |
|---|---|
| `/brfall` | Simulate a fall-through entry |
| `/brenter` | Force-enter a random backroom |
| `/brexit` | Force an exit roll |
| `/brhere` | Print your current coords + a paste-ready entry (for placing points/zones) |
| `/brtc` | Cycle timecycle variants to preview them |
| `/brtorch` | Toggle the torch |
| `/brglimpse` | Force an entity glimpse now |
| `/brexits` · `/brartifacts` · `/bralmond` | List + marker the active curated exits / tapes / Almond Water |
| `/brarchivedemo` | Power on the archive TV with every tape/note (preview the populated screen) |

### Archive placement (`MBT.Debug` or ACE `mbt_backrooms.admin`)

| Command | Action |
|---|---|
| `/brsetarchive` | Open the placement popup: position the TV + tune the camera & on-screen rect live; persists server-side (KVP) |

### Admin (ACE permission `mbt_backrooms.admin`)

| Command | Action |
|---|---|
| `/brstatus` | List players currently inside the Backrooms + their level/sanity |
| `/brlevel [id] [lvl]` | Send a player to a specific level |
| `/brout [id]` | Pull a player back to the surface |
| `/brbring [id]` | Bring a player to your level |
| `/brcleanup` | Reconcile / clear stuck Backrooms state |

> Grant access in `server.cfg`, e.g. `add_ace group.admin mbt_backrooms.admin allow`.

---

## FAQ

**Q: Do I need a framework?**
No. It's standalone. ESX / ox_lib / QBCore / QBox are auto-detected for notifications only.

**Q: How do players get in?**
Three ways: walking into a hidden **no-clip zone**, clipping **under the map**, or using a configured **Enter** interaction point.

**Q: Can I make the entry less intense?**
Yes — set `MBT.Transition = 'fade'` (or `'cut'`), lower `MBT.Atmosphere.Intensity`, or enable `ReduceMotion` / `ReduceFlashing`.

**Q: How do I add a level / move spawn points?**
Add coords to `MBT.Coords` and matching Enter/Exit points to `MBT.BackRooms`. Use `/brhere` (debug) to grab coords in-game.

**Q: The entity never appears.**
Glimpses are gated behind low sanity (`MinSanityGate`), a cooldown, and a roll (`Chance`). Lower your sanity (stay inside, alone) or relax those values for testing.

**Q: What are the tapes for?**
They're the reward loop. Find tapes/logs inside, carry them out to "recover" them, then review your collection on the **archive terminal** on the surface — and (with Research Mode) unlock diegetic field notes as you recover more.

**Q: How do I place the archive TV?**
Run `/brsetarchive` (admin or `MBT.Debug`): a popup lets you position the prop and tune the camera + on-screen rect live, then **Save** — it persists server-side. The TV prop must have a screen render target (e.g. `prop_tv_flat_02` → `tvscreen`, or the x17 flat → `tv_flat_01`).

**Q: The exits are invisible — is that a bug?**
No — curated exits are *meant* to be unmarked. A screen/audio tell grows as you approach; linger inside to be pulled through. Enable `MBT.Debug` for markers + `/brexits` while placing them.

---

## Credits

Developed by **Malibu Tech Team**. Originally created by **DarkSideofTheCode** — this 2.0 carries his work forward. 🕯️

- **Maps** — by **Iakko** (MalibuTech). *Want to contribute a level? Mappers are welcome and get credited here.*
- **Entity peds** — bundled from gta5-mods, credit-only license:
  - [Smiler — Backrooms Add-On Ped](https://www.gta5-mods.com/player/smiler-backrooms-add-on-ped)
  - [Skin Stealer — Backrooms](https://www.gta5-mods.com/player/skin-stealer-backrooms)
- **Audio** — royalty-free / CC0 sources (see `web/public/sounds/LICENSES.md`).
- **The FiveM & Backrooms communities** — for the aesthetic and endless inspiration.

---

## License

Free for noncommercial use — personal use, hobby servers, and community servers. Redistribution for profit or inclusion in paid products is prohibited without written permission from Malibu Tech Team. Bundled third-party assets (entity peds, audio) remain under their original licenses — keep the credits above intact.

##### Copyright © 2022–2026 Malibú Tech. All rights reserved.
