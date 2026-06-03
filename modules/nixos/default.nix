{
  inputs ? null,
}:
{
  headless = import ../../profiles/headless.nix;
  ai-serving = import ../../profiles/ai-serving.nix;
  nixNetwork = import ./nix-network.nix;
  nvidiaDesktop = import ./nvidia-desktop.nix;
  workstationCn = import ./workstation-cn.nix { inherit inputs; };
}
