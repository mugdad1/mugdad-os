# Seafile GUI client on laptops only (t480s + victus).
# The servers run a headless daemon instead (modules/core/seafile-client.nix);
# both sync the same "storage" library (renamed from "filen" on 2026-11-20).
{
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    seafile-client
    seafile-shared
  ];
}
