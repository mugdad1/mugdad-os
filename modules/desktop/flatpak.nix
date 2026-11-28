{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  # nix-flatpak's install unit runs with no session bus, which makes flatpak
  # die with "Cannot autolaunch D-Bus without X11 $DISPLAY" on first install.
  # Reuse the module's own script, wrapped in a private session bus.
  managedInstallScript = import "${inputs.nix-flatpak.outPath}/modules/script/flatpak-managed-install.nix" {
    inherit pkgs lib;
    cfg = config.services.flatpak;
    installation = "system";
    executionContext = "service-start";
  };

  managedInstallWithBus = pkgs.writeShellScript "flatpak-managed-install-with-session-bus" ''
    export PATH="${pkgs.dbus}/bin:$PATH"
    exec ${pkgs.dbus}/bin/dbus-run-session ${managedInstallScript}
  '';

  # Flatpak only mounts the GL runtime whose version matches the host driver
  # (org.freedesktop.Platform.GL.nvidia-<driver with dots as dashes>). Derive
  # the ref from the branch we actually run instead of pinning it by hand, so a
  # driver bump picks up the matching runtime on the next switch. Without it the
  # sandbox has no NVIDIA libs and every flatpak renders on the iGPU.
  nvidiaGlRuntime = "org.freedesktop.Platform.GL.nvidia-${
    lib.replaceStrings ["."] ["-"] config.hardware.nvidia.package.version
  }";
in {
  imports = [inputs.nix-flatpak.nixosModules.nix-flatpak];

  systemd.services.flatpak-managed-install.serviceConfig.ExecStart =
    lib.mkForce "${managedInstallWithBus}";

  # Runtime refs are not covered by services.flatpak.packages (that only takes
  # applications), so the NVIDIA GL runtime is installed here. It fails loudly
  # when flathub has not published the ref for a brand-new driver yet.
  systemd.services.flatpak-nvidia-gl = lib.mkIf config.hardware.nvidia.prime.offload.enable {
    description = "Install the flatpak NVIDIA GL runtime matching the host driver";
    # Same target as flatpak-managed-install, which itself runs before
    # graphical.target: install -> runtime -> graphical. WantedBy =
    # multi-user.target would close an ordering cycle, because that service is
    # ordered after multi-user.target.
    wantedBy = ["graphical.target"];
    before = ["graphical.target"];
    wants = ["network-online.target"];
    after = ["network-online.target" "flatpak-managed-install.service"];
    # network-online.target can be reached before wifi has associated and before
    # blocky has an upstream, so the first attempt may die on DNS. Retry for a
    # while instead of leaving the unit failed until the next rebuild.
    unitConfig = {
      StartLimitBurst = 10;
      StartLimitIntervalSec = "15min";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStartSec = "6min";
    };
    # `network-online.target` only means an IP link exists: on this box wifi
    # associates and blocky gets its upstream later, so flatpak can still die
    # with "Could not resolve hostname". Most boots only need the already
    # installed runtime, so check locally first and never touch the network.
    # When a real install is needed, wait for DNS before invoking flatpak.
    script = ''
      runtime="${nvidiaGlRuntime}"
      if ${pkgs.flatpak}/bin/flatpak info --system "$runtime" >/dev/null 2>&1; then
        echo "Skipping: $runtime is already installed"
        exit 0
      fi

      for attempt in $(seq 1 60); do
        if getent ahosts dl.flathub.org >/dev/null 2>&1; then
          exec ${pkgs.flatpak}/bin/flatpak install --system --noninteractive flathub "$runtime"
        fi
        sleep 5
      done

      echo "DNS for dl.flathub.org never came up; $runtime was not installed" >&2
      exit 1
    '';
  };

  services.flatpak = {
    enable = true;
    overrides = {
      global = {
        # Both sessions are supported: Hyprland is Wayland, but Cinnamon is
        # offered on X11 (modules/desktop/sessions.nix) and Flatpak apps have
        # no XWayland to fall back to there. Denying x11 made every Flatpak
        # window fail to open in that session.
        Context.sockets = [
          "wayland"
          "fallback-x11"
          "x11"
        ];
      };
    };
  };
}
