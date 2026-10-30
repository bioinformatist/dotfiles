-- https://wiki.hypr.land/configuring/
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Load only this host's writable nwg-displays layout, after the automatic default.
local configHome = os.getenv("XDG_CONFIG_HOME")
if not configHome or configHome == "" then
    configHome = os.getenv("HOME") .. "/.config"
end
dofile(configHome .. "/hypr/monitors.lua")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 20,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = true, range = 4, render_power = 3, color = 0xee1a1a1a },
        blur = { enabled = true, size = 3, passes = 1, vibrancy = 0.1696 },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    master = { new_status = "master" },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        background_color = 0x000000,
    },
    ecosystem = { no_update_news = true },
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = { natural_scroll = false },
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })
hl.curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- Workspaces remain free-flowing; unscoped persistent rules move them on reload.
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

-- Only the input-method toggle bypasses application shortcut inhibition.
hl.bind("CTRL + space", hl.dsp.exec_cmd("fcitx5-remote -t"), { dont_inhibit = true })
hl.bind("SUPER + Return", hl.dsp.exec_cmd("ghostty"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("anyrun"))
hl.bind("SUPER + C", hl.dsp.exec_cmd([[sh -c 'if command -v wechat-control >/dev/null 2>&1; then exec wechat-control close-active; else exec hyprctl dispatch "hl.dsp.window.close()"; fi']]))
hl.bind("SUPER + SHIFT + Q", hl.dsp.exit())
hl.bind("SUPER + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + P", hl.dsp.window.pseudo())
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + G", hl.dsp.group.toggle())
hl.bind("SUPER + A", hl.dsp.group.next())

hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Keep WeChat groups on regular workspaces while visible so Fcitx popups work.
hl.bind("SUPER + W", hl.dsp.exec_cmd("wechat-control toggle"))
hl.bind("SUPER + T", hl.dsp.workspace.toggle_special("telegram"))
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind("SUPER + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    hl.bind("right", hl.dsp.window.resize({ x = 30, y = 0, relative = true }), { repeating = true })
    hl.bind("left", hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
    hl.bind("up", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
    hl.bind("down", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), { repeating = true })
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("SUPER + R", hl.dsp.submap("reset"))
end)

hl.bind("ALT + A", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | satty --filename - --copy-command wl-copy]]))
hl.bind("Print", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | satty --filename - --copy-command wl-copy]]))
hl.bind("SUPER + Print", hl.dsp.exec_cmd([[grim -o $(hyprctl activeworkspace -j | jq -r '.monitor') - | satty --filename - --copy-command wl-copy]]))

hl.window_rule({ name = "suppress_maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "ghostty_opacity", match = { class = "^(com.mitchellh.ghostty)$" }, opacity = "0.95 0.85" })
hl.window_rule({
    name = "xwayland_nofocus",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
-- Child windows must keep their natural size.
hl.window_rule({ name = "wechat_float", match = { class = "^(wechat)$" }, float = true })
hl.window_rule({ name = "telegram_workspace", match = { class = [[^(org\.telegram\.desktop)$]] }, workspace = "special:telegram silent" })
hl.window_rule({ name = "telegram_float", match = { class = [[^(org\.telegram\.desktop)$]] }, float = true, size = { 960, 680 }, center = true })
