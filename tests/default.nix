{
  pkgs,
  systemd-notify-fifo,
}:
let
  test =
    name: scriptPath:
    let
      script = pkgs.writeShellApplication {
        name = "run";
        runtimeInputs = [
          systemd-notify-fifo
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
  relpath = test "relpath" ./relpath.sh;
}
