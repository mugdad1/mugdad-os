{
  config,
  variables,
  ...
}: {
  home.sessionVariables = {
    # XDG_CURRENT_DESKTOP / XDG_SESSION_TYPE / XDG_SESSION_DESKTOP are NOT set
    # here: these variables are shared by every session, so a hard-coded
    # desktop name would leak into the wrong one. The greetd session wrappers
    # (modules/desktop/services.nix) export the right values for whichever
    # session was picked at login.

    # XKB_* is a fallback for anything that reads the environment; Hyprland
    # sets the layout explicitly (modules/home/desktop/hyprland/settings.nix)
    # and Cinnamon keeps its own keyboard settings.
    XKB_DEFAULT_LAYOUT = variables.keyboardLayout;
    XKB_DEFAULT_OPTIONS = variables.keyboardOptions;

    NIXOS_OZONE_WL = 1;
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    GDK_BACKEND = "wayland";
    DIRENV_LOG_FORMAT = "";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = 1;
    QT_QPA_PLATFORM = "wayland";

    NH_FLAKE = "${config.home.homeDirectory}/mugdad-os";

    WINEDLLOVERRIDES = "winemenubuilder.exe=d";
  };
}
