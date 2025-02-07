{
  imports = [
    ./hyprland
  ];

  programs.eww = {
    enable = true;
    configDir = ./eww;
  };
}