fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'haunted-core'
author 'Haunted Core Team'
description 'Standalone supernatural roleplay framework with ESX/QBCore/QBox compatibility bridges'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/events.lua',
    'shared/framework.lua'
}

server_scripts {
    'server/player_manager.lua',
    'server/permissions.lua',
    'server/economy.lua',
    'server/inventory.lua',
    'server/entity_manager.lua',
    'server/event_security.lua',
    'server/ghost_system.lua',
    'server/anti_exploit.lua',
    'server/main.lua',
    'bridges/qbcore_bridge.lua',
    'bridges/esx_bridge.lua',
    'bridges/qbox_bridge.lua',
    'exports/player.lua',
    'exports/ghost.lua',
    'exports/economy.lua',
    'exports/permissions.lua'
}

client_scripts {
    'client/main.lua',
    'client/ghost_state.lua',
    'client/visuals.lua',
    'client/abilities.lua'
}
