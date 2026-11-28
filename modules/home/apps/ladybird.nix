{
  pkgs,
  lib,
  ...
}: let
  # Ladybird keeps its profile in ~/.config/Ladybird/Profiles/default/:
  # Settings.json (all preferences) and Bookmarks.json.
  #
  # The keys below are owned by Nix and deep-merged into Settings.json on every
  # activation, so changing a choice here and rebuilding actually changes the
  # browser. Everything we do not name — window size, per-host zoom, session
  # state, new content-blocker toggles — is left to the browser, so the merge
  # never wipes it. His word 2026-11-28: "have our own chosices nix pilled".
  settings = {
    # Skip the first-run tour; we are not a new user.
    firstRunComplete = true;
    # The index page (lib/server-index.nix, served by nginx on grandpa).
    newTabPageURL = "http://100.106.116.60/";
    restorePreviousSession = false;
    languages = ["en-US" "en"];

    appearance = {
      showMenuBar = false;
      showBookmarksBar = "always";
      interfaceTheme = "dark";
      websiteColorScheme = "dark";
    };

    content = {
      defaultZoomLevelFactor = 1;
      # Respect a site's own light mode instead of force-darkening it.
      enableForceDark = false;
    };

    tabs.verticalTabsEnabled = false;

    browsingBehavior = {
      enableAutoscroll = true;
      enablePrimaryPaste = true;
    };

    # SearXNG on asus — the same instance the old Zen profile used
    # (lib/server-index.nix).
    # Ladybird has no built-in entry for it, so it goes in as a custom engine;
    # the autocompleter speaks OpenSearch, which is Ladybird's default format.
    searchEngine = {
      custom = [
        {
          name = "SearXNG";
          url = "http://100.92.54.61:8888/search?q=%s";
          suggestionsUrl = "http://100.92.54.61:8888/autocompleter?q=%s";
        }
      ];
      engine = "SearXNG";
      suggestions = true;
    };

    autoplay.policy = "block-audio";
    locationPolicy = "ask";

    # Privacy choices carried over from the old Zen profile.
    globalPrivacyControl = true;
    backgroundNetworking = {
      enabled = true;
      features.contentBlockerSubscriptionUpdates = true;
    };
    contentBlockers = {
      enabled = true;
      builtInLists = {
        easyList = true;
        easyPrivacy = true;
        easyListCookie = true;
      };
    };
  };

  settingsFile = pkgs.writeText "ladybird-settings.json" (builtins.toJSON settings);

  # Bookmarks are seeded once, then the file is yours: the activation only
  # writes it when it is missing, so anything you add in the UI survives.
  bookmarks = {
    version = 2;
    items = [
      {
        id = "00000000-0000-4000-8000-000000000001";
        dateAdded = 1795869584291;
        lastModified = 1795869584291;
        type = "bookmark";
        url = "http://100.106.116.60/";
        title = "mugdad — Server";
      }
      {
        id = "00000000-0000-4000-8000-000000000002";
        dateAdded = 1795869584291;
        lastModified = 1795869584291;
        type = "bookmark";
        url = "http://100.92.54.61:8091/";
        title = "Study";
      }
      {
        id = "00000000-0000-4000-8000-000000000003";
        dateAdded = 1795869584291;
        lastModified = 1795869584291;
        type = "bookmark";
        url = "http://100.92.54.61:8888/";
        title = "SearXNG";
      }
      {
        id = "00000000-0000-4000-8000-000000000004";
        dateAdded = 1795869584291;
        lastModified = 1795869584291;
        type = "bookmark";
        url = "https://ladybird.org/";
        title = "Ladybird";
      }
    ];
  };

  bookmarksFile = pkgs.writeText "ladybird-bookmarks.json" (builtins.toJSON bookmarks);
in {
  # Ladybird is the browser — Zen was removed on 2026-11-28 ("rm zen browser
  # lady is the one"). It is also the default web handler (apps/xdg.nix).
  # Upstream's official AppImage, not pkgs.ladybird: nixpkgs' source snapshot
  # lags upstream releases by weeks and the bump needs an unreleased PR plus a
  # long C++ build. See pkgs/ladybird-bin.nix; `mcli update` refreshes the pin.
  home.packages = [(pkgs.callPackage ../../../pkgs/ladybird-bin.nix {})];

  home.activation.ladybirdProfile = lib.hm.dag.entryAfter ["writeBoundary"] ''
    P="$HOME/.config/Ladybird/Profiles/default"
    S="$P/Settings.json"
    B="$P/Bookmarks.json"
    run mkdir -p "$P"

    # Deep-merge: our keys win, every other key in the live profile survives.
    if [ -f "$S" ] && ${pkgs.jq}/bin/jq -e . "$S" >/dev/null 2>&1; then
      tmp="$(mktemp)"
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$S" ${settingsFile} > "$tmp"
      run install -m 600 "$tmp" "$S"
      rm -f "$tmp"
    else
      run install -m 600 ${settingsFile} "$S"
    fi

    if [ ! -f "$B" ]; then
      run install -m 600 ${bookmarksFile} "$B"
    fi
  '';
}
