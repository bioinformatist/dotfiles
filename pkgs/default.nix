pkgs: {
  mudfish = pkgs.callPackage ./mudfish.nix { };
  orca-ide = pkgs.callPackage ./orca-ide.nix { };
  rime-data-cantonese = pkgs.callPackage ./rime-data-cantonese.nix { };
}
