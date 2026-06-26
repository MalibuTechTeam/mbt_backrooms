fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name 'mbt_backrooms'
author 'Malibù Tech Team'
version '2.0.0'
description 'Backrooms by Malibu Tech'

this_is_a_map 'yes'
data_file 'PED_METADATA_FILE' 'data/peds.meta'

dependencies {
  '/onesync'
}

shared_scripts {
  'locales/*.lua',
  'modules/locales.lua',
  'config.lua',
  'modules/utils/logger.lua'
}

server_scripts {
  'modules/utils/server.lua',
  'modules/bridge/esx/server.lua',
  'modules/bridge/ox/server.lua',
  'modules/bridge/qb/server.lua',
  'modules/bridge/qbx/server.lua',
  'modules/bridge/custom/server.lua',
  'modules/inventory/server.lua',
  'core/server.lua',
  'modules/sanity/server.lua',
  'modules/artifacts/server.lua',
  'modules/archive/server.lua',
  'modules/almondwater/server.lua',
  'modules/admin/server.lua'
}

client_scripts {
  'modules/utils/client.lua',
  'modules/atmosphere/client.lua',
  'modules/interaction/client.lua',
  'modules/exits/client.lua',
  'modules/artifacts/client.lua',
  'modules/almondwater/client.lua',
  'modules/light/client.lua',
  'modules/archive/client.lua',
  'modules/hud/client.lua',
  'modules/sanity/client.lua',
  'modules/entities/client.lua',
  'modules/contact/client.lua',
  'core/client.lua'
}

ui_page 'web/dist/index.html'

files {
  'data/peds.meta',
  'web/dist/index.html',
  'web/dist/assets/**',
  'web/dist/sounds/*.ogg'
}
