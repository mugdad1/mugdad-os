{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.desktop;
  g = (import ../../lib/gruvbox.nix).raw;

  greeterTheme = "container=#${g.bg0_h};border=#${g.green};text=#${g.fg};prompt=#${g.yellow};time=#${g.gray};action=#${g.blue};button=#${g.aqua};title=#${g.bright_blue};greet=#${g.bright_green};input=#${g.fg}";

  # Only needed on machines where the panel hangs off the iGPU and an external
  # port hangs off the dGPU (the Victus): the compositor has to be told both
  # DRM nodes up front, because it picks its nodes at startup and cannot add
  # one later. Everywhere else it picks its own nodes.
  gpuDevices = lib.optionalString cfg.intelPrimaryDrm ''
    # Cards are found by PCI vendor id, because card numbering depends on load
    # order.
    drm_card_for() {
      for d in /sys/class/drm/card[0-9]*; do
        [ -r "$d/device/vendor" ] || continue
        card="''${d##*/}"
        [ -c "/dev/dri/$card" ] || continue
        if [ "$(cat "$d/device/vendor")" = "$1" ]; then
          printf '/dev/dri/%s\n' "$card"
          return 0
        fi
      done
      return 1
    }
    # True if any connector on the given card reports a connected display.
    card_has_display() {
      for c in /sys/class/drm/"$1"-*/status; do
        [ -r "$c" ] || continue
        if [ "$(cat "$c")" = connected ]; then
          return 0
        fi
      done
      return 1
    }
    intel_card="$(drm_card_for 0x8086 || true)"
    nvidia_card="$(drm_card_for 0x10de || true)"
    if [ -n "$intel_card" ]; then
      if [ -n "$nvidia_card" ] && card_has_display "''${nvidia_card##*/}"; then
        export AQ_DRM_DEVICES="$intel_card:$nvidia_card"
      else
        export AQ_DRM_DEVICES="$intel_card"
        # Nothing is plugged into the dGPU, so keep glvnd away from it: a
        # single open /dev/nvidia* handle pins the GPU in D0 and defeats
        # runtime D3. `nvidia-offload` overrides these for one command.
        mesa_egl=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
        if [ -r "$mesa_egl" ]; then
          export __EGL_VENDOR_LIBRARY_FILENAMES="$mesa_egl"
        fi
        export __GLX_VENDOR_LIBRARY_NAME=mesa
        unset __NV_PRIME_RENDER_OFFLOAD __NV_PRIME_RENDER_OFFLOAD_PROVIDER __VK_LAYER_NV_optimus
      fi
    fi
  '';

  # Shared greetd Wayland-session wrapper: exports the session vars and the
  # GPU selection, then execs the compositor. AQ_DRM_DEVICES is read by
  # Hyprland; Cinnamon ignores it and scans the cards itself.
  sessionWrapper = pkgs.writeShellScript "wayland-session" ''
    # greetd sets up no session environment: /etc/profile is what exports
    # XDG_DATA_DIRS (cinnamon-session looks up its session and required
    # component files there) and PATH (cinnamon-session-cinnamon execs
    # `cinnamon-session` by name).
    . /etc/profile

    case "''${1##*/}" in
      start-hyprland | hyprland)
        export XDG_SESSION_DESKTOP=Hyprland
        export XDG_CURRENT_DESKTOP=Hyprland
        ;;
      cinnamon-session-cinnamon)
        export XDG_SESSION_DESKTOP=cinnamon
        export XDG_CURRENT_DESKTOP=X-Cinnamon
        ;;
    esac

    export XDG_SESSION_TYPE=wayland
    export GDK_BACKEND=wayland
    export QT_QPA_PLATFORM=wayland
    export NIXOS_OZONE_WL=1
    export ELECTRON_OZONE_PLATFORM_HINT=wayland

    ${gpuDevices}

    exec "$@"
  '';

  # X11 sessions get their own wrapper: greetd starts no X server, so startx
  # brings one up on the greeter's VT. The Wayland-only hints must not leak
  # into an X11 session, hence the unset.
  xsessionWrapper = pkgs.writeShellScript "x11-session" ''
    # Same as the Wayland wrapper: pull in XDG_DATA_DIRS/PATH first, then
    # drop the Wayland hints that /etc/profile (via home-manager's session
    # vars) just pulled in — they must not leak into an X11 session.
    . /etc/profile

    unset GDK_BACKEND QT_QPA_PLATFORM NIXOS_OZONE_WL ELECTRON_OZONE_PLATFORM_HINT
    export XDG_SESSION_TYPE=x11
    export XDG_SESSION_DESKTOP=cinnamon
    export XDG_CURRENT_DESKTOP=X-Cinnamon
    exec ${pkgs.xinit}/bin/startx "$@"
  '';
