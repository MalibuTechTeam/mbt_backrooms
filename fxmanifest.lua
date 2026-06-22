fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name 'mbt_backrooms'
author 'Malibù Tech Team'
version '1.0.0'
description 'mbt_backrooms'

this_is_a_map 'yes'

dependencies {
  '/onesync'
}

ui_page 'web/dist/index.html'

files {
  'interiorproxies.meta',
  'web/dist/index.html',
  'web/dist/assets/**'
}

shared_scripts {
  'locales/*.lua',
  'modules/locales.lua',
  'config.lua'
}

server_scripts {
  'modules/utils/server.lua',
  'modules/bridge/esx/server.lua',
  'modules/bridge/ox/server.lua',
  'modules/bridge/qb/server.lua',
  'modules/bridge/qbx/server.lua',
  'modules/bridge/custom/server.lua',
  'modules/inventory/server.lua',
  'core/server.lua'
}

client_scripts {
  'modules/utils/client.lua',
  'modules/bridge/custom/client.lua',
  'core/client.lua'
}
