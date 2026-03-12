# Haunted Core

Haunted Core is a standalone FiveM framework built for ghost and supernatural roleplay, with server-authoritative logic and compatibility bridges for ESX, QBCore, and QBox.

## Architecture

Haunted Core is split into focused modules:

- `shared/`: constants, utilities, framework API surface, internal event bus
- `server/`: player management, permissions, economy, inventory, security, anti-exploit, ghost systems
- `client/`: token handshake, ghost state sync, visuals, ability input and secure requests
- `bridges/`: ESX/QBCore/QBox adapters mapped onto Haunted Core internals
- `exports/`: stable public exports for external resources

Core design principles:

- Server authoritative for economy, inventory, permissions, and ghost state
- Minimal client trust through secure event envelopes (`token + payload`)
- Centralized event validation and throttling
- State bags used for low-overhead sync hints (`ghostState`, permission, account snapshots)
- Modular code organization for maintainability and extension

## Security Model

All sensitive client->server interactions run through `RegisterSecureNetEvent`.

Each request is validated by:

1. Per-player rotating token verification
2. Per-event rate limiting
3. Global trigger rate limiting
4. Burst/mass-trigger strike tracking
5. Optional per-event sanity checks and permission checks
6. Anti-exploit scoring and auto-drop on threshold

## Player System

Server-side player objects include:

- `source`
- `identifier`
- `citizenid`
- `license`
- `name`
- `job`
- `inventory`
- `permissions`
- `ghost_state`
- `metadata`
- `accounts` (`cash`, `bank`, `spirit_energy`)

Available exports:

- `exports["haunted-core"]:GetPlayer(source)`
- `exports["haunted-core"]:GetPlayerByCitizenId(citizenId)`
- `exports["haunted-core"]:CreatePlayer(source)`
- `exports["haunted-core"]:SavePlayer(source)`
- `exports["haunted-core"]:DropPlayer(source, reason)`

Player persistence is handled through resource KVP snapshots.

## Ghost System

States:

- `ALIVE`
- `GHOST`

Abilities:

- `phase_through_walls`
- `invisibility`
- `object_possession`
- `spirit_whisper`
- `haunt_entities`

Behavior:

- Ghost state is tracked server-side and synced to clients
- Ability execution is validated server-side
- Ability cost uses `spirit_energy`
- Cooldowns are enforced server-side
- Interactions can be restricted across `ALIVE`/`GHOST` boundaries

Public ghost exports:

- `exports["haunted-core"]:SetGhostState(source, state)`
- `exports["haunted-core"]:GetGhostState(source)`
- `exports["haunted-core"]:UseGhostAbility(source, abilityName, payload)`

## Economy

Accounts:

- `cash`
- `bank`
- `spirit_energy`

Exports:

- `exports["haunted-core"]:AddMoney(source, account, amount, reason)`
- `exports["haunted-core"]:RemoveMoney(source, account, amount, reason)`
- `exports["haunted-core"]:GetMoney(source, account)`
- `exports["haunted-core"]:AddSpiritEnergy(source, amount, reason)`

## Inventory

Inventory items use:

```lua
{
    name = "item_name",
    count = 1,
    metadata = {}
}
```

Server functions:

- `HauntedCore.Inventory.AddItem(source, name, count, metadata)`
- `HauntedCore.Inventory.RemoveItem(source, name, count, metadata)`
- `HauntedCore.Inventory.HasItem(source, name, count, metadata)`

Anti-dup controls:

- Server-authoritative add/remove
- Transaction lock per player
- Underflow checks with exploit scoring

## Permissions

Hierarchy:

- `player`
- `helper`
- `admin`
- `god`

Exports:

- `exports["haunted-core"]:HasPermission(source, permission)`
- `exports["haunted-core"]:AddPermission(source, permission)`
- `exports["haunted-core"]:RemovePermission(source, permission)`

## Compatibility Bridges

### QBCore Bridge

Provides:

- `QBCore.Functions.GetPlayer(source)`
- `QBCore.Functions.GetPlayerByCitizenId(citizenId)`
- `QBCore.Functions.GetPlayers()`
- `QBCore.Functions.CreateCallback(name, cb)`
- `QBCore:GetObject` event
- `exports["haunted-core"]:GetCoreObject()`

### ESX Bridge

Provides:

- `ESX.GetPlayerFromId(source)`
- `ESX.GetPlayerFromIdentifier(identifier)`
- `ESX.RegisterServerCallback(name, cb)`
- `esx:getSharedObject` event
- `exports["haunted-core"]:getSharedObject()`

### QBox Bridge

Provides:

- `QBox.Player(source)`
- `QBox.Functions.GetPlayer(source)`
- `QBox.Functions.GetPlayerByCitizenId(citizenId)`
- `QBox.Functions.CreateCallback(name, cb)`
- `QBox:GetObject` event
- `exports["haunted-core"]:GetQBoxObject()`

## Writing Scripts for Haunted Core

Use exports and server-authoritative actions:

```lua
local player = exports["haunted-core"]:GetPlayer(source)
if player then
    local hasGem = player:HasItem("spirit_gem", 1, {})
    if hasGem then
        exports["haunted-core"]:AddSpiritEnergy(source, 25, "spirit_gem_used")
    end
end
```

Secure net events from client should send:

```lua
{
    token = "<security token>",
    data = { ... }
}
```

## Migration Guide

### From QBCore

1. Replace dependency on `qb-core` with `haunted-core`.
2. Keep existing `QBCore.Functions.GetPlayer` usage where bridge coverage exists.
3. Move sensitive money/item actions to server if they are currently client-trusted.
4. Prefer direct Haunted Core exports for new code.

### From ESX

1. Replace `es_extended` dependency with `haunted-core`.
2. Existing `ESX.GetPlayerFromId` and callback patterns remain usable through bridge.
3. Validate custom inventory/economy scripts against server-authoritative flows.

### From QBox

1. Replace `qbx_core` dependency with `haunted-core`.
2. Use provided `QBox.Player` / `QBox.Functions.*` compatibility entries.
3. Adopt Haunted Core exports for new systems and ghost mechanics.

## Installation

1. Place `haunted-core` in your `resources` folder.
2. Ensure it in your server config:

```cfg
ensure haunted-core
```

3. Configure behavior in `config.lua`.
4. Start server and verify startup log:

`[HauntedCore] Started v1.0.0`
