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

**mbt_backrooms** turns the classic "fall out of reality" map into a full liminal-horror experience. Glitch into the Backrooms through hidden no-clip spots or a bad clip under the map, then survive a found-footage VHS world that erodes your **sanity**, watches you from the dark with a **Weeping-Angel entity**, and rarely lets you back out. Server-authoritative, multi-framework, and standalone-first — built with a modern React + TypeScript NUI overlay tuned for FiveM's CEF.

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
- **Weighted exits** — exit points roll `MBT.ExitRules`: escape to the surface or get dumped back into another Backroom. Faithful to the lore — getting out is never guaranteed (default ~70% trapped). Per-exit overrides supported.

### Sanity
- **Server-authoritative sanity (0–100)** — decays while inside (faster when you're **alone** in your level), regenerates on the surface.
- **Diegetic feedback** — a closing-in vignette ramps at low sanity; camera shake + heavier distortion kick in when critical. No HUD meter — the dread is sensory.
- **Entity sightings** cost sanity instantly.

### The Entity (scripted glimpse / stalker)
- **Weeping-Angel mechanic** — in darkness / low sanity an entity appears at a distance, **freezes while you look at it**, and **creeps toward you while unobserved**. Reaching you = sanity hit + vanish.
- **Polished presence** — camera-raycast placement (never spawns in your face), a soft alpha fade-out, and a gaze-deferred despawn so it never pops out while you're staring at it.
- **Model-agnostic** — ships with two bundled Backrooms peds (Smiler + Skin Stealer) and falls back gracefully; swap in your own via `MBT.Entities.Models`.
- Optional **sound cue** on spawn / first look.

### Architecture
- **Server-authoritative teleport** — all entry/exit/state lives on the server via OneSync state bags (`inLevel` / `entryTime` / `exitLocked`), token-matched and rate-limited. Clients can't teleport themselves.
- **Multi-framework bridge** — auto-detects **ESX**, **ox_lib**, **QBCore**, **QBox**, or **standalone** for notifications (and an inventory abstraction, dormant until 2.1).
- **Admin tooling** — ACE-gated commands to inspect and manage players in the Backrooms.
- **MBT modular pattern** — `core/`, `modules/{atmosphere,sanity,entities,interaction,bridge,inventory,admin,utils}`, `locales/`, `web/`.

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

### Notifications

`modules/bridge/` auto-detects your framework. Notifications route through **ESX**, **ox_lib**, **QBCore**, **QBox**, or a native fallback with no extra setup.

---

## Commands

### Debug (require `MBT.Debug = true`)

| Command | Action |
|---|---|
| `/brfall` | Simulate a fall-through entry |
| `/brenter` | Force-enter a random backroom |
| `/brexit` | Force an exit roll |
| `/brhere` | Print your current coords (for placing points/zones) |
| `/brtc` | Cycle timecycle variants to preview them |

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
