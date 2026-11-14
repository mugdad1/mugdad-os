{variables, ...}: let
  configFor = import ./config.nix variables;
  mainBar = configFor "hyprland/workspaces";
in {
  # One config everywhere: the default ~/.config/waybar/config uses
  # hyprland/workspaces, and toggle-waybar starts plain `waybar`.
  programs.waybar.settings.mainBar = mainBar;

  # The Hyprland session script starts waybar with
  # `-c ~/.config/waybar/config-hypr`, so keep that file too.
  xdg.configFile."waybar/config-hypr".text = builtins.toJSON mainBar;
}
