# Full Wine compatibility stack for CapCut (Windows x86_64 app, no native
# Linux desktop build). The core is a WoW64 Wine with the staging patchset:
# one prefix handles both 32-bit installers and the 64-bit app, and the "full"
# build enables gstreamer, ffmpeg, Vulkan, VA-API, GTK, CUPS, etc.
# Nothing here is host-global; it is enabled only on victus.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.victus.wine;
in {
  options.services.victus.wine.enable = lib.mkEnableOption ''
    install the full Wine/Bottles compatibility stack for CapCut
  '';

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Wine itself: staging patches + all optional support, 32- and 64-bit in
      # a single prefix. `wineWow64Packages.fonts` are Wine's MIT-licensed
      # replacements for the Microsoft fonts installers expect.
      wineWow64Packages.stagingFull
      wineWow64Packages.fonts
      winetricks

      # Prefix managers. Bottles is the easiest way to give CapCut its own
      # prefix and install its runtime dependencies; Lutris is a fallback.
      bottles
      lutris

      # DirectX translation. CapCut uses DX11/DX12 heavily for its preview and
      # effects; these map those calls to the Vulkan driver already present.
      dxvk
      vkd3d

      # Rendering/overlay helpers. vkbasalt must be in systemPackages for
      # Bottles' toggle to work (Bottles issue #2401).
      gamemode
      mangohud
      vkbasalt

      # Fonts that Windows apps and installers assume exist.
      corefonts # unfree, already allowed by modules/core/system.nix
      liberation_ttf
      dejavu_fonts
      noto-fonts

      # Wine's gstreamer backend uses these codecs for media preview/export.
      ffmpeg
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-libav

      # Small utilities winetricks/Bottles call out to.
      cabextract
      p7zip
      unzip
      zenity
      xdg-utils
    ];
  };
}
