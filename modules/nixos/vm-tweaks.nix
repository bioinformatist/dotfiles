{
  config,
  lib,
  pkgs,
  ...
}:

{
  # VM Specific Fixes (Hyprland & Electron)
  # These are required for hardware cursor issues on VMware/VirtualBox
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    LIBGL_ALWAYS_SOFTWARE = "1";
  };

  virtualisation.vmware.guest.enable = true;
}
