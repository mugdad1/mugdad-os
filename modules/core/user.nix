{
  pkgs,
  lib,
  inputs,
  username,
  host,
  variables,
  ...
}: {
  imports = [inputs.home-manager.nixosModules.home-manager];
  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    extraSpecialArgs = {inherit inputs username host variables;};
    users.${username} = {
      # The desktop home stack requires variables.browser/terminal/launcher, so
      # headless hosts do not declare them. They still get the git config:
      # importing the whole home tree here would drag in the desktop stack.
      imports =
        (lib.optionals (variables ? browser) [../home])
        ++ (lib.optionals (!(variables ? browser)) [../home/apps/git.nix]);
      home.username = username;
      home.homeDirectory = "/home/${username}";
      home.stateVersion = "26.05";
      programs.home-manager.enable = true;
    };
    backupFileExtension = "hm-backup";
  };

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "video"
      "render"
    ];
    shell = pkgs.fish;
  };
  nix.settings.allowed-users = [username];
}
