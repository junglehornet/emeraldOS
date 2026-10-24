
-- Hyprland 0.56.x
-- ~/.config/hypr/hyprland.lua

-------------------------
-- APPLICATIONS
-------------------------

local terminal = "kitty"
local launcher = "fuzzel"
local fileManager = "thunar"
local browser = "firefox"

-------------------------
-- MONITORS
-------------------------

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

-------------------------
-- ENVIRONMENT
-------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-------------------------
-- AUTOSTART
-------------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/apply-theme")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
end)

-------------------------
-- GENERAL APPEARANCE
-------------------------

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 12,
        border_size = 2,
        layout = "dwindle",

        col = {
            active_border = "rgba(50d890ff)",
            inactive_border = "rgba(304038ff)",
        },
    },

    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(00000066)",
        },

        blur = {
            enabled = true,
            size = 5,
            passes = 2,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
    },
})

-------------------------
-- INPUT
-------------------------

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,

        touchpad = {
            natural_scroll = true,
        },
    },
})

-------------------------
-- KEYBINDINGS
-------------------------

local mod = "SUPER"

-- Applications
hl.bind(mod .. " + RETURN",
    hl.dsp.exec_cmd(terminal))

hl.bind(mod .. " + D",
    hl.dsp.exec_cmd(launcher))

hl.bind(mod .. " + E",
    hl.dsp.exec_cmd(fileManager))

hl.bind(mod .. " + B",
    hl.dsp.exec_cmd(browser))

-- Windows
hl.bind(mod .. " + Q",
    hl.dsp.window.close())

hl.bind(mod .. " + V",
    hl.dsp.window.float({ action = "toggle" }))

hl.bind(mod .. " + F",
    hl.dsp.window.fullscreen({
        mode = "fullscreen",
        action = "toggle",
    }))

-- Focus
hl.bind(mod .. " + left",
    hl.dsp.focus({ direction = "left" }))

hl.bind(mod .. " + right",
    hl.dsp.focus({ direction = "right" }))

hl.bind(mod .. " + up",
    hl.dsp.focus({ direction = "up" }))

hl.bind(mod .. " + down",
    hl.dsp.focus({ direction = "down" }))

-- Workspaces 1 through 10
for i = 1, 10 do
    local key = i % 10

    hl.bind(mod .. " + " .. key,
        hl.dsp.focus({ workspace = i }))

    hl.bind(mod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = i }))
end

-- Move and resize windows with mouse
hl.bind(mod .. " + mouse:272",
    hl.dsp.window.drag(),
    { mouse = true })

hl.bind(mod .. " + mouse:273",
    hl.dsp.window.resize(),
    { mouse = true })

-- Play/Pause button
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

-------------------------
-- SCREENSHOTS
-------------------------

hl.bind("Print",
    hl.dsp.exec_cmd(
        "mkdir -p ~/Pictures && grim -g \"$(slurp)\" ~/Pictures/screenshot-$(date +%s).png"
    ))

-------------------------
-- AUDIO
-------------------------

hl.bind("XF86AudioRaiseVolume",
    hl.dsp.exec_cmd(
        "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
    ),
    { repeating = true, locked = true })

hl.bind("XF86AudioLowerVolume",
    hl.dsp.exec_cmd(
        "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    ),
    { repeating = true, locked = true })

hl.bind("XF86AudioMute",
    hl.dsp.exec_cmd(
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    ),
    { locked = true })

-------------------------
-- BRIGHTNESS
-------------------------

hl.bind("XF86MonBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl set 5%+"),
    { repeating = true, locked = true })

hl.bind("XF86MonBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl set 5%-"),
    { repeating = true, locked = true })

-------------------------
-- LOCK AND EXIT
-------------------------

hl.bind(mod .. " + L",
    hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))

hl.bind(mod .. " + SHIFT + E",
    hl.dsp.exit())


-- Load the monitor rules Panorama writes. Keep this last: the final rule
-- for a monitor is the one Hyprland uses.
require("monitors")
