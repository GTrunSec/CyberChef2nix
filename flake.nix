{
  inputs = {
    nixpkgs.url = "nixpkgs/7ff5e241a2b96fff7912b7d793a06b4374bd846c";
    cyberchef-src = {
      url = "github:gchq/cyberchef";
      flake = false;
    };

    npmlock2nix-repo = {
      url = "github:tweag/npmlock2nix";
      flake = false;
    };

    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, cyberchef-src, flake-utils, npmlock2nix-repo, flake-compat }:
    flake-utils.lib.eachDefaultSystem
      (
        system:
        let
          pkgs = import nixpkgs {
            inherit system; overlays = [
            self.overlay
          ];
          };
        in
        with pkgs;
        rec {
          packages = flake-utils.lib.flattenTree {
            cyberchef = pkgs.cyberchef;
          };
          defaultPackage = packages.cyberchef;
          checks = packages.cyberchef;
          devShell = with pkgs; mkShell {
            buildInputs = [ ];
          };
        }
      ) // {
      overlay = final: prev:
        let
          npmlock2nix = import npmlock2nix-repo { pkgs = prev; };
          patched-src = prev.runCommand "patch"
            {
              src = cyberchef-src;
            }
            ''
              cp -r $src tmp && chmod -R u+w tmp
              cp ${./remove-chromedriver.patch} tmp/remove-chromedriver.patch
              cd tmp && patch -p1 < remove-chromedriver.patch
              cp -r ../tmp $out
            '';
        in
        {
          cyberchef = with final;
            (
              npmlock2nix.build {
                src = patched-src;
                installPhase = ''
                  mkdir -p $out/{bin,build}
                  cp -r build/prod/* $out/build
                '';
                nodejs = pkgs.nodejs-10_x;
                node_modules_attrs = {
                  buildInputs = [
                    python3 # for node-gyp
                    nodePackages.grunt-cli
                    chromedriver
                  ];
                };
                postFixup = with prev; ''
                  PATH=$${coreutils}/bin:${chromedriver}:bin/chromedriver:$PATH
                  cat <<EOF > $out/bin/cyberchef
                  #!/usr/bin/env bash
                  set -euxo pipefail
                  xdg-open $out/build/index.html
                  EOF
                  chmod +x $out/bin/cyberchef
                '';
              }
            );
        };
    };
}
