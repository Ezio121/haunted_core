fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'haunted-core'
author 'Haunted Core Team'
description 'Standalone supernatural roleplay framework with ESX/QBCore/QBox compatibility bridges'
version '1.1.0'

provide 'qb-core'
provide 'es_extended'
provide 'qbx_core'
provide 'oxmysql'

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/styles/*.css',
    'nui/scripts/*.js',
    'nui/assets/icons/*',
    'nui/assets/textures/*',
    'nui/assets/runes/*',
    'nui/assets/audio/*'
}

shared_scripts {
    'config.lua',
    'shared/ui_config.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/events.lua',
    'shared/framework.lua'
}

server_scripts {
    'server/db_node.js',
    'server/db.lua',
    'server/db_schema.lua',
    'server/db_migrations.lua',
    'server/player_manager.lua',
    'server/permissions.lua',
    'server/economy.lua',
    'server/inventory.lua',
    'server/entity_manager.lua',
    'server/event_security.lua',
    'server/ghost_system.lua',
    'server/anti_exploit.lua',
    'bridges/oxmysql_bridge.lua',
    'bridges/qbcore_bridge.lua',
    'bridges/esx_bridge.lua',
    'bridges/qbox_bridge.lua',
    'server/compatibility_provider.lua',
    'exports/database.lua',
    'exports/player.lua',
    'exports/ghost.lua',
    'exports/economy.lua',
    'exports/permissions.lua',
    'server/main.lua'
}

client_scripts {
    'client/ui.lua',
    'client/hud.lua',
    'client/notifications.lua',
    'client/menus.lua',
    'client/radial.lua',
    'client/interaction.lua',
    'client/death_state.lua',
    'client/ghost_fx.lua',
    'client/main.lua',
    'client/ghost_state.lua',
    'client/visuals.lua',
    'client/abilities.lua'
}
