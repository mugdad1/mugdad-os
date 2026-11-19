# Seafile GUI client on laptops only (t480s + victus).
# The ~/filen -> Seafile bridge runs on grandpa (modules/core/seafile-sync.nix).
{
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    seafile-client
    seafile-shared
  ];
}
