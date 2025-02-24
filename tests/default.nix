{ pkgs, systemd-notify-fifo }:
let
  test = name: scriptPath:
    let
      script = pkgs.writeShellApplication {
        name = "run";
        text = builtins.readFile scriptPath;
      };
    in

    pkgs.runCommand name
      {
        buildInputs = [
          systemd-notify-fifo
          pkgs.systemd
        ];
      } ''
      bash ${scriptPath}
      touch "$out"
    '';

in
{

  success = test "success" ./success.sh;
}
