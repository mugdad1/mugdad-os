# MeTube + Jellyfin — self-hosted "YouTube host" on grandpa.
# MeTube is a small yt-dlp web UI: paste a YouTube link, it downloads the
# video into /var/lib/media/downloads. Jellyfin serves that folder with proper
# phone/TV apps, so no flaky public Invidious instance is involved.
#
# Nothing secret is stored here: both apps start without accounts. Create the
# Jellyfin admin from its setup page on first visit.
{lib, pkgs, ...}: let
  metubePort = 8091;
  jellyfinPort = 8092;
  compose = ''
    name: media

    services:
      metube:
        image: ghcr.io/alexta69/metube:latest
        container_name: metube
        restart: unless-stopped
        ports:
          - "${toString metubePort}:8080"
        environment:
          UID: "1000"
          GID: "100"
          DOWNLOAD_DIR: /downloads
        volumes:
          - /var/lib/media/downloads:/downloads

      jellyfin:
        image: jellyfin/jellyfin:latest
        container_name: jellyfin
        restart: unless-stopped
        ports:
          - "${toString jellyfinPort}:8096"
        environment:
          TZ: Asia/Riyadh
        volumes:
          - /var/lib/media/jellyfin-config:/config
          - /var/lib/media/downloads:/media/videos:ro
          - /var/lib/media/cache:/cache
        devices:
          - /dev/dri:/dev/dri
  '';
in {
  environment.etc."media/docker-compose.yml".text = compose;

  systemd.services.media = {
    description = "MeTube + Jellyfin (Docker Compose)";
    wantedBy = ["multi-user.target"];
    after = ["docker.service" "network-online.target"];
    wants = ["docker.service" "network-online.target"];
    path = [pkgs.docker pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -o 1000 -g 100 /var/lib/media/downloads
      install -d -o 1000 -g 100 /var/lib/media/jellyfin-config
      install -d -o 1000 -g 100 /var/lib/media/cache
      docker compose --project-directory /etc/media -f /etc/media/docker-compose.yml up -d
    '';
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
    metubePort
    jellyfinPort
  ];
}
