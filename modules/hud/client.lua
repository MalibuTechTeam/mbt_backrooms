-- Minimal in-level HUD (torch-key hint + optional stylized sanity signal). Pure
-- NUI: this module only forwards the small amount of state the HUD needs — the
-- look lives in web/. Sanity itself is still diegetic (the vignette/shake); the
-- signal indicator is opt-in via MBT.HUD.ShowSanity.

local hud = MBT.HUD
if not (hud and hud.Enabled) then return end

local STATE_INLEVEL = 'mbt_backrooms:inLevel'
local STATE_TORCH   = 'mbt_backrooms:torch'

local function pushConfig()
    SendNUIMessage({ action = 'hud:config', data = {
        inLevel    = LocalPlayer.state[STATE_INLEVEL] and true or false,
        torch      = LocalPlayer.state[STATE_TORCH] and true or false,
        torchHint  = hud.TorchHint ~= false,
        showSanity = hud.ShowSanity == true,
        torchKey   = (MBT.Light and MBT.Light.Key) or 'F',
        torchLabel = (MBT.Locale and MBT.Locale.hud_torch) or 'torch',
    } })
end

AddStateBagChangeHandler(STATE_INLEVEL, '', function(bag, _, _value)
    local ply = GetPlayerFromStateBagName(bag)
    if ply == 0 or ply ~= PlayerId() then return end
    pushConfig() -- toggles HUD visibility + refreshes torch state
end)

AddStateBagChangeHandler(STATE_TORCH, '', function(bag, _, value)
    local ply = GetPlayerFromStateBagName(bag)
    if ply == 0 or ply ~= PlayerId() then return end
    SendNUIMessage({ action = 'hud:torch', data = { on = value and true or false } })
end)

-- Initial push once the NUI is up.
CreateThread(function()
    Wait(1500)
    pushConfig()
end)
