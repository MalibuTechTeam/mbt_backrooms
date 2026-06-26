-- Archive (Section 10): a TV terminal that plays your recovered tapes/logs as a DUI
-- on its screen via a RENDER TARGET (the mbt_shooting pattern). The transform is
-- placed in-game (/brsetarchive popup) and synced from the server (KVP). Walk up ->
-- [E] frames the screen and loads your archive onto it; [E]/Backspace exits.

local cfg = MBT.Archive
local aCfg = MBT.Artifacts

-- id -> { type, text, category } from the artifact pool (text lives client-side).
local byId = {}
if aCfg and aCfg.Pool then
    for _, level in pairs(aCfg.Pool) do
        for _, a in ipairs(level) do
            if a.id then byId[a.id] = { type = a.type or 'log', text = a.text or '', category = a.category } end
        end
    end
end

local RT = cfg.RenderTarget or 'tvscreen'

local prop, decorProp, transform, camCfg, wcam, screenCfg, wscreen
local screenActive, viewing = false, false
local nearTerminal, shownPrompt, cam = false, false, nil
local placing, previewCam = false, false

local function cloneCam(c)
    c = c or {}
    return { dist = c.dist or 1.4, side = c.side or -1.0, aimZ = c.aimZ or 1.0, height = c.height or 1.0, fov = c.fov or 34.0 }
end

local function cloneScreen(s)
    s = s or {}
    return { offX = s.offX or 0.0, offY = s.offY or 0.04, offZ = s.offZ or 0.0, w = s.w or 1.05, h = s.h or 0.6 }
end

-- Full archive payload (every tape + note) — used by the placement preview + demo.
local function buildAllData()
    local tapes, confidence = {}, {}
    for id, e in pairs(byId) do
        tapes[#tapes + 1] = { id = id, type = e.type, text = e.text }
        if e.category then confidence[e.category] = (confidence[e.category] or 0) + 1 end
    end
    local notes, rm = {}, cfg.ResearchMode
    if rm and rm.Enabled and rm.Hints then
        for cat, hints in pairs(rm.Hints) do
            for _, h in ipairs(hints) do notes[#notes + 1] = { category = cat, text = h.text } end
        end
    end
    return { tapes = tapes, notes = notes, confidence = confidence, research = (rm and rm.Enabled) or false }
end

local function forwardVec(h)
    local rad = math.rad(h or (transform and transform.h) or 0.0)
    return -math.sin(rad), math.cos(rad)
end

-- Optional decorative prop (cassette/VCR) next to the TV, to sell the "tape" idea.
local function spawnDecor()
    if decorProp and DoesEntityExist(decorProp) then DeleteEntity(decorProp) end
    decorProp = nil
    local d = cfg.Decor
    if not (d and d.model and transform) then return end
    local hash = GetHashKey(d.model)
    RequestModel(hash)
    local t = 2000
    while not HasModelLoaded(hash) and t > 0 do Wait(50); t = t - 50 end
    if not HasModelLoaded(hash) then return end
    local rad = math.rad(transform.h or 0.0)
    local cos, sin = math.cos(rad), math.sin(rad)
    local ox, oy = d.offX or 0.0, d.offY or 0.0
    decorProp = CreateObject(hash, transform.x + (ox * cos - oy * sin),
        transform.y + (ox * sin + oy * cos), transform.z + (d.offZ or 0.0), false, false, false)
    SetEntityHeading(decorProp, (transform.h or 0.0) + (d.heading or 0.0))
    FreezeEntityPosition(decorProp, true)
    SetModelAsNoLongerNeeded(hash)
end

local function spawnProp()
    if not transform then return end
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
    local hash = GetHashKey(cfg.Prop)
    RequestModel(hash)
    local t = 3000
    while not HasModelLoaded(hash) and t > 0 do Wait(50); t = t - 50 end
    if not HasModelLoaded(hash) then
        MBTLog.Warn('archive prop failed to load — swap MBT.Archive.Prop:', cfg.Prop)
        return
    end
    prop = CreateObject(hash, transform.x, transform.y, transform.z, false, false, false)
    SetEntityHeading(prop, transform.h or 0.0)
    FreezeEntityPosition(prop, true) -- exact placement (Z controlled in the placer)
    SetModelAsNoLongerNeeded(hash)
    spawnDecor()
end

local function movePreview()
    if not transform then return end
    if not (prop and DoesEntityExist(prop)) then spawnProp(); return end
    SetEntityCoordsNoOffset(prop, transform.x, transform.y, transform.z, false, false, false)
    SetEntityHeading(prop, transform.h or 0.0)
    spawnDecor()
end

-- Keep the prop's screen a flat BLACK panel via its render target (the readable
-- archive itself is a crisp NUI overlay projected on top — no blurry DUI).
local function ensureScreen()
    if screenActive or not (prop and DoesEntityExist(prop)) then return end
    if not IsNamedRendertargetRegistered(RT) then RegisterNamedRendertarget(RT, false) end
    if not IsNamedRendertargetLinked(GetHashKey(cfg.Prop)) then LinkNamedRendertarget(GetHashKey(cfg.Prop)) end
    screenActive = true
    if MBT.Debug then
        CreateThread(function()
            Wait(400)
            local rid = GetNamedRendertargetRenderId(RT)
            local linked = IsNamedRendertargetLinked(GetHashKey(cfg.Prop))
            MBTLog.Debug(('archive RT "%s" renderId=%d linkedToProp=%s %s'):format(RT, rid, tostring(linked),
                (not linked) and ('(NOT linked: ' .. tostring(cfg.Prop) .. ' has no RT named ' .. RT .. ' — swap Prop/RenderTarget)') or '(OK)'))
        end)
    end
    CreateThread(function()
        while screenActive do
            local rtId = GetNamedRendertargetRenderId(RT)
            if rtId ~= 0 then
                SetTextRenderId(rtId)
                Set_2dLayer(4)
                DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 255) -- flat black screen (the UI is a NUI overlay)
                SetTextRenderId(GetDefaultScriptRendertargetRenderId())
            end
            Wait(0)
        end
    end)
