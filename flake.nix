{
  description = "Moneybadger QR Scanner - Lightning payment scanner webapp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Function to build the webapp with configurable API endpoint
        buildWebapp = { apiEndpoint ? "https://api.moneybadger.sirion.io" }:
          pkgs.stdenv.mkDerivation {
            pname = "moneybadger-qr-scanner";
            version = "0.1.0";

            src = ./.;

            buildInputs = [ ];

            buildPhase = ''
              # Create output directory
              mkdir -p $out

              # Copy favicon
              cp favicon.ico $out/

              # Process index.html to replace API endpoint
              substitute index.html $out/index.html \
                --replace-fail "https://api.moneybadger.sirion.io" "${apiEndpoint}"
            '';

            installPhase = "true"; # Already installed in buildPhase

            meta = with pkgs.lib; {
              description = "Moneybadger QR Scanner - Lightning payment scanner webapp";
              license = licenses.mit;
              platforms = platforms.all;
            };
          };
      in
      {
        # Default package uses the default API endpoint
        packages.default = buildWebapp { };

        # Allow building with custom API endpoint
        # Usage: nix build .#withApi --impure --expr '(builtins.getFlake (toString ./.)).outputs.lib.x86_64-linux.withApi "https://custom.api.example.com"'
        packages.webapp = buildWebapp { };

        # Export the build function so users can override the API
        lib.withApi = apiEndpoint: buildWebapp { inherit apiEndpoint; };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python3  # For local testing with python -m http.server
          ];

          shellHook = ''
            echo "Moneybadger QR Scanner Development Environment"
            echo "=============================================="
            echo ""
            echo "To test locally:"
            echo "  python -m http.server 8000"
            echo ""
            echo "To build with default API:"
            echo "  nix build"
            echo ""
            echo "To build with custom API:"
            echo "  nix build --impure --expr '(builtins.getFlake (toString ./.)).lib.${system}.withApi \"https://custom.api.example.com\"'"
            echo ""
          '';
        };

        # Apps for convenience
        apps.serve = {
          type = "app";
          program = toString (pkgs.writeShellScript "serve" ''
            cd ${self.packages.${system}.default}
            ${pkgs.python3}/bin/python -m http.server 8000
          '');
        };
      }
    );
}
