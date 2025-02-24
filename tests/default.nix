{ pkgs, systemd-notify-fifo, systemd-notify-fifo-server }:
let
  test = name: scriptPath:
    let
      script = pkgs.writeShellApplication {
        name = "run";
        runtimeInputs = [
          systemd-notify-fifo
          systemd-notify-fifo-server
          pkgs.systemd
        ];
        text = builtins.readFile scriptPath;
      };
    in

    pkgs.runCommand name { } ''
      set -euo pipefail
      ${script}/bin/run
      touch "$out"
    '';

in
{

  success = test "success" ./success.sh;
  no-out = test "no-out" ./no-out.sh;
}
