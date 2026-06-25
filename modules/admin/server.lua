-- Admin tooling (F9). Operator commands gated by the ACE permission
-- `mbt_backrooms.admin`. Grant in server.cfg, e.g.:
--   add_ace group.admin mbt_backrooms.admin allow
-- (Server console is always allowed.) These are distinct from the MBT.Debug
-- client test commands (/brfall, /brglimpse, ...), which are dev-only.

local PERM = 'mbt_backrooms.admin'

local function allowed(src)
    return src == 0 or IsPlayerAceAllowed(src, PERM)
end

local function notify(src, msg)
    if src == 0 then
        print('[mbt_backrooms] ' .. msg)
    elseif Utils.Notify then
        Utils.Notify(src, msg)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { 'mbt_backrooms', msg } })
    end
end

-- /brstatus [serverId] — show a player's backrooms state.
RegisterCommand('brstatus', function(src, args)
    if not allowed(src) then return end
    local id = tonumber(args[1]) or src
    if id == 0 then notify(src, 'From console specify an id: /brstatus <serverId>') return end
    local st = Core.GetState(id)
    notify(src, ('[%s] inLevel=%s sanity=%s locked=%s')
        :format(id, tostring(st.inLevel), tostring(st.sanity or 100), tostring(st.locked)))
end, false)

-- /brlevel <n> — send yourself into level n.
RegisterCommand('brlevel', function(src, args)
    if not allowed(src) then return end
    local n = tonumber(args[1])
    if not n or not Core.SendToLevel(src, n) then
        notify(src, 'Usage: /brlevel <1-' .. #MBT.Coords .. '>')
    end
end, false)

-- /brout — force yourself back to the surface.
RegisterCommand('brout', function(src)
    if not allowed(src) then return end
    Core.SendToSurface(src)
end, false)

-- /brbring <serverId> — bring a player into your current level (or surface).
RegisterCommand('brbring', function(src, args)
    if not allowed(src) then return end
    local id = tonumber(args[1])
    if not id then notify(src, 'Usage: /brbring <serverId>') return end
    local st = Core.GetState(src)
    if st.inLevel then Core.SendToLevel(id, st.inLevel) else Core.SendToSurface(id) end
    notify(src, ('Brought %s %s'):format(id, st.inLevel and 'into your level' or 'to the surface'))
end, false)

-- /brcleanup [serverId|all] — clear stuck state (unstick + pull out).
RegisterCommand('brcleanup', function(src, args)
    if not allowed(src) then return end
    local target = args[1]
    if not target or target == 'all' then
        for _, id in ipairs(GetPlayers()) do Core.ClearState(tonumber(id)) end
        notify(src, 'Cleared backrooms state for everyone.')
    else
        local id = tonumber(target)
        if id then Core.ClearState(id); notify(src, 'Cleared state for ' .. id) end
    end
end, false)
