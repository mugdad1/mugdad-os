# The Cinnamon half of the desktop. Hyprland lives in ./hyprland/; this file
# gives the Cinnamon session the same theme, the same application keybinds,
# and the pieces the Hyprland stack provides for free (clipboard history,
# screenshots).
#
# Cinnamon reads org.cinnamon.*, not org.gnome.*, so theme.nix's GTK block
# alone leaves the panel, menus and window borders at Mint-Y.
{
  config,
  lib,
  pkgs,
  ...
}: let
  gtkTheme = "Colloid-Green-Dark-Gruvbox";
  iconTheme = "Papirus-Dark";
  cursorTheme = "Bibata-Modern-Amber";

  # Same image the Hyprland session shows: random-wallpaper and
  # wallpaper-picker maintain this symlink, and wall-change now updates
  # Cinnamon's picture-uri to match.
  wallpaper = "${config.home.homeDirectory}/Pictures/wallpapers/wallpaper";

  # Mirror of the useful Hyprland binds (../hyprland/binds.nix). Cinnamon
  # custom keybindings live under custom-keybindings/customN and are listed
  # in custom-list. Super+E is deliberately absent: Cinnamon already binds
  # `home` to <Super>e.
  customBindings = [
    {
      id = "custom0";
      name = "Terminal";
      command = "terminal";
      binding = "<Super>Return";
    }
    {
      id = "custom1";
      name = "Browser";
      command = "zen-beta";
      binding = "<Super>b";
    }
    {
      id = "custom2";
      name = "Launcher";
      command = "toggle-rofi rofi -show drun";
      binding = "<Super>d";
    }
    {
      id = "custom3";
      name = "Clipboard history";
      command = "copyq toggle";
      binding = "<Super>v";
    }
    {
      id = "custom4";
      name = "Screenshot";
      command = "screenshot --save";
      binding = "Print";
    }
    {
      id = "custom5";
      name = "Screenshot area to clipboard";
      command = "screenshot --copy";
      binding = "<Super>Print";
    }
    {
      id = "custom6";
      name = "Screenshot area to editor";
      command = "screenshot --swappy";
      binding = "<Super><Shift>Print";
    }
  ];
in {
  dconf.settings =
    {
      "org/cinnamon/theme" = {
        name = gtkTheme;
      };

      "org/cinnamon/desktop/interface" = {
        gtk-theme = gtkTheme;
        icon-theme = iconTheme;
        cursor-theme = cursorTheme;
        cursor-size = 24;
        font-name = "Iosevka Nerd Font 14";
        clock-use-24h = true;
        clock-show-date = true;
      };

      "org/cinnamon/desktop/wm/preferences" = {
        theme = gtkTheme;
        titlebar-font = "Iosevka Nerd Font Bold 12";
        button-layout = "menu:minimize,maximize,close";
        num-workspaces = 4;
      };

      "org/cinnamon/desktop/background" = {
        picture-uri = "file://${wallpaper}";
        picture-options = "zoom";
        primary-color = "#282828";
        secondary-color = "#282828";
      };

      "org/cinnamon/desktop/screensaver" = {
        lock-enabled = true;
        idle-activation-enabled = true;
        lock-delay = lib.gvariant.mkUint32 0;
      };

      # Cinnamon's own lid handling runs next to logind (hosts/*/default.nix);
      # keep both saying suspend. Cinnamon would otherwise hibernate at 4 %,
      # and these machines have no swap.
      "org/cinnamon/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-battery-type = "nothing";
        lid-close-ac-action = "suspend";
        lid-close-battery-action = "suspend";
        lock-on-suspend = true;
        critical-battery-action = "shutdown";
      };

      # The custom Print binding below replaces Cinnamon's built-in one.
      "org/cinnamon/desktop/keybindings/media-keys" = {
        screenshot = [];
      };

      "org/cinnamon/desktop/keybindings" = {
        custom-list = map (b: b.id) customBindings;
      };
    }
    // builtins.listToAttrs (map (b: {
        name = "org/cinnamon/desktop/keybindings/custom-keybindings/${b.id}";
        value = {
          inherit (b) name command;
          binding = [b.binding];
        };
      })
      customBindings);

  # CopyQ is the X11 clipboard history. Hyprland uses cliphist instead
  # (../hyprland/exec-once.nix), so the autostart entry is Cinnamon-only.
  xdg.configFile."autostart/copyq.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=CopyQ
    Comment=Clipboard manager
    Exec=${pkgs.copyq}/bin/copyq --start-server
    OnlyShowIn=X-Cinnamon;
    NoDisplay=true
    X-GNOME-Autostart-enabled=true
  '';
}
