-- qbx_core takes precedence: if it's running, let the qbx bridge handle it.
if GetResourceState('qb-core') ~= 'started' or GetResourceState('qbx_core') == 'started' then return end

Bridge = Bridge or {}
Bridge.Framework = 'qb'

Utils.MbtDebugger('bridge: qb loaded')
