if GetResourceState('ox_core') ~= 'started' then return end

Bridge = Bridge or {}
Bridge.Framework = 'ox'

Utils.MbtDebugger('bridge: ox loaded')