end

local function destroyScreen()
    if not screenActive then return end
    screenActive = false
    if IsNamedRendertargetRegistered(RT) then ReleaseNamedRendertarget(RT) end
end

-- Frame (or re-frame) the TV. Updates the existing cam in place so live tuning is
-- smooth. co = camera override (the placer's working copy); else persisted/config.
local function applyCam(co)
    if not transform then return end
    co = co or camCfg or cfg.Camera or {}
    local fx, fy = forwardVec()
    local d = (co.dist or 1.4) * (co.side or -1.0)
    local tx, ty, tz = transform.x, transform.y, transform.z + (co.aimZ or 1.0)
    local cx, cy, cz = tx + fx * d, ty + fy * d, transform.z + (co.height or 1.0)
    if cam then
        SetCamCoord(cam, cx, cy, cz)
        SetCamFov(cam, co.fov or 34.0)
        PointCamAtCoord(cam, tx, ty, tz)
    else
        cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', cx, cy, cz, 0.0, 0.0, 0.0, co.fov or 34.0, false, 0)
        PointCamAtCoord(cam, tx, ty, tz)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 500, true, true)
        -- Hide the ped LOCALLY only (per-frame) so it doesn't block the screen —
        -- networked SetEntityVisible would make us vanish for everyone else.
        CreateThread(function()
            while cam do
                SetEntityLocallyInvisible(PlayerPedId())
                Wait(0)
            end
        end)
    end
end

local function closeCam()
    RenderScriptCams(false, true, 400, true, true)
    if cam then DestroyCam(cam, false); cam = nil end -- stops the local-hide loop; ped reappears next frame
end

-- Re-frame only while the placement camera preview is toggled on.
local function reframe()
    if previewCam then applyCam(wcam) end
end

local function groundSnap()
    if not transform then return end
    local ok, gz = GetGroundZFor_3dCoord(transform.x, transform.y, transform.z + 2.0, false)
    if ok then transform.z = gz end
end

local function hidePrompt()
    if shownPrompt then
        shownPrompt = false
        SendNUIMessage({ action = 'prompt:set', data = { visible = false } })
    end
end

