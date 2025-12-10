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

        # Build the webapp
        webapp = pkgs.stdenv.mkDerivation {
          pname = "moneybadger-qr-scanner";
          version = "0.1.0";

          src = ./.;

          buildPhase = ''
            mkdir -p $out
            cp favicon.ico $out/
            cp index.html $out/
          '';

          installPhase = "true";

          meta = with pkgs.lib; {
            description = "Moneybadger QR Scanner - Lightning payment scanner webapp";
            license = licenses.mit;
            platforms = platforms.all;
          };
        };

        # Nginx configuration for Docker
        nginxConf = pkgs.writeText "nginx.conf" ''
          user nobody nobody;
          worker_processes 1;
          error_log /dev/stderr;
          pid /tmp/nginx.pid;

          events {
            worker_connections 1024;
          }

          http {
            include ${pkgs.nginx}/conf/mime.types;
            default_type application/octet-stream;
            access_log /dev/stdout;
            sendfile on;

            server {
              listen 80;
              root /var/www/html;
              index index.html;

              location / {
                try_files $uri $uri/ /index.html;
              }

              location /api/ {
                proxy_pass https://api.cryptoqr.co.za/;
                proxy_http_version 1.1;
                proxy_set_header Host api.cryptoqr.co.za;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_ssl_server_name on;
                proxy_connect_timeout 30s;
                proxy_read_timeout 60s;
                proxy_send_timeout 60s;
              }
            }
          }
        '';

      in
      {
        # Default package
        packages.default = webapp;

        # Docker image with nginx serving the webapp
        packages.dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "moneybadger";
          tag = "latest";

          contents = [
            pkgs.nginx
            pkgs.fakeNss
            (pkgs.runCommand "webapp-files" {} ''
              mkdir -p $out/var/www/html
              cp -r ${webapp}/* $out/var/www/html/
            '')
          ];

          extraCommands = ''
            mkdir -p tmp var/log/nginx var/cache/nginx
          '';

          config = {
            Cmd = [ "${pkgs.nginx}/bin/nginx" "-c" "${nginxConf}" "-g" "daemon off;" ];
            ExposedPorts = { "80/tcp" = {}; };
          };
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python3  # For local testing with python -m http.server
            just     # Task runner
          ];

          shellHook = ''
            echo "Moneybadger QR Scanner Development Environment"
            echo "=============================================="
            echo ""
            echo "Available commands:"
            echo "  just docker-build  - Build and load Docker image"
            echo "  just docker-run    - Build, load, and run container"
            echo "  just build         - Build webapp"
            echo "  just serve         - Serve webapp locally"
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
