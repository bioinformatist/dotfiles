{
  username,
  config,
  lib,
  ...
}:

{
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
    };
  };

  hardware.nvidia-container-toolkit.enable = true;

  users.users.${username}.extraGroups = [ "docker" ];

  networking.firewall.enable = lib.mkDefault true;

  systemd.tmpfiles.rules = [
    "d /var/lib/ai-serving 0755 root root -"
    "d /var/lib/ai-serving/logs 0755 root root -"
    "d /var/lib/ai-serving/runtime 0755 root root -"
  ];
}
