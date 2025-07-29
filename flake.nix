{

  nixConfig.allow-import-from-derivation = false;

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";

  outputs =
    { self, ... }@inputs:
    let
      lib = inputs.nixpkgs.lib;
      collectInputs =
        is:
        pkgs.linkFarm "inputs" (
          builtins.mapAttrs (
            name: i:
            pkgs.linkFarm name {
              self = i.outPath;
              deps = collectInputs (lib.attrByPath [ "inputs" ] { } i);
            }
          ) is
        );

      overlay = (
        final: prev:
        let
          systemd-notify-server = final.runCommandLocal "systemd-notify-server" { } ''
            mkdir -p "$out/bin" 
            export XDG_CACHE_HOME="$PWD"
            ${final.go}/bin/go build -o "$out/bin/systemd-notify-server" ${./server.go}
          '';

          systemd-notify-server-prepare = final.writeShellApplication {
            name = "systemd-notify-server-prepare";
            text = ''
              rm -f "/tmp/$PPID-systemd-notify-server.fifo" > /dev/null 2>&1 || true
              mkfifo "/tmp/$PPID-systemd-notify-server.fifo"
            '';
          };

          systemd-notify-server-wait = final.writeShellApplication {
            name = "systemd-notify-server-wait";
            text = ''
              cat "/tmp/$PPID-systemd-notify-server.fifo"
            '';
          };

          systemd-notify-wait = final.writeShellApplication {
            name = "systemd-notify-wait";
            text = ''
              while true; do
                result=$(cat "/tmp/$PPID-systemd-notify.fifo")
                if [ "$result" = "READY=1" ]; then
                  break
                fi
              done
            '';
          };

        in
        {
          systemd-notify-fifo = pkgs.symlinkJoin {
            name = "systemd-notify-fifo";
            paths = [
              systemd-notify-server
              systemd-notify-server-prepare
              systemd-notify-server-wait
              systemd-notify-wait
            ];
          };
        }
      );

      pkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
        overlays = [ overlay ];
      };

      treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
        programs.prettier.enable = true;
        programs.shfmt.enable = true;
        programs.shellcheck.enable = true;
        programs.gofumpt.enable = true;
        settings.formatter.shellcheck.options = [
          "-s"
          "sh"
        ];
        settings.global.excludes = [ "LICENSE" ];
      };

      formatter = treefmtEval.config.build.wrapper;

      devShells.default = pkgs.mkShellNoCC {
        buildInputs = [
          pkgs.nixd
        ];
      };

      packages = devShells // {
        systemd-notify-fifo = pkgs.systemd-notify-fifo;
        formatting = treefmtEval.config.build.check self;
        formatter = formatter;
        allInputs = collectInputs inputs;
      };

    in
    {
      packages.x86_64-linux = packages // {
        gcroot = pkgs.linkFarm "gcroot" packages;
        default = pkgs.systemd-notify-fifo;
      };

      devShells.x86_64-linux = devShells;
      checks.x86_64-linux = packages;
      formatter.x86_64-linux = formatter;
      overlays.default = overlay;
    };
}
