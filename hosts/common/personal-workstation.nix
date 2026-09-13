{ lib, ... }:
{
  dotfiles.workstation.clash.enable = lib.mkDefault true;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        action.id == "org.freedesktop.NetworkManager.settings.modify.system" &&
        subject.isInGroup("wheel")
      ) {
        return polkit.Result.YES;
      }
    });

    polkit.addRule(function(action, subject) {
      if (
        subject.active &&
        subject.local &&
        subject.isInGroup("wheel") &&
        (
          action.id == "com.feralinteractive.GameMode.governor-helper" ||
          action.id == "com.feralinteractive.GameMode.procsys-helper"
        )
      ) {
        return polkit.Result.YES;
      }
    });
  '';
}
