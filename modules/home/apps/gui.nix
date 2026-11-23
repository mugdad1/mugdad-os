{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    ## Multimedia
    imv
    obs-studio
    kdePackages.kdenlive
    shotcut
    gimp
    audacity
    pavucontrol
    vlc
    freetube
    cool-retro-term
    ## Browsers (un-nixified profiles)
    # Chromium wrapped instead of overridden: `commandLineArgs` would rebuild
    # the whole browser, while this only adds a wrapper. The basic password
    # store keeps Chromium out of gnome-keyring entirely, so it never asks to
    # unlock a keyring (saved passwords are then encrypted with a fixed key).
    (pkgs.symlinkJoin {
      name = "chromium-basic-store";
      paths = [pkgs.chromium];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        for bin in chromium chromium-browser; do
          if [ -e "$out/bin/$bin" ]; then
            wrapProgram "$out/bin/$bin" --add-flags "--password-store=basic"
          fi
        done
      '';
    })
    tor-browser

    ## Cloud storage — the headless seafile-client daemon and CLI are
    ## declared in modules/core/seafile-client.nix. There is no GUI client
    ## on any host anymore; Filen was removed on 2026-11-20.

    ## Office / Productivity
    libreoffice-stable

    ## System / Utility
    qbittorrent
    gnome-disk-utility
    # localsend needs zlib in the wrapper's library path.
    (localsend.overrideAttrs (old: {
      extraWrapProgramArgs =
        lib.trim (old.extraWrapProgramArgs or "")
        + " --prefix LD_LIBRARY_PATH : ${zlib}/lib";
    }))
    zenity
    kdePackages.polkit-kde-agent-1
    wlsunset

    ## GNOME apps (PDF viewer, archive manager)
    evince
    file-roller

    ## File manager
    nemo-with-extensions
    nemo-fileroller
  ];

  dconf.settings = {
    "org/nemo/preferences" = {
      always-use-browser = true;
      close-device-view-on-device-eject = true;
      date-font-choice = "auto-mono";
      date-format = "iso";
      last-server-connect-method = 3;
      quick-renames-with-pause-in-between = true;
      show-edit-icon-toolbar = false;
      show-full-path-titles = false;
      show-hidden-files = true;
      show-home-icon-toolbar = true;
      show-new-folder-icon-toolbar = true;
      show-open-in-terminal-toolbar = false;
      show-search-icon-toolbar = false;
      show-show-thumbnails-toolbar = false;
      thumbnail-limit = lib.gvariant.mkUint64 (100 * 1024 * 1024); # 100 mb
    };
    "org/nemo/preferences/menu-config" = {
      background-menu-open-as-root = false;
      selection-menu-open-as-root = false;
      selection-menu-open-in-terminal = false;
      selection-menu-scripts = false;
    };
    "org/nemo/search" = {
      search-reverse-sort = false;
      search-sort-column = "name";
    };
    "org/nemo/window-state" = {
      maximized = true;
      network-expanded = true;
      side-pane-view = "places";
      sidebar-bookmark-breakpoint = 2;
      sidebar-width = lib.gvariant.mkInt32 180;
      start-with-sidebar = true;
    };
  };
}
