{
  headless = import ../../profiles/headless.nix;
  ai-serving = import ../../profiles/ai-serving.nix;
  nixProxy = import ./nix-proxy.nix;
}
