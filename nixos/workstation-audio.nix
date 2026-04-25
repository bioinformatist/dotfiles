{ ... }:

{
  services.pipewire.wireplumber.extraConfig = {
    "90-alsa-routing" = {
      "monitor.alsa.rules" = [
        {
          matches = [{ "device.name" = "alsa_card.pci-0000_2b_00.3"; }];
          actions = {
            update-props = {
              "device.profile" = "output:analog-stereo+input:analog-stereo";
              "device.disabled" = false;
            };
          };
        }
        {
          matches = [{ "device.name" = "alsa_card.pci-0000_29_00.1"; }];
          actions = {
            update-props = {
              "device.profile" = "off";
            };
          };
        }
      ];
    };
  };
}
