{

  nixConfig.allow-import-from-derivation = false;

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, treefmt-nix }:
    let

      overlay = (final: prev:
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

        in
        {
          systemd-notify-fifo-server = systemd-notify-fifo-server;
          systemd-notify-fifo = systemd-notify-fifo;

        });

      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ overlay ];
      };

      treefmtEval = treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.nixpkgs-fmt.enable = true;
        programs.prettier.enable = true;
        programs.shfmt.enable = true;
        programs.shellcheck.enable = true;
        programs.gofumpt.enable = true;
        settings.formatter.shellcheck.options = [ "-s" "sh" ];
        settings.global.excludes = [ "LICENSE" ];
      };


      testAttrs = import ./tests {
        pkgs = pkgs;
        systemd-notify-fifo = pkgs.systemd-notify-fifo;
        systemd-notify-fifo-server = pkgs.systemd-notify-fifo-server;
      };

      tests = pkgs.lib.mapAttrs' (name: value: { name = "test-" + name; value = value; }) testAttrs;

      packages = tests // {
        systemd-notify-fifo-server = pkgs.systemd-notify-fifo-server;
        systemd-notify-fifo = pkgs.systemd-notify-fifo;
        formatting = treefmtEval.config.build.check self;
      };

      gcroot = packages // {
        gcroot-all = pkgs.linkFarm "gcroot-all" packages;
        default = pkgs.systemd-notify-fifo;
      };

    in
    {
      packages.x86_64-linux = gcroot;

      checks.x86_64-linux = gcroot;

      formatter.x86_64-linux = treefmtEval.config.build.wrapper;

      overlays.default = overlay;
    };
}
