{
  description = "Prismarine: a modern home for your Prism Launcher library";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      packages = forAllSystems (pkgs: {
        prismarine = pkgs.callPackage ./packaging/nix/package.nix { };
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.prismarine;
      });

      checks = forAllSystems (pkgs: {
        inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) prismarine;
      });

      overlays.default = final: _prev: {
        prismarine = final.callPackage ./packaging/nix/package.nix { };
      };

      nixosModules.default = { pkgs, lib, ... }: {
        imports = [ ./packaging/nix/module.nix ];
        programs.prismarine.package = lib.mkDefault (
          pkgs.callPackage ./packaging/nix/package.nix { }
        );
      };

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ self.packages.${pkgs.stdenv.hostPlatform.system}.prismarine ];
        };
      });
    };
}