-- Project the TV screen's 4 corners to screen-space and return the bounding rect
-- (x,y,w,h in 0..1) so the NUI overlay can sit exactly on the screen in the framed
-- view. Auto-aligns regardless of the camera tuning.
local function projectScreenRect()
    if not transform then return nil end
    local s = (placing and wscreen) or screenCfg or cfg.Screen or {}
    local rad = math.rad(transform.h or 0.0)
    local fx, fy = -math.sin(rad), math.cos(rad) -- forward
    local rx, ry = math.cos(rad), math.sin(rad)  -- right
    local cx = transform.x + rx * (s.offX or 0.0) + fx * (s.offY or 0.0)
    local cy = transform.y + ry * (s.offX or 0.0) + fy * (s.offY or 0.0)
    local cz = transform.z + (s.offZ or 0.0)
    local hw, hh = (s.w or 1.0) * 0.5, (s.h or 0.6) * 0.5
    local corners = {
        { cx - rx * hw, cy - ry * hw, cz + hh }, { cx + rx * hw, cy + ry * hw, cz + hh },
        { cx - rx * hw, cy - ry * hw, cz - hh }, { cx + rx * hw, cy + ry * hw, cz - hh },
    }
    local minX, minY, maxX, maxY, any = 2.0, 2.0, -1.0, -1.0, false
    for _, c in ipairs(corners) do
        local on, sxp, syp = World3dToScreen2d(c[1], c[2], c[3])
        if on then
            any = true
            if sxp < minX then minX = sxp end
            if syp < minY then minY = syp end
            if sxp > maxX then maxX = sxp end
            if syp > maxY then maxY = syp end
        end
    end
    if not any then return nil end
    return { x = minX, y = minY, w = maxX - minX, h = maxY - minY }
end

local closing = false
local function closeView()
    if not viewing or closing then return end
    closing = true
    SendNUIMessage({ action = 'archive:hide' }) -- CRT power-off plays on the NUI overlay
    SetTimeout(400, function()
        viewing, closing = false, false
        closeCam()
        FreezeEntityPosition(PlayerPedId(), false)
    end)
end

-- [E]: frame the TV, then power on a CRISP NUI overlay projected onto the screen.
local function viewArchive(data)
    if viewing or not transform then return end
    viewing = true
    hidePrompt()
    ensureScreen() -- keep the screen flat black behind the overlay
    FreezeEntityPosition(PlayerPedId(), true)
    applyCam()

    -- Power on once the camera has settled on the TV (reads as "the screen turns on").
    SetTimeout(520, function()
        if not viewing then return end
        SendNUIMessage({ action = 'archive:show', data = { archive = data, rect = projectScreenRect() } })
    end)

    -- Keep the overlay aligned to the screen (cheap; the cam is mostly static).
    CreateThread(function()
        while viewing do
            local r = projectScreenRect()
            if r then SendNUIMessage({ action = 'archive:rect', data = r }) end
            Wait(120)
        end
    end)

    local openedAt = GetGameTimer()
    CreateThread(function()
        while viewing do
            DisableControlAction(0, 38, true)  -- E
            DisableControlAction(0, 177, true) -- Backspace
            if GetGameTimer() - openedAt > 350
                and (IsDisabledControlJustReleased(0, 38) or IsDisabledControlJustReleased(0, 177)) then
                closeView()
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('mbt_backrooms:archiveTransform', function(t)
    if type(t) ~= 'table' then return end
    transform = t
    camCfg = (type(t.cam) == 'table') and t.cam or nil
    screenCfg = (type(t.screen) == 'table') and t.screen or nil
    spawnProp()
end)

RegisterNetEvent('mbt_backrooms:archiveRemoved', function()
    transform = nil
    destroyScreen()
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    if decorProp and DoesEntityExist(decorProp) then DeleteEntity(decorProp) end
    prop, decorProp = nil, nil
end)

-- Server reply with the recovered ids -> build the archive payload + show it.
RegisterNetEvent('mbt_backrooms:archiveData', function(ids)
    local tapes, confidence = {}, {}
    if type(ids) == 'table' then
        for _, id in ipairs(ids) do
            local e = byId[id]
            if e then
                tapes[#tapes + 1] = { id = id, type = e.type, text = e.text }
                if e.category then confidence[e.category] = (confidence[e.category] or 0) + 1 end
            end
        end
    end
    local notes = {}
    local rm = cfg.ResearchMode
    local research = (rm and rm.Enabled) or false
    if research and rm.Hints then
        for cat, hints in pairs(rm.Hints) do
            local c = confidence[cat] or 0
            for _, h in ipairs(hints) do
                if c >= (h.at or 1) then notes[#notes + 1] = { category = cat, text = h.text } end
            end
        end
    end
    viewArchive({ action = 'archive:data', tapes = tapes, notes = notes, confidence = confidence, research = research })
end)

RegisterCommand('mbt_archive', function()
    if cfg.Enabled and nearTerminal and not viewing and not placing then
        TriggerServerEvent('mbt_backrooms:openArchive')
    end
end, false)
RegisterKeyMapping('mbt_archive',
    (MBT.Locale and MBT.Locale.keymapping_archive) or 'Backrooms: review archive',
    'keyboard', MBT.General.InteractKey)

-------------------------------------------------------------------------------
-- Placement popup (NUI, like mbt_elevator): nudge XYZ + rotate, place-at-me,
-- remove, save. Edits the live prop as a preview; Save persists, Close reverts.
-------------------------------------------------------------------------------
local function closePlacer(revert)
    if not placing then return end
    placing, previewCam = false, false
    closeCam()
    SendNUIMessage({ action = 'archive:hide' }) -- hide the placement preview overlay
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'archivePlacer:close' })
    if revert then TriggerServerEvent('mbt_backrooms:requestArchiveTransform') end
end

RegisterCommand('brsetarchive', function()
    if placing or viewing then return end
    placing = true
    previewCam = false
    if not transform then
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        local fx, fy = forwardVec(GetEntityHeading(ped))
        transform = { x = c.x + fx * 1.5, y = c.y + fy * 1.5, z = c.z, h = GetEntityHeading(ped) }
        groundSnap() -- sit on the floor by default, not floating
        movePreview()
    end
    wcam = cloneCam(camCfg or cfg.Camera)
    wscreen = cloneScreen(screenCfg or cfg.Screen)
    -- No camera on open: place from the normal view (see the ground), then toggle
    -- the camera preview to tune framing + screen rect.
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'archivePlacer:open' })
end, false)

