# Seafile — open-source Filen alternative: central server, web UI, and
# desktop + Android/iOS sync clients. NixOS removed services.seafile in 25.11
# (unmaintained), so the official image runs under Docker, already enabled here.
#
# No secret lives in the repo: /etc/seafile/seafile.env is generated on first
# start, mode 0600, with a random MariaDB root password and admin password.
# Read them with: sudo cat /etc/seafile/seafile.env
{pkgs, ...}: let
  port = 8090;
  compose = ''
    name: seafile

    services:
      db:
        image: mariadb:10.11
        container_name: seafile-mysql
        restart: unless-stopped
        environment:
          MYSQL_ROOT_PASSWORD: ''${SEAFILE_DB_PASSWORD}
          MYSQL_LOG_CONSOLE: "true"
        volumes:
          - /var/lib/seafile/mysql:/var/lib/mysql
        networks: [seafile-net]

      memcached:
        image: memcached:1.6
        container_name: seafile-memcached
        restart: unless-stopped
        entrypoint: memcached -m 256
        networks: [seafile-net]

      seafile:
        image: seafileltd/seafile-mc:latest
        container_name: seafile
        restart: unless-stopped
        ports:
          - "${toString port}:80"
        volumes:
          - /var/lib/seafile/data:/shared
        # seahub refuses to start if pids/seahub.pid names a dead process, and
        # that file lives in the container's writable layer, which survives a
        # `restart: unless-stopped`. An unclean shutdown therefore left the web
        # UI answering 502 until the pid was removed by hand (2026-11-21).
        # Runtime pids belong in tmpfs: a fresh container always starts clean.
        tmpfs:
          - /opt/seafile/pids
        # Watch seahub, not nginx: nginx stays up when gunicorn is dead, which
        # is how the 502 above stayed invisible.
        healthcheck:
          test: ["CMD-SHELL", "curl -fsS -o /dev/null http://127.0.0.1:8000/ || exit 1"]
          interval: 30s
          timeout: 5s
          retries: 3
          start_period: 120s
        environment:
          DB_HOST: db
          DB_ROOT_PASSWD: ''${SEAFILE_DB_PASSWORD}
          TIME_ZONE: Asia/Riyadh
          SEAFILE_ADMIN_EMAIL: mugdad02@tutamail.com
          SEAFILE_ADMIN_PASSWORD: ''${SEAFILE_ADMIN_PASSWORD}
          SEAFILE_SERVER_HOSTNAME: 100.106.116.60:${toString port}
        depends_on: [db, memcached]
        networks: [seafile-net]

    networks:
      seafile-net:
  '';
in {
  environment.etc."seafile/docker-compose.yml".text = compose;

  systemd.services.seafile = {
    description = "Seafile file sync (Docker Compose)";
    wantedBy = ["multi-user.target"];
    after = ["docker.service" "network-online.target"];
    wants = ["docker.service" "network-online.target"];
    path = [pkgs.docker pkgs.openssl pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -f /etc/seafile/seafile.env ]; then
        umask 077
        db_pass=$(openssl rand -hex 24)
        admin_pass=$(openssl rand -base64 18 | tr -d '/+=')
        printf 'SEAFILE_DB_PASSWORD=%s\nSEAFILE_ADMIN_PASSWORD=%s\n' "$db_pass" "$admin_pass" > /etc/seafile/seafile.env
        echo "Seafile: generated credentials at /etc/seafile/seafile.env (0600)"
      fi
      set -a
      . /etc/seafile/seafile.env
      set +a
      docker compose --project-directory /etc/seafile -f /etc/seafile/docker-compose.yml up -d
    '';
  };

  # Web UI is on the tailnet only, like the rest of grandpa's pages.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [port];
}
