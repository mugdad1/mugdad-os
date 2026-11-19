# seafile-sync — the single host that bridges Filen -> Seafile.
# grandpa also runs filen-sync (Filen cloud <-> ~/filen); this daemon takes
# that same folder and syncs it into the "filen" library on the Seafile server
# running on grandpa. The library id is public metadata; the auth token lives
# only in ~/.seafile-cli under the user's home, never in this repo.
{
  lib,
  pkgs,
  host,
  username,
  ...
}:
lib.mkIf (host == "grandpa") {
  systemd.services.seafile-filen-sync = {
    description = "Seafile CLI sync for ~/filen";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    unitConfig.ConditionPathExists = [
      "/home/${username}/.seafile-cli/seafile.ini"
      "/home/${username}/filen"
    ];
    serviceConfig = {
      Type = "simple";
      User = username;
      Environment = [
        "HOME=/home/${username}"
        "USER=${username}"
        "LOGNAME=${username}"
      ];
      # Loopback: the Seafile server runs in Docker on this same host.
      ExecStart = "${pkgs.seafile-shared}/bin/seaf-daemon -c /home/${username}/.seafile-cli -d /home/${username}/.seafile-cli-data/seafile-data -w /home/${username}/.seafile-cli-data/seafile";
      Restart = "on-failure";
      RestartSec = 10;
    };
    wantedBy = ["multi-user.target"];
  };
}