RegisterNUICallback('archiveNudge', function(d, cb)
    if transform then
        transform.x = transform.x + (tonumber(d.dx) or 0.0)
        transform.y = transform.y + (tonumber(d.dy) or 0.0)
        transform.z = transform.z + (tonumber(d.dz) or 0.0)
        transform.h = ((transform.h or 0.0) + (tonumber(d.dh) or 0.0)) % 360.0
        movePreview()
        reframe()
    end
    cb('ok')
end)

RegisterNUICallback('archivePlaceHere', function(_, cb)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    transform = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) }
    movePreview()
    reframe()
    cb('ok')
end)

RegisterNUICallback('archiveDropGround', function(_, cb)
    groundSnap()
    movePreview()
    reframe()
    cb('ok')
end)

-- Toggle the camera framing preview (off by default so you can place from the
-- normal view). When on, the ped is hidden locally and the cam frames the TV.
RegisterNUICallback('archiveCamPreview', function(_, cb)
    previewCam = not previewCam
    if previewCam then
        applyCam(wcam)
        -- show the archive overlay (demo content) so you can align the screen rect
        SendNUIMessage({ action = 'archive:show', data = { archive = buildAllData(), rect = projectScreenRect() } })
        CreateThread(function()
            while placing and previewCam do
                local r = projectScreenRect()
                if r then SendNUIMessage({ action = 'archive:rect', data = r }) end
                Wait(80)
            end
        end)
    else
        SendNUIMessage({ action = 'archive:hide' })
        closeCam()
    end
    SendNUIMessage({ action = 'archivePlacer:cam', data = { on = previewCam } })
    cb('ok')
end)

-- Live camera tuning: dist / height / aim / fov nudges + side flip.
RegisterNUICallback('archiveCamNudge', function(d, cb)
    if wcam then
        wcam.dist   = math.max(0.3, (wcam.dist or 1.4) + (tonumber(d.dDist) or 0.0))
        wcam.height = (wcam.height or 1.0) + (tonumber(d.dHeight) or 0.0)
        wcam.aimZ   = (wcam.aimZ or 1.0) + (tonumber(d.dAim) or 0.0)
        wcam.fov    = math.max(10.0, math.min(90.0, (wcam.fov or 34.0) + (tonumber(d.dFov) or 0.0)))
        if d.flipSide then wcam.side = -(wcam.side or -1.0) end
        reframe()
    end
    cb('ok')
end)

