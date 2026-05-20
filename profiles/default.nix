{
  inputs ? null,
}:
{
  headless = import ./headless.nix;
  ai-serving = import ./ai-serving.nix;
  workstationCn = import ./workstation-cn.nix { inherit inputs; };
}
