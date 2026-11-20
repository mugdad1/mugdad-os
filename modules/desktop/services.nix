# Desktop *services* as opposed to the session/greeter wiring in sessions.nix.
{
  pkgs,
  lib,
  ...
}: {
  config = {
    services = {
      gvfs.enable = true;

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

      irqbalance.enable = false;
      bpftune.enable = false;

      # sched_ext: scx_bpfland prioritizes the interactive queue, which is the
      # laptop case (builds and containers churning while you type).
      scx-loader = {
        enable = true;
        config.default_sched = "scx_bpfland";
      };

      upower = {
        enable = true;
        percentageLow = 20;
        percentageCritical = 5;
        percentageAction = 3;
        criticalPowerAction = "PowerOff";
      };
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
