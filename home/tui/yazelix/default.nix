{ yazelix }:

{
  imports = [
    yazelix.homeManagerModules.default
  ];

  programs.yazelix.enable = true;
  programs.yazelix.runtime_variant = "ghostty";
}
