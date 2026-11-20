# SearXNG — the house search engine, declared natively (no docker). Moved here
# from grandpa 2026-11-18; browsers and the `web-search` helper point at :8888.
_: {
  services.searx = {
    enable = true;

    settings = {
      use_default_settings = true;

      server = {
        port = 8888;
        bind_address = "0.0.0.0";
        base_url = "http://100.92.54.61:8888/";
        # Only signs session cookies on a tailnet-only instance; not a
        # credential. Rotate by changing this string and restarting searx.
        secret_key = "searxng-cookie-signing-key-please-rotate";
        limiter = false;
        image_proxy = true;
      };

      # html for people, json for scripts hitting /search.
      search.formats = ["html" "json"];

      ui.static_use_hash = true;
    };
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [8888];
}
