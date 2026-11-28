{pkgs, ...}: {
  imports = [
    ./battery-charge-limit.nix
    ./hardware-configuration.nix
    ./waydroid.nix
    ../../modules/core
    ../../modules/desktop
  ];

  # Standard hybrid (Optimus) laptop: the panel is wired to the Intel iGPU and
  # HDMI to the NVIDIA dGPU, with no MUX. X runs on the iGPU and offloads
  # rendering to the dGPU on demand via `nvidia-offload`.
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    open = true;
    modesetting.enable = true;

    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Decode on the Intel iGPU.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    intel-compute-runtime
  ];

  boot.kernelParams = [
    "nowatchdog"
    "psi=1"
    "rootflags=noatime"
    # USB enumeration on the Type-C port fails for some low-speed devices.
    "usbcore.old_scheme_first=1"
    "usbcore.use_both_schemes=1"
    "usbcore.initial_descriptor_timeout=10000"
    "usbcore.autosuspend=-1"
  ];

  services.throttled.enable = false;
  services.tlp.enable = false;
  services.power-profiles-daemon.enable = true;

  # HP's own ACPI charge-mode methods, not TLP thresholds.
  # Re-enabled 2026-11-28 after the pack was reconnected; disabled 2026-11-27
  # only because ACPI reported `BAT0` absent and the daemon logged
  # `BAT0/capacity is missing` every 60 s.
  services.victus.batteryChargeLimit = {
    enable = true;
    stopAt = 85;
    resumeAt = 82;
  };

  environment.systemPackages = [
    pkgs.nvtopPackages.full
    pkgs.tmux
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "suspend";
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };
}
