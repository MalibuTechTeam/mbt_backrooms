Utils = Utils or {}

-- Gated debug print. Enabled via MBT.Debug in config.lua (shared).
function Utils.MbtDebugger(...)
    if not MBT.Debug then return end
    local args = { ... }
    local out = "[" .. GetCurrentResourceName() .. "] | "
    for _, v in ipairs(args) do
        out = out .. tostring(v) .. "\t"
    end
    print(out)
end

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
