# Shared desktop environment configuration for all hosts.
# Covers Hyprland, GUI applications, input method, and proxy tools.

{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  caches = import ../lib/nix-caches.nix;
  # shortcut: nwg-displays 0.4.4 uses retired DPMS commands; drop when upstream
  # supports Lua dispatchers in both apply paths (tracking: #225).
  nwg-displays = pkgs.nwg-displays.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/nwg-displays-lua-dpms.patch ];
  });
  wechatDebReferer = "https://pro-store-packages.uniontech.com/";
  wechat-uos-with-referer = pkgs.wechat-uos.override {
    # UOS package storage rejects the WeChat deb intermittently without Referer.
    fetchurl =
      args:
      pkgs.fetchurl (
        args
        // {
          curlOptsList = (args.curlOptsList or [ ]) ++ [
            "-H"
            "Referer: ${wechatDebReferer}"
          ];
        }
      );
  };
  wechat-uos-fcitx = pkgs.symlinkJoin {
    name = "wechat-uos-fcitx";
    paths = [ wechat-uos-with-referer ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      install -m 0755 ${./wechat-control} $out/bin/wechat-control

      wrapProgram $out/bin/wechat-uos \
        --set QT_IM_MODULE fcitx

      desktopFile=$out/share/applications/com.tencent.wechat.desktop
      rm "$desktopFile"
      install -m 0644 ${wechat-uos-with-referer}/share/applications/com.tencent.wechat.desktop "$desktopFile"
      substituteInPlace "$desktopFile" \
        --replace-fail \
        "Exec=${wechat-uos-with-referer}/bin/wechat-uos -- %U" \
        "Exec=$out/bin/wechat-control launch -- %U"
    '';
  };
  clash-verge-rev = pkgs.symlinkJoin {
    name = "clash-verge-rev-webkit-wrapper";
    paths = [ pkgs.clash-verge-rev ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta = pkgs.clash-verge-rev.meta or { } // {
      mainProgram = "clash-verge";
    };
    postBuild = ''
      # Work around WebKitGTK transparent rendering on Hyprland/NVIDIA.
      wrapProgram $out/bin/clash-verge \
        --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
        --set WEBKIT_DISABLE_COMPOSITING_MODE 1
    '';
  };
in
{
  options.dotfiles.workstation = {
    clash.enable = lib.mkEnableOption "Clash Verge for workstation network proxying" // {
      default = false;
    };

    wechat.enable = lib.mkEnableOption "WeChat desktop client" // {
      default = true;
    };
  };

  config = lib.mkMerge [
    {
      nix.settings = caches.workstation;

      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      fonts = {
        packages = with pkgs; [
          sarasa-gothic
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
          nerd-fonts.jetbrains-mono
          maple-mono.NF
        ];

        fontconfig.defaultFonts = {
          serif = [
            "Noto Serif CJK SC"
            "Noto Serif"
          ];
          sansSerif = [
            "Sarasa UI SC"
            "Noto Sans CJK SC"
            "Noto Sans"
          ];
          monospace = [
            "JetBrains Mono"
            "Sarasa Mono SC"
            "Noto Sans Mono CJK SC"
          ];
        };
      };

      programs.hyprland = {
        enable = true;
        withUWSM = true;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        portalPackage =
          inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      };

      # Portal configuration: add GTK portal as fallback for Screenshot interface.
      # WeChat calls org.freedesktop.portal.Screenshot via D-Bus, but the Hyprland
      # portal doesn't implement it. The GTK portal provides a working Screenshot
      # backend that captures via Wayland screencopy and returns the image to the
      # requesting app (WeChat), which then opens its own annotation editor.
      xdg.portal = {
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        config.hyprland = {
          default = [
            "hyprland"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Screenshot" = [ "gtk" ];
          "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
        };
      };

      programs.nix-ld.enable = true;

      # --- Input method: Fcitx5 + Rime (Mandarin + Cantonese) ---
      # NixOS module writes profile/config to /etc/xdg/fcitx5/ (regular files),
      # sets XMODIFIERS=@im=fcitx automatically, and with waylandFrontend=true
      # deliberately omits GTK_IM_MODULE (native Wayland apps use text-input-v3).
      #
      # NOTE: On Hyprland, fcitx5's native trigger key (TriggerKeys in
      # globalOptions) does NOT work — Wayland input-method-v2 protocol doesn't
      # reliably deliver key events to fcitx5. The Lua binding applies
      # dont_inhibit only to the Ctrl+Space toggle, without
      # disabling application shortcut inhibition for other bindings.
      #
      # Related: the "Keep virtual keyboard object for V2 Protocol" option in
      # fcitx5's Wayland IM frontend addon can cause "sticky key" bugs on
      # Hyprland (modifier keys appear stuck after switching IM). If this occurs,
      # disable it via: settings.addons.waylandim.globalSection.KeepVirtualKeyboardObjectV2 = "False";
      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5 = {
          waylandFrontend = true;
          addons = with pkgs; [
            fcitx5-gtk
            # nixpkgs rime-data now includes Cantonese (jyut6ping3).
            fcitx5-rime
            kdePackages.fcitx5-configtool
          ];
          settings = {
            # /etc/xdg/fcitx5/config — trigger key and behavior
            globalOptions = {
              "Hotkey" = {
                TriggerKeys = "Control+space";
                EnumerateForwardKeys = "";
                EnumerateBackwardKeys = "";
                EnumerateWithTriggerKeys = "True";
              };
              "Hotkey/ActivateKeys" = {
                "0" = "";
              };
              "Hotkey/DeactivateKeys" = {
                "0" = "";
              };
              "Behavior" = {
                ActiveByDefault = "False";
                ShareInputState = "No";
                PreeditEnabledByDefault = "True";
                ShowInputMethodInformation = "True";
              };
            };
            # /etc/xdg/fcitx5/profile — input method groups
            inputMethod = {
              "Groups/0" = {
                Name = "Default";
                "Default Layout" = "us";
                DefaultIM = "rime";
              };
              "Groups/0/Items/0" = {
                Name = "keyboard-us";
                Layout = "";
              };
              "Groups/0/Items/1" = {
                Name = "rime";
                Layout = "";
              };
              "GroupOrder" = {
                "0" = "Default";
              };
            };
            # Disable "Keep virtual keyboard object for V2 Protocol" to fix
            # sticky modifier keys (Super/Shift appear stuck) on Hyprland.
            addons = {
              waylandim.globalSection.KeepVirtualKeyboardObjectV2 = "False";
            };
          };
        };
      };

      environment.systemPackages =
        (with pkgs; [
          wl-clipboard
          git
          google-chrome
          hyprlock
          grim # Wayland screenshot backend
          slurp # Wayland region selector
          satty # Screenshot annotation editor (arrows, text, blur)
          xclip # X11 clipboard bridge (for XWayland apps like WeChat)
          jq # JSON processor (used by screenshot keybind to get active monitor)
        ])
        ++ lib.optionals config.dotfiles.workstation.wechat.enable [
          wechat-uos-fcitx
        ]
        ++ [
          nwg-displays # GUI monitor layout tool
          inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
    }
    (lib.mkIf config.dotfiles.workstation.clash.enable {
      programs.clash-verge = {
        enable = true;
        package = clash-verge-rev;
        tunMode = true;
        serviceMode = true;
      };

      programs.proxychains = {
        enable = true;
        quietMode = false;
        proxies.default = {
          enable = true;
          type = "socks5";
          host = "127.0.0.1";
          port = 7897;
        };
      };
    })
  ];
}
