fx_version 'cerulean'
game 'gta5'

description 'lsn-voltage'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/*',
}

files {
    'locales/*.json',
}

lua54 'yes'
use_fxv2_oal 'yes'
