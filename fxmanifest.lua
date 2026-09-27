fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dps-fleet'
description 'DPS Fleet: the vehicle browser and the workshop on one panel (Del Perro Sands)'
author 'DelPerroSands'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
    'shared/fields.lua',
    'shared/groups.lua',
    'shared/search.lua',
    'shared/workshop.lua',
}
client_scripts { 'client.lua', 'client/workshop.lua', 'client/repair.lua', 'client/target.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }

dependencies { 'ox_lib', 'qbx_core', 'oxmysql', 'ox_target' }
