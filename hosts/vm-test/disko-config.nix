{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "128M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/nix" = {
                    mountOptions = [
                      "compress=zstd:1"
                      "noatime"
                      "discard=async"
                      "space_cache=v2"
                    ];
                    mountpoint = "/nix";
                  };
                  "/persist" = {
                    mountOptions = [
                      "compress=zstd:1"
                      "noatime"
                      "discard=async"
                      "space_cache=v2"
                    ];
                    mountpoint = "/persist";
                  };
                };
              };
            };
          };
        };
      };
    };
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [
          "defaults"
          "size=50%"
          "mode=755"
          "noatime"
        ];
      };
    };
  };
}
