# Workstation (physical machine) host configuration.
# Shared settings are in ../../nixos/common.nix and ../../nixos/desktop.nix.

{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
    ../common/personal-workstation.nix
    (import ../../profiles/workstation.nix { inherit inputs; })
    ../../nixos/china-network.nix
    ../../nixos/proxy.nix
    ../../nixos/nvidia.nix
    ../../nixos/mudfish.nix
  ];

  # --- Physical machine: Boot ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Compressed swap to cushion memory pressure on homePC.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Experimental workaround for missing ALC892 playback devices at boot:
  # preload its codec driver before the HDA controller to test probe ordering.
  boot.extraModprobeConfig = ''
    softdep snd_hda_intel pre: snd_hda_codec_alc662
  '';

  # --- Physical machine: Networking ---
  networking.hostName = "homePC";
  networking.networkmanager.enable = true;

  users.users.ysun.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOuEoLENuL9X/OYuPg75zOaheSINb18vsVFh4zz9Algy arreat-index-homepc"
  ];

  # --- Physical machine: Bluetooth ---
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true; # Enable battery display etc.
  };
  services.colord.enable = true;

  # The ALC892 front-panel jack works, but its presence detection reports the
  # connected headphones as unplugged. Prefer analog stereo in WirePlumber's
  # profile-selection policy so later availability events cannot select off.
  services.pipewire.wireplumber.extraConfig."90-homepc-audio" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          { "device.name" = "alsa_card.pci-0000_2b_00.3"; }
        ];
        actions.update-props = {
          "device.disabled" = false;
        };
      }
    ];

    "device.profile.priority.rules" = [
      {
        matches = [
          { "device.name" = "alsa_card.pci-0000_2b_00.3"; }
        ];
        actions.update-props.priorities = [
          "output:analog-stereo+input:analog-stereo"
        ];
      }
    ];

    "wireplumber.components" = [
      {
        name = "default-nodes/force-homepc-analog-default.lua";
        type = "script/lua";
        provides = "custom.homepc-analog-default";
      }
    ];

    "wireplumber.profiles".main."custom.homepc-analog-default" = "required";
  };

  # Profile/default-sink selection does not open a physical output route.
  # Both stored-route and best-route selection reject the misdetected jack.
  # Fill only the missing headphone route, then let WirePlumber restore its
  # normal volume/mute properties and apply it through the hardware mixer.
  services.pipewire.wireplumber.extraScripts."default-nodes/force-homepc-analog-default.lua" = ''
    local cutils = require ("common-utils")
    local devinfo = require ("device-info-cache")

    SimpleEventHook {
      name = "device/homepc-headphone-fallback",
      after = "device/find-best-routes",
      before = { "device/apply-route-props", "device/apply-routes" },
      interests = {
        EventInterest {
          Constraint { "event.type", "=", "select-routes" },
          Constraint { "profile.active-device-ids", "is-present" },
        },
      },
      execute = function (event)
        local device = event:get_subject ()
        if device.properties["device.name"] ~= "alsa_card.pci-0000_2b_00.3" then
          return
        end

        local info = devinfo:get_device_info (device)
        local active_ids = Json.Raw (
            event:get_properties ()["profile.active-device-ids"]):parse ()
        local selected = event:get_data ("selected-routes") or Properties ()

        for _, route in pairs (info.route_infos) do
          if route.name == "analog-output-headphones" and
              route.direction == "Output" and
              (route.profiles == nil or
               cutils.arrayContains (route.profiles, info.active_profile)) then
            for _, id in ipairs (active_ids) do
              local key = tostring (id)
              if not selected[key] and cutils.arrayContains (route.devices, id) then
                selected[key] = Json.Object { index = route.index }:to_string ()
              end
            end
          end
        end

        event:set_data ("selected-routes", selected)
      end
    }:register ()

    local analog_sink = "alsa_output.pci-0000_2b_00.3.analog-stereo"

    SimpleEventHook {
      name = "default-nodes/force-homepc-analog-default",
      after = {
        "default-nodes/find-selected-default-node",
        "default-nodes/find-stored-default-node",
      },
      before = "default-nodes/find-best-default-node",
      interests = {
        EventInterest {
          Constraint { "event.type", "=", "select-default-node" },
        },
      },
      execute = function (event)
        local source = event:get_source ()
        local props = event:get_properties ()
        if props["default-node.type"] ~= "audio.sink" then
          return
        end

        local metadata_om = source:call ("get-object-manager", "metadata")
        local metadata = metadata_om:lookup {
          Constraint { "metadata.name", "=", "default" },
        }
        local configured = metadata and
            metadata:find (0, "default.configured.audio.sink")
        if not configured or Json.Raw (configured):parse ().name ~= analog_sink then
          return
        end

        local nodes_om = source:call ("get-object-manager", "node")
        local analog_node = nodes_om:lookup {
          Constraint { "node.name", "=", analog_sink, type = "pw" },
        }
        if analog_node then
          event:set_data ("selected-node", analog_sink)
          event:set_data ("selected-node-priority", 40000)
          event:set_data ("selected-route-priority", 40000)
        end
      end
    }:register ()
  '';

  # --- Sops secrets (host-specific paths) ---
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt";
  sops.secrets."ysun-password" = {
    neededForUsers = true;
  };
  # Shared GitHub SSH key (same key for all hosts)
  sops.secrets."github-ssh-key-vm-test" = {
    owner = "ysun";
    path = "/home/ysun/.ssh/id_ed25519";
  };
  sops.secrets."sctmes-ops-ssh-key" = {
    owner = "ysun";
    path = "/home/ysun/.ssh/id_ed25519_sctmes_ops";
  };
  sops.secrets."github-mcp-token" = {
    owner = "ysun";
  };
  sops.secrets."context7-api-key" = {
    owner = "ysun";
    mode = "0400";
  };
  systemd.tmpfiles.rules = [
    "d /home/ysun/.local/bin          0755 ysun users -"
  ];

  # --- Home Manager ---
  home-manager.backupFileExtension = "backup";
  home-manager.users.ysun.dotfiles.codex.githubTokenFile =
    config.sops.secrets."github-mcp-token".path;
  home-manager.users.ysun.dotfiles.codex.context7ApiKeyFile =
    config.sops.secrets."context7-api-key".path;

  # --- Gaming ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    # NixOS Steam module handles symlinking Proton-GE into Steam's runtime.
    # Do NOT manually place in compatibilitytools.d — impermanence makes that unreliable.
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };
  programs.gamemode.enable = true;

  # --- Impermanence ---
  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/alsa"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/NetworkManager"
      "/etc/NetworkManager/system-connections"
      "/var/lib/sops-nix"
      {
        directory = "/var/lib/colord";
        user = "colord";
        group = "colord";
        mode = "u=rwx,g=rx,o=";
      }
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    users.ysun = {
      directories = [
        "github.com"
        ".config/nix"
        ".config/sops"
        ".config/nushell"
        ".config/gh" # GitHub CLI auth state; initialize with gh auth login after install
        ".config/google-chrome" # Chrome profile (bookmarks, passwords, extensions)
        ".config/Codex" # Codex Desktop settings, window state, and logs
        ".codex" # Codex config, auth, history, and MCP server state
        ".local/share/io.github.clash-verge-rev.clash-verge-rev"
        ".local/share/fcitx5" # Fcitx5/Rime user dictionary and learned words
        ".xwechat" # WeChat login/session state
        "xwechat_files" # WeChat chat history and data
        # Physical machine daily-use paths
        "Downloads"
        "Documents"
        ".local/share/TelegramDesktop" # Telegram login session + chat cache
        ".cargo/registry" # Cargo registry cache (speeds up rebuilds)
        ".local/share/Steam" # Steam games, Proton prefixes, saves
        ".local/state/wireplumber" # Default audio device, routes, volumes, and mute state
        ".local/state/noctalia" # Settings UI overrides and Noctalia runtime state
        ".cache/noctalia/calendar" # Synchronized calendar event snapshot
        ".cache/fontconfig" # Font cache for GTK/Pango app cold starts
        ".cache/codex-runtimes" # Codex Desktop managed runtimes patched for NixOS
      ];
      # known_hosts is a symlink → /persist (cross-filesystem), so SSH cannot
      # atomically update it (link() fails). We suppress the harmless warning
      # via UpdateHostKeys=no in programs.ssh.extraConfig.
      # NOTE: Do NOT persist .ssh as a directory — the bind mount would hide
      # the id_ed25519 symlink that sops-nix creates on tmpfs.
      files = [
        ".ssh/known_hosts"
        ".config/hypr/monitors.conf" # nwg-displays monitor layout (persists across reboots)
      ];
    };
  };
}
