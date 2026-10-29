let
  official = "https://cache.nixos.org?priority=40";
in
{
  global = {
    substituters = [ official ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    fallback = false;
  };
  china.substituters = [
    "https://mirrors.ustc.edu.cn/nix-channels/store?priority=10"
    official
  ];
  headless = {
    extra-substituters = [ "https://cache.numtide.com?priority=60" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
  workstation = {
    extra-substituters = [
      "https://cache.lantian.pub/lantian?priority=60"
      "https://ghostty.cachix.org?priority=60"
      "https://anyrun.cachix.org?priority=60"
      "https://hyprland.cachix.org?priority=60"
      "https://noctalia.cachix.org?priority=60"
    ];
    extra-trusted-public-keys = [
      "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };
}
