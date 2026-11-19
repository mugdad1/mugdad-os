# Invidious — self-hosted YouTube front end + API, tailnet only (:8091).
# Replaces the rejected MeTube + Jellyfin stack (2026-11-19, decisions row 270).
#
# Three containers: the app, PostgreSQL 14, and invidious-companion. Companion
# is mandatory for playback — it replaced inv-sig-helper and
# youtube-trusted-session-generator. Upstream's compose also mounts its SQL
# files and init script into postgres, so both are vendored from the pinned tag
# under ./invidious-sql instead of cloning the repo on the host.
#
# No `logging.options` here: upstream's example assumes the json-file driver,
# but this host's daemon logs to journald, which rejects max-size/max-file.
#
# No secret lives in the repo: /etc/invidious/invidious.env is generated on
# first start, mode 0600, with the DB password, HMAC key and companion key.
# Read them with: sudo cat /etc/invidious/invidious.env
{lib, pkgs, ...}: let
  port = 8091;
  sqlDir = ./invidious-sql;
  compose = ''
    name: invidious

    services:
      invidious:
        image: quay.io/invidious/invidious:2.20261114.0
        container_name: invidious
        restart: unless-stopped
        ports:
          - "${toString port}:3000"
        environment:
          INVIDIOUS_CONFIG: |
            db:
              user: kemal
              password: ''${INVIDIOUS_DB_PASSWORD}
              host: postgres
              port: 5432
              dbname: invidious
            check_tables: true
            hmac_key: ''${INVIDIOUS_HMAC_KEY}
            invidious_companion:
              - private_url: "http://companion:8282/companion"
            invidious_companion_key: ''${INVIDIOUS_COMPANION_KEY}
            domain: ""
            https_only: false
        healthcheck:
          test: wget -nv --tries=1 --spider http://127.0.0.1:3000/api/v1/stats || exit 1
          interval: 30s
          timeout: 5s
          retries: 2
        depends_on:
          postgres:
            condition: service_healthy
          companion:
            condition: service_started

      companion:
        image: quay.io/invidious/invidious-companion:2026.11.07-07ae73c
        container_name: companion
        restart: unless-stopped
        environment:
          SERVER_SECRET_KEY: ''${INVIDIOUS_COMPANION_KEY}
        volumes:
          - companioncache:/var/tmp/youtubei.js:rw
        cap_drop:
          - ALL
        read_only: true
        security_opt:
          - no-new-privileges:true

      postgres:
        image: docker.io/library/postgres:14
        container_name: invidious-postgres
        restart: unless-stopped
        volumes:
          - postgresdata:/var/lib/postgresql/data
          - /etc/invidious/sql:/config/sql:ro
          - /etc/invidious/init-invidious-db.sh:/docker-entrypoint-initdb.d/init-invidious-db.sh:ro
        environment:
          POSTGRES_DB: invidious
          POSTGRES_USER: kemal
          POSTGRES_PASSWORD: ''${INVIDIOUS_DB_PASSWORD}
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
          interval: 10s
          timeout: 5s
          retries: 5

    volumes:
      postgresdata:
      companioncache:
  '';
in {
  environment.etc."invidious/docker-compose.yml".text = compose;
  environment.etc."invidious/sql".source = sqlDir;
  environment.etc."invidious/init-invidious-db.sh".source = sqlDir + "/init-invidious-db.sh";

  systemd.services.invidious = {
    description = "Invidious + companion + PostgreSQL (Docker Compose)";
    wantedBy = ["multi-user.target"];
    after = ["docker.service" "network-online.target"];
    wants = ["docker.service" "network-online.target"];
    path = [pkgs.docker pkgs.openssl pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -f /etc/invidious/invidious.env ]; then
        umask 077
        db_pass=$(openssl rand -hex 24)
        hmac_key=$(openssl rand -hex 16)
        # Companion rejects anything that is not exactly 16 characters.
        companion_key=$(openssl rand -hex 8)
        printf 'INVIDIOUS_DB_PASSWORD=%s\nINVIDIOUS_HMAC_KEY=%s\nINVIDIOUS_COMPANION_KEY=%s\n' \
          "$db_pass" "$hmac_key" "$companion_key" > /etc/invidious/invidious.env
        chmod 600 /etc/invidious/invidious.env
        echo "Invidious: generated secrets at /etc/invidious/invidious.env (0600)"
      fi
      set -a
      . /etc/invidious/invidious.env
      set +a
      docker compose --project-directory /etc/invidious -f /etc/invidious/docker-compose.yml up -d
    '';
  };

  # Upstream: "Invidious must be restarted often, at least once a day, ideally
  # every hour." A crashed container's restart policy does not clear a poisoned
  # YouTube/PO-Token session; a scheduled restart does.
  systemd.services.invidious-restart = {
    description = "Restart Invidious and companion (YouTube session refresh)";
    after = ["invidious.service"];
    wants = ["invidious.service"];
    path = [pkgs.docker pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      set -a
      . /etc/invidious/invidious.env
      set +a
      docker compose --project-directory /etc/invidious -f /etc/invidious/docker-compose.yml restart invidious companion
    '';
  };

  systemd.timers.invidious-restart = {
    description = "Hourly Invidious + companion restart";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "hourly";
      AccuracySec = "5min";
      # A missed restart is skipped, never caught up in a burst.
      Persistent = false;
      Unit = "invidious-restart.service";
    };
  };

  # Direct tailnet HTTP: no public domain, no TLS cert, no reverse proxy.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [port];
}
