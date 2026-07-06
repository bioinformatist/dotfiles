{
  lib,
  pkgs,
  ...
}:

{
  hardware.enableRedistributableFirmware = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  hardware.graphics.enable = lib.mkDefault true;
  hardware.amdgpu.initrd.enable = lib.mkDefault true;

  boot.kernelModules = lib.mkAfter [ "kvm-amd" ];

  services.upower.enable = lib.mkDefault true;
  services.power-profiles-daemon.enable = lib.mkDefault true;
  services.fwupd.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    lshw
    lm_sensors
    vulkan-tools
    libva-utils
    radeontop
  ];
}