-- Live screen-rect tuning: move (offX/offZ) + resize (w/h) the NUI box on the TV.
RegisterNUICallback('archiveScreenNudge', function(d, cb)
    if wscreen then
        wscreen.offX = (wscreen.offX or 0.0) + (tonumber(d.dX) or 0.0)
        wscreen.offZ = (wscreen.offZ or 0.0) + (tonumber(d.dZ) or 0.0)
        wscreen.w = math.max(0.2, (wscreen.w or 1.05) + (tonumber(d.dW) or 0.0))
        wscreen.h = math.max(0.15, (wscreen.h or 0.6) + (tonumber(d.dH) or 0.0))
        if previewCam then
            local r = projectScreenRect()
            if r then SendNUIMessage({ action = 'archive:rect', data = r }) end
        end
    end
    cb('ok')
end)

RegisterNUICallback('archiveSave', function(_, cb)
    if transform then
        TriggerServerEvent('mbt_backrooms:placeArchive',
            { x = transform.x, y = transform.y, z = transform.z, h = transform.h, cam = wcam, screen = wscreen })
    end
    closePlacer(false)
    cb('ok')
end)

RegisterNUICallback('archiveRemove', function(_, cb)
    TriggerServerEvent('mbt_backrooms:removeArchive')
    closePlacer(false)
    cb('ok')
end)

RegisterNUICallback('archivePlacerClose', function(_, cb)
    closePlacer(true)
    cb('ok')
end)

-- Debug: power on the TV with EVERY tape/log + all field notes, to preview the
-- populated archive in-game (no need to actually recover them). Stand near the TV.
if MBT.Debug then
    RegisterCommand('brarchivedemo', function()
        local tapes, confidence = {}, {}
        for id, e in pairs(byId) do
            tapes[#tapes + 1] = { id = id, type = e.type, text = e.text }
            if e.category then confidence[e.category] = (confidence[e.category] or 0) + 1 end
        end
        local notes, rm = {}, cfg.ResearchMode
        if rm and rm.Enabled and rm.Hints then
            for cat, hints in pairs(rm.Hints) do
                for _, h in ipairs(hints) do notes[#notes + 1] = { category = cat, text = h.text } end
            end
        end
        viewArchive({ action = 'archive:data', tapes = tapes, notes = notes, confidence = confidence,
            research = (rm and rm.Enabled) or false })
    end, false)
end

-------------------------------------------------------------------------------
CreateThread(function()
    if not (cfg and cfg.Enabled) then return end
    Wait(1000)
    TriggerServerEvent('mbt_backrooms:requestArchiveTransform')
    while true do
        local sleep = 1000
        if transform and prop then
            local pc = GetEntityCoords(PlayerPedId())
            local dist = #(pc - vector3(transform.x, transform.y, transform.z))
            if dist <= (cfg.RenderRange or 25.0) then ensureScreen() else destroyScreen() end

            nearTerminal = dist <= (cfg.PromptRange or 2.0)
            if nearTerminal and not viewing and not placing then
                sleep = 250
                if not shownPrompt then
                    shownPrompt = true
                    SendNUIMessage({ action = 'prompt:set', data = {
                        visible = true, key = MBT.General.InteractKey,
                        label = (MBT.Locale and MBT.Locale.prompt_archive) or 'review',
                        type = 'archive',
                        reduceMotion = (MBT.Atmosphere and MBT.Atmosphere.ReduceMotion) or false,
                    } })
                end
            elseif shownPrompt then
                hidePrompt()
            end
        elseif screenActive then
            destroyScreen()
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    destroyScreen()
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false); cam = nil
        FreezeEntityPosition(PlayerPedId(), false)
    end
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    if decorProp and DoesEntityExist(decorProp) then DeleteEntity(decorProp) end
    if viewing then SendNUIMessage({ action = 'archive:hide' }) end
end)
