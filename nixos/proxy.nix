{
  username,
  pkgs,
  ...
}:

{
  systemd.services.nix-daemon = {
    path = [ pkgs.nushell ];
    preStart = ''
      cfg="/home/${username}/.config/nix/local-proxy.nuon"
      out="/run/nix-daemon-proxy.env"

      rm -f "$out"

      if [ -f "$cfg" ]; then
        http_proxy="$(${pkgs.nushell}/bin/nu -c 'let cfg = open "/home/${username}/.config/nix/local-proxy.nuon"; ($cfg.HTTP_PROXY? | default "")' | tr -d '\n')"
        https_proxy="$(${pkgs.nushell}/bin/nu -c 'let cfg = open "/home/${username}/.config/nix/local-proxy.nuon"; ($cfg.HTTPS_PROXY? | default "")' | tr -d '\n')"
        no_proxy="$(${pkgs.nushell}/bin/nu -c 'let cfg = open "/home/${username}/.config/nix/local-proxy.nuon"; ($cfg.NO_PROXY? | default "")' | tr -d '\n')"
        substituters="$(${pkgs.nushell}/bin/nu -c 'let cfg = open "/home/${username}/.config/nix/local-proxy.nuon"; ($cfg.substituters? | default [] | str join " ")' | tr -d '\n')"

        {
          [ -n "$http_proxy" ] && printf 'HTTP_PROXY=%s\nhttp_proxy=%s\n' "$http_proxy" "$http_proxy"
          [ -n "$https_proxy" ] && printf 'HTTPS_PROXY=%s\nhttps_proxy=%s\n' "$https_proxy" "$https_proxy"
          [ -n "$no_proxy" ] && printf 'NO_PROXY=%s\nno_proxy=%s\n' "$no_proxy" "$no_proxy"
          [ -n "$substituters" ] && printf 'NIX_CONFIG="substituters = %s"\n' "$substituters"
        } > "$out"
      fi
    '';
    serviceConfig.EnvironmentFile = [ "-/run/nix-daemon-proxy.env" ];
  };

  networking.proxy.default = "http://127.0.0.1:7897";
  networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  networking.nameservers = [
    "8.8.8.8"
    "1.1.1.1"
  ];
}
