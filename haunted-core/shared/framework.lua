HauntedCore = HauntedCore or {}

local HC = HauntedCore
HC.Config = Config or {}
HC.Version = HC.Constants and HC.Constants.VERSION or "1.0.0"

HC.Player = HC.Player or {}
HC.Ghost = HC.Ghost or {}
HC.Security = HC.Security or {}
HC.Economy = HC.Economy or {}
HC.Inventory = HC.Inventory or {}
HC.Permissions = HC.Permissions or {}
HC.DB = HC.DB or {}

function HC.IsServer()
    return IsDuplicityVersion()
end

function HC.GetPlayer(source)
    if HC.PlayerManager and HC.PlayerManager.GetPlayer then
        return HC.PlayerManager.GetPlayer(source)
    end
    return nil
end

function HC.GetPlayerByCitizenId(citizenId)
    if HC.PlayerManager and HC.PlayerManager.GetPlayerByCitizenId then
        return HC.PlayerManager.GetPlayerByCitizenId(citizenId)
    end
    return nil
end

function HC.DebugLog(message, ...)
    local cfg = HC.Config and HC.Config.Core
    if not cfg or not cfg.debug then
        return
    end

    local text = "[HauntedCore] " .. tostring(message)
    if select("#", ...) > 0 then
        text = text:format(...)
    end
    print(text)
end

if HC.IsServer() then
    local auditQueue = {}
    local maxQueuedAuditEvents = 1000

    local function flushAuditQueue()
        if not HC.DB or not HC.DB.IsReady or not HC.DB.IsReady() or not HC.DB.BackendAvailable or not HC.DB.BackendAvailable() then
            return
        end

        if #auditQueue == 0 then
            return
        end

        for i = 1, #auditQueue do
            local entry = auditQueue[i]
            HC.DB.insert(
                "INSERT INTO audit_logs (action, source, citizenid, payload) VALUES (?, ?, ?, ?)",
                { entry.action, entry.source, entry.citizenid, entry.payload }
            )
        end

        auditQueue = {}
    end

    function HC.FlushAuditQueue()
        flushAuditQueue()
    end

    function HC.LogAudit(action, source, citizenid, payload)
        if not (Config.Database and Config.Database.AuditLogging) then
            return false
        end

        local actionName = tostring(action or "unknown_action")
        local sourceId = tonumber(source) or 0
        local cid = citizenid

        if not cid and sourceId > 0 and HC.PlayerManager and HC.PlayerManager.GetPlayer then
            local player = HC.PlayerManager.GetPlayer(sourceId)
            if player then
                cid = player.citizenid
            end
        end

        local encodedPayload = HC.Utils.SafeJsonEncode(payload or {})

        if HC.DB and HC.DB.IsReady and HC.DB.IsReady() and HC.DB.BackendAvailable and HC.DB.BackendAvailable() then
            HC.DB.insert(
                "INSERT INTO audit_logs (action, source, citizenid, payload) VALUES (?, ?, ?, ?)",
                { actionName, sourceId, cid, encodedPayload }
            )
        else
            if #auditQueue >= maxQueuedAuditEvents then
                table.remove(auditQueue, 1)
            end
            auditQueue[#auditQueue + 1] = {
                action = actionName,
                source = sourceId,
                citizenid = cid,
                payload = encodedPayload
            }
        end

        if Config.Database.Debug then
            print(("[HauntedCore][Audit] %s source=%s citizenid=%s payload=%s"):format(
                actionName,
                sourceId,
                tostring(cid),
                encodedPayload
            ))
        end

        return true
    end
else
    function HC.LogAudit()
        return false
    end
end
