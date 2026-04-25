# NVIDIA desktop integration on top of the generic ai-serving profile.
# References:
#   - https://wiki.hyprland.org/Nvidia/
#   - https://wiki.nixos.org/wiki/NVIDIA
{ pkgs, ... }:

{
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
  };

  hardware.graphics = {
    enable = true;
    # nvidia-vaapi-driver: VA-API hardware video acceleration on Wayland
    # Required for NVD_BACKEND=direct env var to work
    extraPackages = with pkgs; [ nvidia-vaapi-driver ];
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # NixOS-specific: auto-configure Electron/CEF apps to use Wayland
  # Ref: https://wiki.hyprland.org/Nvidia/#flickering-in-electron--cef-apps
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
