{ inputs }:

{
  pkgs,
  lib,
  ...
}:
let
  powerAction = pkgs.writeShellApplication {
    name = "dotfiles-power-action";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
      uwsm
    ];
    text = ''
      action="''${1:?Usage: dotfiles-power-action <poweroff|reboot>}"

      case "$action" in
        poweroff|reboot)
          ;;
        *)
          echo "Unknown power action: $action" >&2
          exit 1
          ;;
      esac

      if uwsm check is-active; then
        timeout 60s uwsm stop || true
      fi

      exec systemctl "$action"
    '';
  };
in
{
  imports = [
    ./anyrun
    ./ghostty
    ./hyprland
    (import ./noctalia.nix { inherit inputs; })
  ];

  systemd.user.services."dotfiles-power-action@" = {
    Unit = {
      Description = "Stop UWSM session and %i";
      Documentation = "man:uwsm(1)";
    };
    Service = {
      Type = "oneshot";
      Slice = "session.slice";
      ExecStart = "${lib.getExe powerAction} %i";
    };
  };
}
