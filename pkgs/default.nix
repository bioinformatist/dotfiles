pkgs: {
  mudfish = pkgs.callPackage ./mudfish.nix { };
  rime-data-cantonese = pkgs.callPackage ./rime-data-cantonese.nix { };
}
