# Alacritty is the only terminal, on both Hyprland and Cinnamon X11. foot was
# removed 2026-11-28 (Wayland-only, and the session wrapper that picked between
# them went with it).
_: let
  c = (import ../../../lib/gruvbox.nix).raw;
in {
  programs.alacritty = {
    enable = true;

    settings = {
      window.padding = {
        x = 4;
        y = 4;
      };

      font = {
        normal = {
          family = "Iosevka Nerd Font";
          style = "Regular";
        };
        size = 12;
      };

      colors = {
        primary = {
          background = "#${c.bg0_h}";
          foreground = "#${c.fg0}";
        };
        cursor = {
          text = "#${c.bg0_h}";
          cursor = "#${c.fg0}";
        };
        normal = {
          black = "#${c.bg0}";
          red = "#${c.red}";
          green = "#${c.green}";
          yellow = "#${c.yellow}";
          blue = "#${c.blue}";
          magenta = "#${c.purple}";
          cyan = "#${c.aqua}";
          white = "#${c.fg}";
        };
        bright = {
          black = "#${c.light_gray}";
          red = "#${c.bright_red}";
          green = "#${c.bright_green}";
          yellow = "#${c.bright_yellow}";
          blue = "#${c.bright_blue}";
          magenta = "#${c.bright_purple}";
          cyan = "#${c.bright_aqua}";
          white = "#${c.fg0}";
        };
      };
    };
  };
}
