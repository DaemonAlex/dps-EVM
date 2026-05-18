fx_version 'cerulean'
game 'gta5'

name 'DSRP Emergency Vehicle Menu'
description 'Emergency vehicle modification system with QBox framework integration, job-based access control, and custom livery support. Adapted for DelPerro Sands RP.'
author 'DaemonAlex (Adapted for DSRP by DelPerro Sands RP)'
version '2.2.0-DSRP'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'ox_lib',
    'oxmysql'
}

lua54 'yes'
