-- Minimal in-level HUD (torch-key hint + optional stylized sanity signal). Pure
-- NUI: this module only forwards the small amount of state the HUD needs — the look
-- lives in web/. Sanity itself stays diegetic (vignette/shake); the signal indicator
-- is opt-in via MBT.HUD.ShowSanity. Driven by a poll on the authoritative state
-- (same pattern as the other modules — reliable regardless of state-bag handlers).

local hud = MBT.HUD
if not (hud and hud.Enabled) then return end

local STATE_INLEVEL = 'mbt_backrooms:inLevel'
local STATE_TORCH   = 'mbt_backrooms:torch'

local function push(inLevel, torch)
    SendNUIMessage({ action = 'hud:config', data = {
        inLevel    = inLevel and true or false,
        torch      = torch and true or false,
        torchHint  = hud.TorchHint ~= false,
        showSanity = hud.ShowSanity == true,
        torchKey   = (MBT.Light and MBT.Light.Key) or 'F',
        torchLabel = (MBT.Locale and MBT.Locale.hud_torch) or 'torch',
    } })
end

CreateThread(function()
    local lastIn, lastTorch
    while true do
        local inLevel = LocalPlayer.state[STATE_INLEVEL] and true or false
        local torch   = LocalPlayer.state[STATE_TORCH] and true or false
        if inLevel ~= lastIn or torch ~= lastTorch then
            lastIn, lastTorch = inLevel, torch
            push(inLevel, torch)
        end
        Wait(400)
    end
end)
