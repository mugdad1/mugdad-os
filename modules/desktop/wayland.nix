{pkgs, ...}: {
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;

    # Explicit per-desktop config: xdg-desktop-portal resolves
    # $XDG_CURRENT_DESKTOP to <name>-portals.conf. Hyprland gets its own
    # backend for screencopy/screenshots; Cinnamon ships its conf through the
    # NixOS cinnamon module (xdg.portal.configPackages) and falls back to
    # gtk here.
    config = {
      common = {
        default = ["gtk"];
      };

      hyprland = {
        default = ["hyprland" "gtk"];
        "org.freedesktop.impl.portal.ScreenCast" = ["hyprland"];
        "org.freedesktop.impl.portal.Screenshot" = ["hyprland"];
        "org.freedesktop.impl.portal.GlobalShortcuts" = ["hyprland"];
        "org.freedesktop.impl.portal.InputCapture" = ["hyprland"];
      };
    };

    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    # xdg-desktop-portal-hyprland is added by programs.hyprland
    # (modules/desktop/hyprland.nix), xdg-desktop-portal-xapp by the
    # cinnamon module.
  };
}
