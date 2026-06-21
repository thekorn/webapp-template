{
  description = "Development and run environment for sample-project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = function:
        nixpkgs.lib.genAttrs systems (system:
          function system (import nixpkgs {
            inherit system;
          })
        );
    in
    {
      devShells = forAllSystems (_system: pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            bun
            git
          ];

          shellHook = ''
            echo "sample-project dev shell"
            echo "Run 'bun install' once, then 'bun run dev' to start the development services."
          '';
        };
      });

      packages = forAllSystems (_system: pkgs: {
        default = pkgs.writeShellApplication {
          name = "sample-project";
          runtimeInputs = with pkgs; [
            bun
            coreutils
          ];

          text = ''
            if [ ! -f package.json ] || [ ! -f bun.lock ]; then
              echo "nix run must be started from the sample-project checkout" >&2
              exit 1
            fi

            if [ ! -d node_modules ]; then
              bun install --frozen-lockfile
            fi

            if [ "''${SAMPLE_PROJECT_SKIP_BUILD:-0}" != "1" ]; then
              bun run clean
              NODE_ENV=production bun run build:web
              bun run build:server
              bun run build:css
            fi

            exec bun run start
          '';
        };
      });

      apps = forAllSystems (system: _pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/sample-project";
          meta.description = "Build and run sample-project from the current checkout";
        };
      });
    };
}
