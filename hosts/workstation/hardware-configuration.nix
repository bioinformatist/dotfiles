# PLACEHOLDER: This file must be regenerated on the actual physical machine.
#
# On the target machine, run:
#   sudo nixos-generate-config --root /mnt
# Then copy the generated /mnt/etc/nixos/hardware-configuration.nix here,
# replacing this placeholder file entirely.
#
# The content below is a reasonable default for a desktop AMD system
# with SATA SSD. Adjust kernel modules as needed for your hardware.

{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
