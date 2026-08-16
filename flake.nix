{
  description = "Linux-only Nix flake for the official ChatGPT desktop app";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs linuxSystems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: lib.getName pkg == "chatgpt-app";
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        rec {
          chatgpt-app = pkgs.callPackage ./pkgs/chatgpt-app/package.nix { };
          default = chatgpt-app;

          update-chatgpt-app = pkgs.writeShellApplication {
            name = "update-chatgpt-app";
            runtimeInputs = [
              pkgs.binutils
              pkgs.curl
              pkgs.gawk
              pkgs.gnutar
              pkgs.jq
              pkgs.nix
              pkgs.perl
              pkgs.xz
            ];
            text = builtins.readFile ./scripts/update-chatgpt-app;
          };
        }
      );

      apps = forAllSystems (system: {
        default = self.apps.${system}.chatgpt-app;
        chatgpt-app = {
          type = "app";
          program = lib.getExe self.packages.${system}.chatgpt-app;
          meta.description = "Run chatgpt-app";
        };
        update-chatgpt-app = {
          type = "app";
          program = lib.getExe self.packages.${system}.update-chatgpt-app;
          meta.description = "Update chatgpt-app release metadata";
        };
      });

      devShells = forAllSystems (system: {
        default =
          let
            pkgs = pkgsFor system;
          in
          pkgs.mkShell {
            packages = [
              self.packages.${system}.update-chatgpt-app
              pkgs.nixfmt
            ];
          };
      });

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
