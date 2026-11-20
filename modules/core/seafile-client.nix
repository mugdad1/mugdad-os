# seafile-client — headless two-way sync of the "storage" library into
# ~/seafile. Servers only (grandpa, asus): a desktop has no need for a second
# daemon when the GUI client in modules/desktop/seafile.nix can do it.
#
# The login token lives in ~/.seafile-cli, never in this repo. Bootstrap once
# per host (seaf-cli init/login/sync); after that this unit keeps the daemon
# running and the folder syncing.
{
  lib,
  pkgs,
  host,
  username,
  ...
}:
lib.mkIf (host == "grandpa" || host == "asus") {
  environment.systemPackages = [pkgs.seafile-shared];

  systemd.services.seafile-client = {
    description = "Seafile client daemon (headless, ~/seafile)";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    unitConfig.ConditionPathExists = ["/home/${username}/.seafile-cli/seafile.ini"];
    serviceConfig = {
      Type = "simple";
      User = username;
      Environment = [
        "HOME=/home/${username}"
        "USER=${username}"
        "LOGNAME=${username}"
      ];
      ExecStart = "${pkgs.seafile-shared}/bin/seaf-daemon -c /home/${username}/.seafile-cli -d /home/${username}/.seafile-cli-data/seafile-data -w /home/${username}/.seafile-cli-data/seafile";
      Restart = "on-failure";
      RestartSec = 10;
    };
    wantedBy = ["multi-user.target"];
  };
}
