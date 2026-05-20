{
  inputs ? null,
}:
{
  headless = import ../../profiles/headless.nix;
  ai-serving = import ../../profiles/ai-serving.nix;
  nixProxy = import ./nix-proxy.nix;
  nvidiaDesktop = import ./nvidia-desktop.nix;
  workstationCn = import ./workstation-cn.nix { inherit inputs; };
}