in {
  options.services.desktop.intelPrimaryDrm = lib.mkEnableOption ''
    explicit Wayland DRM device lists for an iGPU-scanned-out laptop whose
    external port is wired to the dGPU (Victus: no MUX, HDMI on the RTX 3050)
  '';

  config = {
    services = {
      gvfs.enable = true;

      gnome = {
        gnome-keyring.enable = true;
        # The Cinnamon module enables the GOA daemon by default; nothing here
        # uses online accounts, so turn it off with its panel app above.
        gnome-online-accounts.enable = false;
      };

      fstrim = {
        enable = true;
        interval = "daily";
      };
      fwupd.enable = true;

      logind.settings.Login = {
        HandlePowerKey = "ignore";
        HandleLidSwitch = lib.mkDefault "ignore";
        HandleLidSwitchExternalPower = lib.mkDefault "ignore";
        HandleLidSwitchDocked = lib.mkDefault "ignore";
      };

      greetd = {
        enable = true;
        settings = {
          default_session = {
            # Sessions come from /etc/wayland-sessions and /etc/xsessions so
            # hyprland's own hyprland-uwsm.desktop never appears as a broken
            # extra choice.
            command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --remember-session --sessions /etc/wayland-sessions --xsessions /etc/xsessions --session-wrapper ${sessionWrapper} --xsession-wrapper ${xsessionWrapper} --theme '${greeterTheme}'";
            user = "greeter";
          };
        };
      };

      # The Cinnamon module opts into the full Linux Mint application suite
      # (xed, pix, xviewer, xreader, celluloid, bulky, warpinator, gucharmap,
      # gnome-terminal, …). Every app the user actually wants is installed by
      # home-manager, so the Mint set is only menu clutter — turn it off.
      cinnamon.apps.enable = false;

      # Cinnamon is a desktopManager, not just a session script: the module
      # installs the DE (cinnamon-screensaver, settings daemons, nemo,
      # xdg-desktop-portal-xapp) and registers cinnamon's own session files.
      # Without it cinnamon-session dies on
      # "Unable to find required component 'org.cinnamon.ScreenSaver'".
      # greetd stays the display manager — its module is in the list that
      # keeps xserver from auto-enabling LightDM — and startx is the X server
      # the X11 session wrapper runs.
      xserver = {
        enable = true;
        displayManager.startx.enable = true;
        desktopManager.cinnamon.enable = true;

        # xterm is added unconditionally by the X server module; nothing here
        # launches it (foot is the terminal), so keep it out of the menu.
        excludePackages = [pkgs.xterm];
      };

      irqbalance.enable = false;
      bpftune.enable = false;

      # sched_ext: scx_bpfland prioritizes the interactive queue, which is the
      # laptop case (builds and containers churning while you type).
      scx-loader = {
        enable = true;
        config.default_sched = "scx_bpfland";
      };
    };

    # The sessions offered at greetd: Cinnamon on X11, Cinnamon on Wayland,
    # and Hyprland. Exec paths are absolute because the greeter's PATH is not
    # guaranteed.
    environment.etc = {
      "wayland-sessions/cinnamon.desktop".text = ''
        [Desktop Entry]
        Name=Cinnamon on Wayland (Experimental)
        Comment=Cinnamon desktop environment on Wayland
        Exec=${pkgs.cinnamon}/bin/cinnamon-session-cinnamon --wayland
        Type=Application
        DesktopNames=X-Cinnamon
        Keywords=desktop;cinnamon;wayland;
      '';

      "xsessions/cinnamon.desktop".text = ''
        [Desktop Entry]
        Name=Cinnamon
        Comment=Cinnamon desktop environment on X11
        Exec=${pkgs.cinnamon}/bin/cinnamon-session-cinnamon
        Type=Application
        DesktopNames=X-Cinnamon
        Keywords=desktop;cinnamon;x11;
      '';

      "wayland-sessions/hyprland.desktop".text = ''
        [Desktop Entry]
        Name=Hyprland
        Comment=An intelligent dynamic tiling Wayland compositor
        Exec=${config.programs.hyprland.package}/bin/start-hyprland
        Type=Application
        DesktopNames=Hyprland
        Keywords=tiling;wayland;compositor;
      '';
    };

    # Onboard (on-screen keyboard), blueman (Bluetooth Manager/Adapters) and
    # orca (screen reader) are the extras the Cinnamon module pulls that we do
    # not want; everything else in that list is a theme or a session
    # requirement. Excluding blueman only drops the applet — hardware.bluetooth
    # stays on.
    environment.cinnamon.excludePackages = [pkgs.onboard pkgs.blueman pkgs.orca];

    # gnome-online-accounts-gtk (the "Online Accounts" panel) is hard-coded
    # into the Cinnamon module's environment.systemPackages with no exclude
    # hook, so the package itself is replaced with an empty directory. It is
    # referenced nowhere else in nixpkgs, so nothing else loses it.
    nixpkgs.overlays = [
      (_final: prev: {
        gnome-online-accounts-gtk = prev.emptyDirectory;
      })
    ];

    # gvfs needs wsdd to browse the Windows Network neighbourhood.
    environment.systemPackages = [pkgs.wsdd];

    # tuigreet's --remember-session cache. `f` only writes when missing, so the
    # picked session survives reboots; `r` drops a stale free-form command.
    systemd.tmpfiles.rules = [
      "d /var/cache/tuigreet 0755 greeter greeter -"
      "f /var/cache/tuigreet/lastsession-path 0644 greeter greeter - /etc/xsessions/cinnamon.desktop"
      "r /var/cache/tuigreet/lastsession"
    ];

    services.upower = {
      enable = true;
      percentageLow = 20;
      percentageCritical = 5;
      percentageAction = 3;
      criticalPowerAction = "PowerOff";
    };

    zramSwap = {
      enable = true;
      algorithm = "zstd";
    };

    # oomd only acts on slices that opt in; kill the largest user process at 80%
    # pressure rather than locking up the whole desktop.
    systemd.oomd = {
      enable = true;
      enableUserSlices = true;
    };
  };
}
