# opencode's MCP servers and search policy. This lives in modules/core, not
# modules/home, because every host runs opencode (it is in
# modules/core/packages.nix) while only the desktops import the home stack.
#
# Nothing secret enters the store: the repository is public. SearXNG needs no
# credential at all, and the MCP server is a local stdio process — the store
# path below keeps it alive across garbage collection.
{
  pkgs,
  username,
  ...
}: let
  # SearXNG moved from grandpa to asus on 2026-11-18. This is the address the
  # MCP server queries over the tailnet.
  searxngUrl = "http://100.92.54.61:8888";
in {
  home-manager.users.${username} = {
    xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";

      # The built-in search providers (exa, firecrawl, parallel, tavily,
      # tinyfish) are third parties and none can point at a SearXNG instance.
      # Turning the tool off removes the choice: the agent searches with the
      # `searxng` MCP server below, which talks to our own instance.
      websearch = false;

      mcp.servers = {
        searxng = {
          type = "local";
          command = ["${pkgs.mcp-searxng}/bin/mcp-searxng"];
          environment.SEARXNG_URL = searxngUrl;
        };
      };
    };
  };
}
