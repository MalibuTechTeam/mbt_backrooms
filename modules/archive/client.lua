-- Archive (Section 10): a surface CRT terminal to review recovered tapes/logs.
-- Spawns the terminal prop(s), shows an [E] prompt on proximity, and on use opens
-- a NUI panel listing everything recovered (ids -> text from the Artifacts config).

local cfg = MBT.Archive
local aCfg = MBT.Artifacts

-- id -> { type, text } lookup, built from the artifact pool (the text lives
-- client-side in config, so the server only has to send the recovered ids).
local byId = {}
if aCfg and aCfg.Pool then
    for _, level in pairs(aCfg.Pool) do
        for _, a in ipairs(level) do
            if a.id then byId[a.id] = { type = a.type or 'log', text = a.text or '' } end
        end
    end
end

local terminals = {} -- spawned prop handles
local nearTerminal, shownPrompt, open = false, false, false

local function spawnTerminals()
    if not cfg.PropModel then return end
    local hash = GetHashKey(cfg.PropModel)
    RequestModel(hash)
    local t = 3000
    while not HasModelLoaded(hash) and t > 0 do Wait(50); t = t - 50 end
    if not HasModelLoaded(hash) then
        MBTLog.Warn('archive terminal prop failed to load — swap MBT.Archive.PropModel:', cfg.PropModel)
        return
    end
    for _, term in ipairs(cfg.Terminals or {}) do
        local c = term.coords
        local obj = CreateObject(hash, c.x, c.y, c.z, false, false, false)
        SetEntityHeading(obj, term.heading or 0.0)
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        terminals[#terminals + 1] = obj
    end
    SetModelAsNoLongerNeeded(hash)
end

local function hidePrompt()
    if shownPrompt then
        shownPrompt = false
        SendNUIMessage({ action = 'prompt:set', data = { visible = false } })
    end
end

local function closeArchive()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'archive:close' })
end

-- Server replies with the recovered ids -> map to text and open the NUI panel.
RegisterNetEvent('mbt_backrooms:archiveData', function(ids)
    local tapes = {}
    if type(ids) == 'table' then
        for _, id in ipairs(ids) do
            local e = byId[id]
            if e then tapes[#tapes + 1] = { id = id, type = e.type, text = e.text } end
        end
    end
    hidePrompt()
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'archive:open', data = { tapes = tapes } })
end)

RegisterNUICallback('archiveClose', function(_, cb)
    closeArchive()
    cb('ok')
end)

RegisterCommand('mbt_archive', function()
    if cfg.Enabled and nearTerminal and not open then
        TriggerServerEvent('mbt_backrooms:openArchive')
    end
end, false)
RegisterKeyMapping('mbt_archive',
    (MBT.Locale and MBT.Locale.keymapping_archive) or 'Backrooms: review archive',
    'keyboard', MBT.General.InteractKey)

CreateThread(function()
    if not (cfg and cfg.Enabled) then return end
    spawnTerminals()
    while true do
        local sleep = 700
        local pc = GetEntityCoords(PlayerPedId())
        nearTerminal = false
        for _, term in ipairs(cfg.Terminals or {}) do
            if #(pc - term.coords) <= (cfg.PromptRange or 1.8) then nearTerminal = true break end
        end

        if nearTerminal and not open then
            sleep = 300
            if not shownPrompt then
                shownPrompt = true
                SendNUIMessage({
                    action = 'prompt:set',
                    data = {
                        visible = true,
                        key = MBT.General.InteractKey,
                        label = (MBT.Locale and MBT.Locale.prompt_archive) or 'review',
                        type = 'archive',
                        reduceMotion = (MBT.Atmosphere and MBT.Atmosphere.ReduceMotion) or false,
                    },
                })
            end
        elseif shownPrompt then
            hidePrompt()
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, obj in ipairs(terminals) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
    if open then SetNuiFocus(false, false) end
end)
