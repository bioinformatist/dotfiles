{ config, lib, ... }:
{
  dotfiles.workstation.clash.enable = lib.mkDefault true;

  security.polkit.extraConfig = lib.mkIf config.services.power-profiles-daemon.enable ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.UPower.PowerProfiles.switch-profile" &&
          subject.local && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
