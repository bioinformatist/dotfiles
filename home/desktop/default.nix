{
  imports = [
    ./anyrun
    ./hyprland
  ];

  programs.eww = {
    enable = true;
    configDir = ./eww;
  };
}