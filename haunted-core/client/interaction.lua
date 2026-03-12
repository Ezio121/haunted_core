HauntedCore = HauntedCore or {}
HauntedCore.Interaction = HauntedCore.Interaction or {}

local HC = HauntedCore
local Interaction = HC.Interaction

local activePrompt = nil
local holdStartedAt = 0
local holdDuration = 0

local function nowMs()
    return GetGameTimer()
end

local function sendPrompt()
    HC.UI.Send("haunted:interaction:update", {
        prompt = activePrompt
    })
end

function Interaction.ShowPrompt(prompt)
    if type(prompt) ~= "table" then
        return
    end

    activePrompt = {
        id = tostring(prompt.id or ("prompt_%s"):format(GetGameTimer())),
        label = tostring(prompt.label or "Interact"),
        description = tostring(prompt.description or ""),
        key = tostring(prompt.key or "E"),
        hold = prompt.hold == true,
        holdMs = tonumber(prompt.holdMs) or 1200,
        icon = tostring(prompt.icon or "interact"),
        progress = 0,
        style = tostring(prompt.style or "default")
    }

    holdStartedAt = 0
    holdDuration = activePrompt.holdMs
    sendPrompt()
end

function Interaction.HidePrompt()
    activePrompt = nil
    holdStartedAt = 0
    holdDuration = 0
    sendPrompt()
end

RegisterNetEvent("haunted:interaction:show", function(prompt)
    Interaction.ShowPrompt(prompt)
end)

RegisterNetEvent("haunted:interaction:hide", function()
    Interaction.HidePrompt()
end)

CreateThread(function()
    while true do
        Wait(0)

        if not activePrompt then
            Wait(150)
            goto continue
        end

        if IsControlJustPressed(0, 38) then
            if not activePrompt.hold then
                TriggerEvent("haunted:interaction:triggered", activePrompt)
                Interaction.HidePrompt()
            else
                holdStartedAt = nowMs()
            end
        end

        if activePrompt.hold and holdStartedAt > 0 then
            if not IsControlPressed(0, 38) then
                holdStartedAt = 0
                activePrompt.progress = 0
                sendPrompt()
            else
                local elapsed = nowMs() - holdStartedAt
                local pct = math.min(100, math.floor((elapsed / holdDuration) * 100))

                if pct ~= activePrompt.progress then
                    activePrompt.progress = pct
                    sendPrompt()
                end

                if elapsed >= holdDuration then
                    TriggerEvent("haunted:interaction:triggered", activePrompt)
                    Interaction.HidePrompt()
                end
            end
        end

        ::continue::
    end
end)

RegisterCommand("hc_interact_preview", function()
    if not (Config.UI and Config.UI.Developer and Config.UI.Developer.PreviewCommands) then
        return
    end

    Interaction.ShowPrompt({
        id = "preview_prompt",
        label = "Haunt Object",
        description = "Hold to imbue spectral resonance",
        key = "E",
        hold = true,
        holdMs = 1600,
        icon = "haunt",
        style = "spectral"
    })
end, false)
