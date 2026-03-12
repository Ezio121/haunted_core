Config = Config or {}

Config.UI = Config.UI or {
    Enabled = true,
    Theme = {
        Variant = "cursed-victorian",
        GlowIntensity = 0.82,
        AnimationIntensity = 0.9,
        GhostDistortionIntensity = 0.74,
        PerformanceMode = false,
        ReducedMotion = false,
        StreamerMode = false,
        GrainOpacity = 0.08,
        FogOpacity = 0.12,
        Accent = {
            Primary = "#93d7ff",
            Secondary = "#9f9cc6",
            Success = "#8de7b5",
            Warning = "#d3bf86",
            Danger = "#bc4d5d",
            Spectral = "#7eead9"
        }
    },
    Layout = {
        Scale = 1.0,
        Compact = false,
        ShowMinimapMask = true,
        PositionPreset = "default",
        Presets = {
            ["default"] = {
                HudAnchor = { x = 1.0, y = 1.0 },
                NotificationAnchor = "top-right",
                InteractionAnchor = "bottom-center"
            },
            ["cinematic"] = {
                HudAnchor = { x = 0.98, y = 0.985 },
                NotificationAnchor = "top-center",
                InteractionAnchor = "bottom-center"
            },
            ["minimal"] = {
                HudAnchor = { x = 1.0, y = 1.0 },
                NotificationAnchor = "bottom-right",
                InteractionAnchor = "bottom-center"
            }
        }
    },
    Status = {
        EnableStress = true,
        EnableHunger = true,
        EnableThirst = true,
        EnableArmor = true,
        EnableStamina = true,
        EnableVoice = true,
        EnableWeatherPlaceholder = true,
        EnableStreetLabel = true,
        LowThreshold = 25,
        CriticalThreshold = 12
    },
    Notifications = {
        MaxVisible = 6,
        DefaultDurationMs = 4200,
        Position = "top-right",
        WidthPx = 360,
        EnableSounds = true,
        StackDirection = "down"
    },
    Radial = {
        OpenKey = "F5",
        HoldToOpen = true,
        HoldThresholdMs = 120,
        DeadzonePx = 36,
        CloseOnSelect = true,
        CursorOnOpen = true,
        GhostWheelKey = "F6"
    },
    Menus = {
        OpenKey = "F2",
        AllowKeyboardNavigation = true,
        EnableSearch = true,
        DefaultWidth = 520,
        MaxHeight = 700
    },
    Overlays = {
        DeathOverlay = true,
        LimboOverlay = true,
        PossessionOverlay = true,
        GhostAmbientOverlay = true,
        IntroOverlay = true
    },
    Audio = {
        WhisperOpen = false,
        RuneActivate = false,
        CursedError = false,
        SpiritFull = false,
        PossessionStart = false,
        LimboTransition = false,
        Volume = 0.45
    },
    Developer = {
        PreviewCommands = true,
        DebugNuiMessages = false
    }
}

return Config.UI
