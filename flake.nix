{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, treefmt-nix }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

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

      systemd-notify-fifo-server = pkgs.runCommandLocal "systemd-notify-fifo" { } ''
        mkdir -p "$out/bin" 
        export XDG_CACHE_HOME="$PWD"
        ${pkgs.go}/bin/go build -o "$out/bin/systemd-notify-fifo-server" ${./server.go}
      '';

      systemd-notify-fifo = pkgs.writeShellApplication {
        name = "systemd-notify-fifo";
        runtimeInputs = [ systemd-notify-fifo-server ];
        text = builtins.readFile ./systemd_notify_fifo.sh;
      };

      packages = {
        systemd-notify-fifo-server = systemd-notify-fifo-server;
        systemd-notify-fifo = systemd-notify-fifo;
        formatting = treefmtEval.config.build.check self;
      };


      gcroot = packages // {
        gcroot-all = pkgs.linkFarm "gcroot-all" packages;
        default = systemd-notify-fifo;
      };


    in
    {


      packages.x86_64-linux = gcroot;
      checks.x86_64-linux = gcroot;
      formatter.x86_64-linux = treefmtEval.config.build.wrapper;

    };
}
