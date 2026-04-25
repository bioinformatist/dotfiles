{
  headless = import ../../profiles/headless.nix;
  ai-serving = import ../../profiles/ai-serving.nix;
  desktop = import ../../nixos/desktop.nix;
  proxy = import ../../nixos/proxy.nix;
  workstation-audio = import ../../nixos/workstation-audio.nix;
  nvidia-desktop = import ../../nixos/nvidia.nix;
  vm-tweaks = import ./vm-tweaks.nix;
}
