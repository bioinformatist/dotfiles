# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications =
    final: prev:
    prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "x86_64-linux") {
      # Targeted security fixes without refreshing the system package set.
      # Remove these overrides when the locked nixpkgs includes these versions.
      # Chrome source matches nixpkgs 8ee8648691ab7fefbf5e156384e39f4139594911.
      # hyprlock source matches nixpkgs a257dcd1428569057f566faaf94acaff27545d6c.
      # Noctalia source matches nixpkgs 0bb2eedc20e4739f29e8045034f2828ad7054f8f.
      google-chrome = prev.google-chrome.overrideAttrs (_: rec {
        version = "157.0.8103.50";
        src = final.fetchurl {
          url = "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${version}-1_amd64.deb";
          hash = "sha256-khSL0U3AWCOmQGHC+vzyDU2Cs/xW9YMSBvFtKsnuP3k=";
        };
      });

      hyprlock = prev.hyprlock.overrideAttrs (_: rec {
        version = "0.9.7";
        src = final.fetchFromGitHub {
          owner = "hyprwm";
          repo = "hyprlock";
          tag = "v${version}";
          hash = "sha256-P8pBEk0fKsYlWfYe/Qrt1ovGa5fPSFlqRPn2D3nMV6w=";
        };
      });

      noctalia = prev.noctalia.overrideAttrs (_: rec {
        version = "5.4.1";
        src = final.fetchFromGitHub {
          owner = "noctalia-dev";
          repo = "noctalia";
          tag = "v${version}";
          hash = "sha256-j6EccQtLK45fYjA5uyUHXW8jxz0gYVxW2SE+pn5UA0Y=";
        };
      });
    };
}
