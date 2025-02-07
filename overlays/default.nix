# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    openssh = prev.clash-verge-rev.override {
        version = "2.0.2";
        src = pkgs.fetchFromGitHub {
            owner = "clash-verge-rev";
            repo = "clash-verge-rev";
            rev = "v2.0.2";
            hash = "sha256-QLvJO1JFHPFOsVxNi6SCu2QuJQ9hCsO1+WKOjZL944w=";
        };
        src-service = pkgs.fetchFromGitHub {
            owner = "clash-verge-rev";
            repo = "clash-verge-service";
            rev = "ab4200dfa0f24230a7bacbda0412750a3115cd7e";
            hash = "sha256-7a+lNeOLN9rvF8yHeWeKgghsdOF+8JkvhxjJEjDeFhQ=";
        };
    };
  };
}