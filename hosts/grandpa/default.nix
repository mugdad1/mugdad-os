# grandpa — headless server: Intel i3-2120, 6 GiB RAM, one 298 GiB HDD, no
# discrete GPU. Imports modules/core only; never modules/desktop.
{
  pkgs,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    # A directory module loads its default.nix only, so every sibling below
    # must be listed explicitly.
    ./packages.nix
    ./overrides.nix
    ./router-reboot.nix
    ./home-assistant.nix
    ./services.nix
  ];

  boot.loader.efi.efiSysMountPoint = "/boot";

  # Literal-IP NTP so the clock can be fixed even when DNS is down.
  services.timesyncd.enable = true;
  networking.timeServers = [
    "162.159.200.1" # time.cloudflare.com
    "216.239.35.0" # time.google.com
    "216.239.35.4"
  ];

  # Slow spinning disk and 6 GiB RAM: compressed RAM swap beats a swap file.
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 35;
    priority = 100;
  };

  # Forgejo, gitea-mirror and SearXNG moved to asus on 2026-11-18. Their data
  # was moved with them; no port or unit for them remains on this host.

  # Docker engine stays installed; the compose stack it used to run is gone.
  virtualisation.docker.enable = true;
  users.users.${username}.extraGroups = ["docker"];

  # The service index: nginx on :80 over the tailnet, rendered from
  # lib/server-index.nix so a rebuild is the publish.
  services.nginx = {
    enable = true;
    virtualHosts.index = {
      default = true;
      root = pkgs.writeTextDir "index.html" (import ../../lib/server-index.nix {});
      extraConfig = "index index.html;";
    };
  };
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [80];
}
