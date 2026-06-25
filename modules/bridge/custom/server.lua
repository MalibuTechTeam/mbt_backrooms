-- Standalone bridge (no framework). Loads only when none of the supported
-- frameworks are started — it's the default fallback.
if GetResourceState('es_extended') == 'started'
    or GetResourceState('ox_core') == 'started'
    or GetResourceState('qb-core') == 'started'
    or GetResourceState('qbx_core') == 'started' then
    return
end

Bridge = Bridge or {}
Bridge.Framework = 'custom'

Utils.MbtDebugger('bridge: standalone (custom) loaded')
