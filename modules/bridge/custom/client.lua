-- Standalone notification handler (native GTA feed above the minimap).
-- Only fired by the custom server bridge; with a framework active the server
-- routes notifications through that framework's own client event instead.
RegisterNetEvent('mbt_backrooms:notify', function(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end)
