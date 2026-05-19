{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.nixProxy;
  proxyConfigPath = lib.escapeShellArg cfg.configPath;
  nuConfigPath = builtins.toJSON cfg.configPath;
in
{
  options.dotfiles.nixProxy = {
    enable = lib.mkEnableOption "nix-daemon proxy settings loaded from a local nuon file";

    configPath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nix/local-proxy.nuon";
      description = "Path to the local nuon proxy config read by nix-daemon.";
    };

    networkingProxyDefault = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional system-wide default proxy value.";
    };

    networkingNoProxy = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1,localhost,internal.domain";
      description = "System-wide noProxy value used when networkingProxyDefault is set.";
    };

    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Optional system-wide nameservers.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        systemd.services.nix-daemon = {
          path = [ pkgs.nushell ];
          preStart = ''
            cfg=${proxyConfigPath}
            out="/run/nix-daemon-proxy.env"

            rm -f "$out"

            if [ -f "$cfg" ]; then
              http_proxy="$(${pkgs.nushell}/bin/nu -c 'let cfg = open ${nuConfigPath}; ($cfg.HTTP_PROXY? | default "")' | tr -d '\n')"
              https_proxy="$(${pkgs.nushell}/bin/nu -c 'let cfg = open ${nuConfigPath}; ($cfg.HTTPS_PROXY? | default "")' | tr -d '\n')"
              all_proxy="$(${pkgs.nushell}/bin/nu -c 'let cfg = open ${nuConfigPath}; ($cfg.ALL_PROXY? | default "")' | tr -d '\n')"
              no_proxy="$(${pkgs.nushell}/bin/nu -c 'let cfg = open ${nuConfigPath}; ($cfg.NO_PROXY? | default "")' | tr -d '\n')"
              substituters="$(${pkgs.nushell}/bin/nu -c 'let cfg = open ${nuConfigPath}; ($cfg.substituters? | default [] | str join " ")' | tr -d '\n')"

              {
                [ -n "$http_proxy" ] && printf 'HTTP_PROXY=%s\nhttp_proxy=%s\n' "$http_proxy" "$http_proxy"
                [ -n "$https_proxy" ] && printf 'HTTPS_PROXY=%s\nhttps_proxy=%s\n' "$https_proxy" "$https_proxy"
                [ -n "$all_proxy" ] && printf 'ALL_PROXY=%s\nall_proxy=%s\n' "$all_proxy" "$all_proxy"
                [ -n "$no_proxy" ] && printf 'NO_PROXY=%s\nno_proxy=%s\n' "$no_proxy" "$no_proxy"
                [ -n "$substituters" ] && printf 'NIX_CONFIG="substituters = %s"\n' "$substituters"
              } > "$out"
            fi
          '';
          serviceConfig.EnvironmentFile = [ "-/run/nix-daemon-proxy.env" ];
        };
      }
      (lib.mkIf (cfg.networkingProxyDefault != null) {
        networking.proxy.default = cfg.networkingProxyDefault;
        networking.proxy.noProxy = cfg.networkingNoProxy;
      })
      (lib.mkIf (cfg.nameservers != [ ]) {
        networking.nameservers = cfg.nameservers;
      })
    ]
  );
}
