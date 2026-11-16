# Stable overlay outputs for personal hosts and downstream consumers.
{ inputs, ... }:
{
  additions = final: _prev: import ../pkgs final.pkgs;

  # The locked nixpkgs now includes the Chrome, hyprlock and Noctalia fixes.
  # Keep this public extension point without overriding newer upstream packages.
  modifications = _final: _prev: { };
}
