{ yazelix }:

{ pkgs, ... }:

{
  imports = [
    yazelix.homeManagerModules.default
  ];

  programs.yazelix = {
    enable = true;
    terminal = "ghostty";
    runtime_tool_sources.helix = "host";
  };
}
