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
          systemd-notify-fifo-server = final.runCommandLocal "systemd-notify-fifo" { } ''
            mkdir -p "$out/bin" 
            export XDG_CACHE_HOME="$PWD"
            ${final.go}/bin/go build -o "$out/bin/systemd-notify-fifo-server" ${./server.go}
          '';

          systemd-notify-fifo = final.writeShellApplication {
            name = "systemd-notify-fifo";
            runtimeInputs = [ systemd-notify-fifo-server ];
            text = builtins.readFile ./systemd_notify_fifo.sh;
          };

          systemd-notify-fifo-wait-ready = final.writeShellApplication {
            name = "systemd-notify-fifo-wait-ready";
            text = ''
              while true; do
                result=$(cat "/tmp/$PPID-systemd-notify-fifo.fifo")
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
              systemd-notify-fifo-server
              systemd-notify-fifo
              systemd-notify-fifo-wait-ready
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

      testAttrs = import ./tests {
        pkgs = pkgs;
        systemd-notify-fifo = pkgs.systemd-notify-fifo;
      };

      devShells.default = pkgs.mkShellNoCC {
        buildInputs = [
          pkgs.nixd
        ];
      };

      tests = pkgs.lib.mapAttrs' (name: value: {
        name = "test-" + name;
        value = value;
      }) testAttrs;

      packages =
        tests
        // devShells
        // {
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
