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
  '';
}
