# Haunted Core

Haunted Core is a standalone FiveM framework for supernatural roleplay with:

- server-authoritative player/account/inventory persistence
- built-in SQL abstraction and native MariaDB mode
- oxmysql-compatible export and global API emulation
- QBCore / ESX / QBox compatibility bridges
- hardened event security and exploit prevention
- premium haunted NUI/HUD system

## Resource Architecture

### Core Layers

- `shared/*`: constants, utilities, event bus, framework namespace
- `server/*`: DB, migrations, player state, economy, inventory, permissions, anti-exploit
- `bridges/*`: compatibility adapters (`qb-core`, `es_extended`, `qbx_core`, `oxmysql`)
- `client/*`: gameplay + UI integration + radial/interaction/death overlays
- `nui/*`: HTML/CSS/JS haunted design system and runtime UI modules

### UI Layers

- `client/ui.lua`: NUI message router, focus manager, menu/radial/inventory/admin open-close APIs
- `client/hud.lua`: throttled status sampling and partial HUD updates
- `client/notifications.lua`: notification push interface
- `client/menus.lua`: occult context menu system with nested categories
- `client/radial.lua`: ghost ability wheel + nested radial support
- `client/ghost_fx.lua`: ghost/possession/phase overlay transitions
- `client/death_state.lua`: death/limbo/afterlife cinematic overlays
- `client/interaction.lua`: interaction prompts and hold progress UI

## UI Design Philosophy

Haunted Core UI is built as a haunted grimoire + premium tactical HUD:

- asymmetrical compact HUD for RP visibility
- spectral transitions instead of intrusive full-screen blocking
- ghost-state visual transformation with spirit-focused telemetry
- cursed-victorian visual motifs (runes, fog, grain, ritual framing)
- readable typography with decorative display headings only
- event-driven updates (no frame-spam DOM writes)

## Lua -> NUI Message Contracts

`SendNUIMessage({ type = "...", payload = {...} })`

### Core Contracts

- `haunted:hud:update`
- `haunted:hud:toggle`
- `haunted:notify:push`
- `haunted:menu:open`
- `haunted:menu:update`
- `haunted:menu:close`
- `haunted:radial:open`
- `haunted:radial:close`
- `haunted:overlay:show`
- `haunted:overlay:hide`
- `haunted:interaction:update`
- `haunted:inventory:open`
- `haunted:inventory:update`
- `haunted:inventory:close`
- `haunted:admin:open`
- `haunted:admin:update`
- `haunted:admin:close`
- `haunted:loading:show`
- `haunted:loading:hide`
- `haunted:character:open`
- `haunted:character:close`

### NUI -> Lua Callbacks

- `haunted:ui:ready`
- `haunted:ui:close`
- `haunted:ui:menuAction`
- `haunted:ui:radialAction`

## UI Configuration

UI config lives in `shared/ui_config.lua` (`Config.UI`):

- theme variant, glow intensity, animation intensity
- ghost distortion and performance mode
- reduced motion and streamer mode
- HUD scaling and layout presets
- notification position/limits
- radial/menu key behavior
- overlay toggles
- optional audio hook map

## Examples

### Direct Haunted Core player access

```lua
local player = exports['haunted-core']:GetPlayer(source)
if player then
    print(player.citizenid, player.job.name)
end
```

### Direct Haunted DB usage

```lua
local row = exports['haunted-core']:Single(
    'SELECT citizenid, job FROM users WHERE license = ?',
    { license }
)
```

### oxmysql-compatible usage

```lua
local result = exports.oxmysql:single(
    'SELECT * FROM users WHERE citizenid = ?',
    { citizenid }
)
```

### Push notification from client script

```lua
TriggerEvent('haunted:notify:push', {
    type = 'supernatural',
    title = 'Veil Surge',
    description = 'You sense an unstable spirit nearby.',
    icon = 'ghost',
    duration = 4500
})
```

### Open context menu from client script

```lua
TriggerEvent('haunted:menu:open', {
    title = 'Occult Actions',
    subtitle = 'Choose invocation',
    entries = {
        {
            id = 'ward',
            title = 'Create Ward',
            description = 'Protect this area from possession.',
            clientEvent = 'haunted:notify:push',
            args = { type = 'ritual', title = 'Ward', description = 'Ward established.' }
        }
    }
})
```

## Adding New HUD Widgets

1. Add new value in client state pipeline (`client/hud.lua`).
2. Include it in `UI.UpdateHud(...)` payload.
3. Render it in `nui/scripts/hud.js`.
4. Style in `nui/styles/hud.css`.

Keep updates interval-based and diff-aware; do not push per-frame full objects.

## Adding New Menu Pages

1. Build a menu payload (`title`, `subtitle`, `entries`, optional `breadcrumbs`).
2. `TriggerEvent('haunted:menu:open', payload)`.
3. For nested pages, provide `entry.submenu` table.

## Adding New Radial Abilities

1. Extend slices in `client/radial.lua` (or send custom payload via event).
2. Set `ability`, `icon`, `cooldown`, `locked` flags.
3. Route selected actions to secure server events.

## Performance Notes

- HUD updates are throttled and partial.
- NUI modules reuse DOM containers; no full screen repaint loops.
- FX layers are lightweight and configurable via `PerformanceMode`.
- Pause menu suppresses HUD visibility.
- Idle UI cost remains event-driven.

## Reskin / Theme Strategy

To reskin later without logic rewrites:

- only modify `nui/styles/*.css`
- keep contracts in `nui/scripts/events.js` + `client/ui.lua`
- if adding a new theme variant, map it in `theme.css` variables

## Compatibility and Provide

`fxmanifest.lua` provides:

- `qb-core`
- `es_extended`
- `qbx_core`
- `oxmysql`

Common auto-detection checks continue to pass:

```lua
if GetResourceState('qb-core') == 'started' then ... end
if GetResourceState('es_extended') == 'started' then ... end
if GetResourceState('qbx_core') == 'started' then ... end
if GetResourceState('oxmysql') == 'started' then ... end
```

## Database Backend Behavior

Backend selection:

1. external `oxmysql` (if present)
2. embedded native MariaDB adapter (`server/db_node.js` + `mysql2`)
3. standalone fallback backend (when native mode is disabled/unavailable)

## Migration Notes

### QBCore scripts

- `exports['qb-core']:GetCoreObject()` remains available
- common player/callback/usable-item patterns are bridged

### ESX scripts

- `exports['es_extended']:getSharedObject()` remains available
- callback and usable item registration remain compatible

### QBox scripts

- `exports['qbx_core']:GetQBoxObject()` remains available
- common player and callback patterns are bridged

### oxmysql scripts

Supported old patterns include:

- `exports.oxmysql:query/single/scalar/insert/update/execute/prepare/transaction`
- `*_async` aliases
- `MySQL.query/single/scalar/insert/update/execute/prepare/transaction`
- `MySQL.Sync.fetchAll/fetchScalar/execute`
- `MySQL.Async.fetchAll/fetchScalar/execute/insert`

Haunted Core is the provider and does not require external oxmysql resource code.

## Developer Preview Commands

With `Config.UI.Developer.PreviewCommands = true`:

- `/hc_uinotify`
- `/hc_menu`
- `/hc_radial`
- `/hc_inventory`
- `/hc_adminpanel`
- `/hc_interact_preview`

These commands preview haunted UI systems in-game.
