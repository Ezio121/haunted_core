# Haunted Core

Haunted Core is a standalone FiveM framework with:

- full server-authoritative player/account/inventory persistence
- built-in SQL abstraction
- oxmysql-compatible API emulation
- compatibility bridges for QBCore, ESX, and QBox
- supernatural gameplay systems with hardened event security

## Database Architecture

Haunted Core uses `server/db.lua` as the only SQL gateway.

### DB API

Available methods:

- `HauntedCore.DB.scalar(query, params[, cb])`
- `HauntedCore.DB.single(query, params[, cb])`
- `HauntedCore.DB.query(query, params[, cb])`
- `HauntedCore.DB.insert(query, params[, cb])`
- `HauntedCore.DB.update(query, params[, cb])`
- `HauntedCore.DB.execute(query, params[, cb])`
- `HauntedCore.DB.transaction(queries[, cb])`
- `HauntedCore.DB.prepare(query, params[, cb])`
- `HauntedCore.DB.ready(cb)`

Also available:

- `HauntedCore.DB.promise.query(...)` and matching promise wrappers for all methods.

### Backend Detection

Haunted Core:

1. checks for an external `oxmysql` resource
2. uses oxmysql when present
3. safely degrades if no SQL backend is installed
4. normalizes parameter styles (`{1, 2}`, `{id = 1}`, `{['@id'] = 1}`)

### Query Safety / Performance

- nil-safe return normalization
- slow query warnings (`Config.Database.SlowQueryWarningMs`)
- optional DB debug logging (`Config.Database.Debug`)
- centralized error handling + audit logging

## Schema and Migrations

### Full Schema

- `sql/haunted_core.sql`

### Incremental Migrations

- `sql/migrations/001_base.sql`
- `sql/migrations/002_ghost_state.sql`
- `sql/migrations/003_audit_logs.sql`

### Runtime Components

- `server/db_schema.lua` ensures migration metadata table exists
- `server/db_migrations.lua` applies missing migrations in order and records them in `hc_schema_migrations`

## Persistence Coverage

Haunted Core persists:

- users/identity (`users`)
- accounts (`player_accounts`)
- inventory (`player_inventory`)
- metadata (`player_metadata`)
- permissions (`player_permissions`)
- ghost state (`ghost_states`)
- jobs/grades (`jobs`, `job_grades`)
- entities (`owned_entities`)
- security/audit logs (`audit_logs`)
- server key/value (`server_kvp`)

Player load/save is driven by `server/player_manager.lua`.

## Provide Compatibility

`fxmanifest.lua` declares:

- `provide 'qb-core'`
- `provide 'es_extended'`
- `provide 'qbx_core'`
- `provide 'oxmysql'`

This allows common auto-detection patterns such as:

```lua
if GetResourceState('qb-core') == 'started' then ... end
if GetResourceState('es_extended') == 'started' then ... end
if GetResourceState('qbx_core') == 'started' then ... end
if GetResourceState('oxmysql') == 'started' then ... end
```

to continue working when Haunted Core is replacing those resources.

## oxmysql Compatibility

Haunted Core exposes oxmysql-like exports in `bridges/oxmysql_bridge.lua`:

- `exports.oxmysql:query(...)`
- `exports.oxmysql:single(...)`
- `exports.oxmysql:scalar(...)`
- `exports.oxmysql:insert(...)`
- `exports.oxmysql:update(...)`
- `exports.oxmysql:execute(...)`
- `exports.oxmysql:transaction(...)`
- `exports.oxmysql:prepare(...)`
- async aliases:
  - `query_async`
  - `single_async`
  - `scalar_async`
  - `insert_async`
  - `update_async`
  - `execute_async`

Global compatibility is also provided:

- `MySQL.query(...)`
- `MySQL.single(...)`
- `MySQL.scalar(...)`
- `MySQL.insert(...)`
- `MySQL.update(...)`
- `MySQL.prepare(...)`
- `MySQL.execute(...)`
- `MySQL.transaction(...)`
- `MySQL.Sync.fetchAll(...)`
- `MySQL.Sync.fetchScalar(...)`
- `MySQL.Sync.execute(...)`
- `MySQL.Async.fetchAll(...)`
- `MySQL.Async.fetchScalar(...)`
- `MySQL.Async.execute(...)`
- `MySQL.Async.insert(...)`

### Known Behavior Differences

- When no external SQL backend exists, DB methods fail safely (default returns) and warnings are logged.
- Exotic oxmysql edge-case behavior is not emulated; high-value/common usage paths are supported.

## Framework Bridge Compatibility

### QBCore

- `exports['qb-core']:GetCoreObject()`
- `QBCore.Functions.GetPlayer`
- `QBCore.Functions.GetPlayerByCitizenId`
- `QBCore.Functions.CreateCallback`
- usable item registration skeleton

### ESX

- `exports['es_extended']:getSharedObject()`
- `ESX.GetPlayerFromId`
- `ESX.RegisterServerCallback`
- `ESX.RegisterUsableItem`

### QBox

- `exports['qbx_core']:GetQBoxObject()`
- `QBox.Player`
- `QBox.Functions.GetPlayer`
- callback + usable item registration skeleton

## Audit Logging and Security

`HauntedCore.LogAudit(action, source, citizenid, payload)` writes to `audit_logs`.

Logged categories include:

- event spam
- invalid payload/token attempts
- money mutation anomalies
- duplicate inventory anomalies
- permission changes
- ghost abuse attempts
- anti-exploit flags/kicks

## Usage Examples

### Haunted Core direct query

```lua
local row = exports['haunted-core']:Single(
    'SELECT citizenid, job FROM users WHERE license = ?',
    { license }
)
```

### oxmysql-compatible style

```lua
local result = exports.oxmysql:single(
    'SELECT * FROM users WHERE citizenid = ?',
    { citizenid }
)
```

### Global MySQL style

```lua
local count = MySQL.scalar('SELECT COUNT(*) FROM users', {})
```

### Player access

```lua
local player = exports['haunted-core']:GetPlayer(source)
if player then
    print(player.citizenid, player.job.name)
end
```

## Migration Notes

### From QBCore

- keep common `QBCore.Functions.GetPlayer` usage
- replace direct qb-core internals with Haunted Core exports for new scripts
- keep callback pattern compatibility via bridge

### From ESX

- keep `ESX.GetPlayerFromId` and callback pattern
- migrate stateful custom logic toward Haunted Core exports for strict server authority

### From QBox

- bridge supports common player/callback flows
- migrate resource-specific internals toward Haunted Core modules

### From oxmysql scripts

- existing `exports.oxmysql:*` usage works through Haunted Core provider
- common `MySQL.*`, `MySQL.Sync.*`, and `MySQL.Async.*` patterns are supported

## Config Highlights

`config.lua` database and compatibility controls:

```lua
Config.Database = {
    Debug = false,
    SlowQueryWarningMs = 250,
    AutoMigrate = true,
    AutoCreateSchema = true,
    SaveIntervalMinutes = 10,
    UseTransactions = true,
    AuditLogging = true
}
```

Additional toggles:

- `Config.Compatibility.StrictMode`
- `Config.Compatibility.OxmysqlEmulation`
- `Config.Compatibility.LegacyCallbacks`
- `Config.Identifiers.Priority`
