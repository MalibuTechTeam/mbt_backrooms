fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name 'mbt_backrooms'
author 'Malibù Tech Team'
version '1.0.0'
description 'mbt_backrooms'

this_is_a_map 'yes'

files {
  'interiorproxies.meta'
}

shared_scripts {
  'locales/*.lua',
  'modules/locales.lua',
  'config.lua'
}

client_scripts {
  'modules/utils/client.lua',
  'core/client.lua'
}

escrow_ignore { 'config.lua', 'locales/*.lua' }
