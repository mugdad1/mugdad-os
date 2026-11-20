{
  description = "mugdad's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {nixpkgs, ...} @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    mkHost = host: let
      variables = import ./hosts/${host}/variables.nix;
    in
      nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/${host}
        ];
        specialArgs = {
          inherit host inputs variables;
          inherit (variables) username;
        };
      };
  in {
    formatter.${system} = pkgs.alejandra;

    devShells.${system} = {
      default = pkgs.mkShell {
        packages = with pkgs; [
          alejandra
          statix
          deadnix
          shellcheck
          shfmt
          treefmt
          stylua
          taplo
          nixd
        ];
      };

      kernel = pkgs.mkShell {
        packages = with pkgs; [
          gnumake
          gcc
          linuxPackages_latest.kernel.dev
        ];
        shellHook = ''
          export KDIR="${pkgs.linuxPackages_latest.kernel.dev}/lib/modules/${pkgs.linuxPackages_latest.kernel.dev.version}/build"
          echo "Kernel dev shell ready"
          echo "Kernel: $(uname -r)"
          echo "KDIR: $KDIR"
        '';
      };
    };

    # `nix flake check` fails on lint/format drift. The source is copied
    # because the store path is read-only and treefmt/statix may want to touch
    # files; treefmt.toml and statix.toml exclude generated hardware configs.
    checks.${system} = {
      lint =
        pkgs.runCommand "lint" {
          nativeBuildInputs = with pkgs; [
            alejandra
            deadnix
            statix
            treefmt
            shfmt
            stylua
            taplo
          ];
        } ''
          cp -r ${./.} work
          chmod -R u+w work
          cd work
          # treefmt keeps an eval cache under $HOME; the sandbox has none.
          export HOME=$TMPDIR
          treefmt --fail-on-change
          statix check .
          deadnix --fail --exclude 'hosts/*/hardware-configuration.nix' .
          touch $out
        '';
    };

    nixosConfigurations = {
      t480s = mkHost "t480s";
      victus = mkHost "victus";
      grandpa = mkHost "grandpa";
      asus = mkHost "asus";
    };
  };
}
