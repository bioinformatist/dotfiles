{ yazelix }:

{
  imports = [
    yazelix.homeManagerModules.default
  ];

  programs.yazelix.enable = true;
  programs.yazelix.runtime_tool_sources.yazi = "host";
}
