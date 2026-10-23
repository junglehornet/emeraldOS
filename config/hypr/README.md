# Emerald desktop

Palette: background #0e1512, surface #111916, text #dce8e0, accent #50d890.

Configured files:
- hypr/hyprland.lua: compositor, session environment, startup, keybindings
- hypr/hyprpaper.conf and wallpapers/emerald.png: wallpaper on all displays
- hypr/hypridle.conf: lock after 10 minutes, displays off after 15; lock before sleep
- hypr/hyprlock.conf: matching lock screen
- waybar/config.jsonc and style.css: panel
- fuzzel/fuzzel.ini: launcher
- mako/config: notifications
- kitty/kitty.conf: terminal and ANSI palette
- gtk-3.0 and gtk-4.0/settings.ini and gtk.css: dark theme and green accents
- qt6ct/qt6ct.conf and colors/emerald.conf: Fusion palette and Papirus icons
- hypr/scripts/apply-theme: GTK and portal desktop preferences

Log out and back into Hyprland to apply the session environment and startup changes. Restart existing GUI applications to pick up toolkit themes. Libadwaita applications can override some CSS preferences.

Shortcuts: Super+Return terminal; Super+D launcher; Super+E files; Super+B browser; Super+Q close; Super+V float; Super+F fullscreen; Super+L lock; Super+arrows focus; Super+1..0 workspace; Super+Shift+1..0 move to workspace; Print region screenshot; Super+Shift+E exit.

Monitor preferred mode, automatic placement and scale 1 are retained. Keyboard layout remains US. No automatic suspend is configured. Change idle timeouts in hypridle.conf as needed.

Original configs backed up under ~/.local/state/desktop-theme/backups/20261021-213609. Restore the files from that directory to roll back existing configs; remove newly created files separately.

Validation: Hyprland --verify-config, luac -p, and fuzzel --check-config passed. Hypridle parsed both timeout rules. Full graphical validation requires access to the desktop Wayland and session D-Bus sockets, unavailable in this execution environment.
