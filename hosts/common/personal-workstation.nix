{ lib, ... }:
{
  dotfiles.workstation.clash.enable = lib.mkDefault true;

  # Trust the personal server declaratively so ephemeral workstations can use
  # their sctmes-ops key before a mutable known_hosts entry has been created.
  programs.ssh.knownHosts."116-ed25519" = {
    hostNames = [
      "116"
      "bigdick"
      "192.168.0.116"
    ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0Mjbn/qCE7fB5tkAJO6+L5arETZ1QFw0JH3orqqB9g";
  };

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
