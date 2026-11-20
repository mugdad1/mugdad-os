# Seafile GUI client on laptops only (t480s + victus).
# The servers run a headless daemon instead (modules/core/seafile-client.nix);
# both sync the same "filen" library, laptops to ~/seafile.
{
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    seafile-client
    seafile-shared
  ];
}
