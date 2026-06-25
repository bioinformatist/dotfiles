{
  config,
  lib,
  ...
}:

let
  cfg = config.dotfiles.nixNetwork;
  chinaSubstituters = [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
  ];
  proxyEnv = {
    HTTP_PROXY = cfg.proxy.url;
    HTTPS_PROXY = cfg.proxy.url;
    ALL_PROXY = cfg.proxy.url;
    http_proxy = cfg.proxy.url;
    https_proxy = cfg.proxy.url;
    all_proxy = cfg.proxy.url;
    NO_PROXY = cfg.proxy.noProxy;
    no_proxy = cfg.proxy.noProxy;
  };
in
{
  options.dotfiles.nixNetwork = {
    profile = lib.mkOption {
      type = lib.types.enum [
        "global"
        "china"
      ];
      default = "global";
      description = "Declarative Nix binary-cache network profile.";
    };

    proxy = {
      enable = lib.mkEnableOption "declarative proxy settings for Nix maintenance";

      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Proxy URL used when dotfiles.nixNetwork.proxy.enable is true.";
      };

      noProxy = lib.mkOption {
        type = lib.types.str;
        default = "mirrors.ustc.edu.cn,127.0.0.1,localhost";
        description = "Comma-separated hosts that bypass the proxy.";
      };
    };

    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Optional system-wide nameservers.";
    };

    networkManagerNameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Optional NetworkManager inserted nameservers.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.profile == "china") {
      nix.settings.substituters = lib.mkForce chinaSubstituters;
    })
    (lib.mkIf cfg.proxy.enable {
      assertions = [
        {
          assertion = cfg.proxy.url != null;
          message = "dotfiles.nixNetwork.proxy.url must be set when proxy.enable is true.";
        }
      ];
    })
    (lib.mkIf (cfg.proxy.enable && cfg.proxy.url != null) {
      systemd.services.nix-daemon.environment = proxyEnv;
      environment.etc."dotfiles/nix-network.json".text = builtins.toJSON {
        inherit proxyEnv;
      };
    })
    (lib.mkIf (cfg.nameservers != [ ]) {
      networking.nameservers = cfg.nameservers;
    })
    (lib.mkIf (cfg.networkManagerNameservers != [ ]) {
      networking.networkmanager.insertNameservers = cfg.networkManagerNameservers;
    })
  ];
}
