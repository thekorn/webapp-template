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

      pname = "sample-project";
      version = "0.0.0";

      dependencySource = pkgs:
        pkgs.lib.cleanSourceWith {
          src = self;
          filter = path: _type:
            let
              name = baseNameOf path;
            in
            name == "package.json" || name == "bun.lock";
        };

      packageFor = system: pkgs:
        let
          bunDeps = pkgs.stdenvNoCC.mkDerivation {
            pname = "${pname}-bun-deps";
            inherit version;

            src = dependencySource pkgs;

            nativeBuildInputs = [ pkgs.bun ];

            dontConfigure = true;

            buildPhase = ''
              runHook preBuild

              export HOME=$TMPDIR
              bun install --frozen-lockfile --no-progress

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p $out
              cp -R node_modules $out/node_modules

              runHook postInstall
            '';

            outputHashAlgo = "sha256";
            outputHashMode = "recursive";
            outputHash = "sha256-LWCWf3e/Xy+72/2QP8kaou9/iPsHcxOFAeT8UrKIhHU=";
          };
        in
        pkgs.stdenvNoCC.mkDerivation {
          inherit pname version;

          src = pkgs.lib.cleanSource self;

          nativeBuildInputs = with pkgs; [
            bun
            makeWrapper
          ];

          dontConfigure = true;

          buildPhase = ''
            runHook preBuild

            export HOME=$TMPDIR
            cp -R ${bunDeps}/node_modules node_modules
            chmod -R u+w node_modules

            NODE_ENV=production bun run build:web
            bun run build:server
            bun run build:css

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/${pname} $out/bin
            cp -R dist $out/share/${pname}/dist
            makeWrapper ${pkgs.bun}/bin/bun $out/bin/${pname} \
              --chdir $out/share/${pname} \
              --add-flags run \
              --add-flags $out/share/${pname}/dist/server/index.js

            runHook postInstall
          '';

          meta = {
            description = "Sample SolidJS and Bun web application";
            mainProgram = pname;
          };
        };
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

      packages = forAllSystems (system: pkgs: {
        default = packageFor system pkgs;
      });

      apps = forAllSystems (system: _pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/sample-project";
          meta.description = "Run sample-project";
        };
      });
    };
}
