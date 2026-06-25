Utils = Utils or {}

-- Canonical logging via MBTLog (modules/utils/logger.lua, shared). Kept as a
-- Utils.MbtDebugger alias for back-compat; new code can call MBTLog.Debug/.Warn
-- /.Error directly.
Utils.MbtDebugger = MBTLog.Debug

-- Per-player rate limiter. Returns true if the (src, key) action is allowed now.
local lastAction = {}
function Utils.RateLimit(src, key, intervalMs)
    local now = GetGameTimer()
    local actions = lastAction[src]
    if not actions then
        actions = {}
        lastAction[src] = actions
    end
    local last = actions[key]
    if last and (now - last) < intervalMs then
        return false
    end
    actions[key] = now
    return true
end

function Utils.ClearRateLimit(src)
    lastAction[src] = nil
end

-- Send a notification to a player. Framework-agnostic (NOT a bridge concern): the
-- client renders it via the config's MBT.Notification(data). Accepts a string or a
-- { title?, description, type?, duration? } table.
function Utils.Notify(src, data)
    TriggerClientEvent('mbt_backrooms:notify', src, type(data) == 'table' and data or { description = data })
end
