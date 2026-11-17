# filen-sync — periodic two-way bisync of the Filen drive root into ~/filen.
# Servers only (grandpa, asus): the laptops carry no filen CLI.
# Credentials come from the filen CLI's own login state in the user's home
# (`filen login` once); nothing secret is declared in Nix.
{
  lib,
  pkgs,
  host,
  username,
  ...
}: let
  filenSync = pkgs.writeShellApplication {
    name = "filen-sync";
    runtimeInputs = [
      (pkgs.callPackage ../../pkgs/filen-cli.nix {})
      pkgs.coreutils
    ];
    text = ''
      state="$HOME/.cache/rclone/bisync/filen_..home_mugdad_filen.path1.lst"
      args=(bisync "filen:" "$HOME/filen")

      if [ ! -f "$state" ]; then
        echo "[filen-sync] no baseline at $state — establishing it with --resync"
        args+=(--resync)
      fi

      exec filen --skip-update rclone "''${args[@]}"
    '';
  };
in
  lib.mkIf (host == "grandpa" || host == "asus") {
    systemd.services.filen-sync = {
      description = "Two-way bisync: Filen drive root <-> ~/filen";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      unitConfig = {
        # Skip cleanly until ~/filen exists instead of failing the rebuild.
        ConditionPathExists = "/home/${username}/filen";
      };
      serviceConfig = {
        Type = "oneshot";
        User = username;
        Environment = [
          "HOME=/home/${username}"
          "USER=${username}"
          "LOGNAME=${username}"
        ];
        ExecStart = "${filenSync}/bin/filen-sync";
        TimeoutStartSec = "60min";
      };
    };

    systemd.timers.filen-sync = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = "30min";
        AccuracySec = "1min";
      };
    };
  }
