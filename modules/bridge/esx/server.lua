if GetResourceState('es_extended') ~= 'started' then return end

Bridge = Bridge or {}
Bridge.Framework = 'esx'

Utils.MbtDebugger('bridge: esx loaded')
