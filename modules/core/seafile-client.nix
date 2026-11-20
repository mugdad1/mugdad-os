# seafile-client — headless two-way sync of the "storage" library into
# ~/seafile on every host, servers and laptops alike. There is no GUI client
# in the fleet: the same daemon and the same CLI run everywhere, so every
# machine holds the identical library at the same path.
#
# The login token lives in ~/.seafile-cli, never in this repo. Bootstrap once
# per host (seaf-cli init/login/sync); after that this unit keeps the daemon
# running and the folder syncing.
{
  pkgs,
  username,
  ...
}: {
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
