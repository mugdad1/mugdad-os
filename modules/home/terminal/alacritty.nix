# Alacritty is the X11 terminal. foot is Wayland-only, so the Cinnamon X11
# session had no terminal at all (xterm is excluded and cinnamon.apps is off).
# scripts/terminal.sh picks foot on Hyprland and alacritty everywhere else.
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
