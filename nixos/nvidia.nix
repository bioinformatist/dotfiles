# NVIDIA proprietary driver configuration.
# Import this module in hosts that have NVIDIA GPUs.
# Current target: RTX 3060 LHR (GA106, Ampere architecture)
#
# References:
#   - https://wiki.hyprland.org/Nvidia/
#   - https://wiki.nixos.org/wiki/NVIDIA
{ config, lib, pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    # nvidia-vaapi-driver: VA-API hardware video acceleration on Wayland
    # Required for NVD_BACKEND=direct env var to work
    extraPackages = with pkgs; [ nvidia-vaapi-driver ];
  };

  hardware.nvidia = {
    modesetting.enable = true;  # Required for Wayland (default on NixOS ≥535)

    # NVIDIA recommends open kernel modules for Ampere (RTX 30xx) and newer.
    # Ref: https://wiki.hyprland.org/Nvidia/#foreword
    open = true;

    # Suspend/resume support — adds nvidia.NVreg_PreserveVideoMemoryAllocations=1
    # Ref: https://wiki.hyprland.org/Nvidia/#suspendwakeup-issues
    powerManagement.enable = true;

    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # NixOS-specific: auto-configure Electron/CEF apps to use Wayland
  # Ref: https://wiki.hyprland.org/Nvidia/#flickering-in-electron--cef-apps
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
