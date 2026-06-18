{
  inputs ? null,
}:
{
  headless = import ./headless.nix;
  ai-serving = import ./ai-serving.nix;
  workstation = import ./workstation.nix { inherit inputs; };
}
