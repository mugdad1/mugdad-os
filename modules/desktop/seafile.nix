# Seafile on laptops only (t480s + victus): GUI client plus the CLI daemon
# that keeps ~/filen synced with the "filen" library on grandpa.
# The library id is public metadata; the auth token lives only in the
# client's own config under the user's home (written by `seaf-cli sync`).
{
  lib,
  pkgs,
  host,
  username,
  ...
}: {
  environment.systemPackages = with pkgs; [
    seafile-client
    seafile-shared
  ];

  systemd.services.seafile-filen-sync = lib.mkIf (host == "victus") {
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
      ExecStart = "${pkgs.seafile-shared}/bin/seaf-daemon -c /home/${username}/.seafile-cli -d /home/${username}/.seafile-cli-data/seafile-data -w /home/${username}/.seafile-cli-data/seafile";
      Restart = "on-failure";
      RestartSec = 10;
    };
    wantedBy = ["multi-user.target"];
  };
}
