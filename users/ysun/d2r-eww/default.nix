{ lib, ... }:
{
  xdg.configFile = {
    "eww/eww.yuck".source = lib.mkForce ./eww.yuck;
    "eww/windows/bar.yuck".source = lib.mkForce ./bar.yuck;
    "eww/modules/terror-zone.yuck".source = ./terror-zone.yuck;
    "eww/terror-zones.json".source = ./terror-zones.json;
    "eww/scripts/get-terror-zone" = {
      source = ./get-terror-zone;
      executable = true;
    };
  };
}
