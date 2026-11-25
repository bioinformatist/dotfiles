# Stable overlay outputs for personal hosts and downstream consumers.
{ inputs, ... }:
{
  additions = final: _prev: import ../pkgs final.pkgs;

  modifications =
    final: prev:
    let
      chromeSecurityVersion = "158.0.8127.88";
    in
    prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "x86_64-linux") {
      # Remove when the locked nixpkgs contains the fix from
      # NixOS/nixpkgs@17c7172f7b1f0ceb1784d9a7d93d87a73f98664f.
      google-chrome =
        if prev.lib.versionOlder prev.google-chrome.version chromeSecurityVersion then
          prev.google-chrome.overrideAttrs (_: {
            version = chromeSecurityVersion;
            src = final.fetchurl {
              url = "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${chromeSecurityVersion}-1_amd64.deb";
              hash = "sha256-play2wCoy38ToddU9qrZH4QBSQZFLG37fz6tkwNdoDs=";
            };
          })
        else
          prev.google-chrome;
    };
}
