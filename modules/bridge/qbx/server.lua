if GetResourceState('qbx_core') ~= 'started' then return end

Bridge = Bridge or {}
Bridge.Framework = 'qbx'

Utils.MbtDebugger('bridge: qbx loaded')
