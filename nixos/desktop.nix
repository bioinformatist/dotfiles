# Shared desktop environment configuration for all hosts.
# Covers Hyprland, GUI applications, input method, and proxy tools.

{
  inputs,
  pkgs,
  ...
}:

{
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
      default = [ "hyprland" "gtk" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
    };
  };

  programs.clash-verge = {
    enable = true;
    package = pkgs.clash-verge-rev;
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

  programs.nix-ld.enable = true;

  # --- Input method: Fcitx5 + Rime (Mandarin + Cantonese) ---
  # NixOS module writes profile/config to /etc/xdg/fcitx5/ (regular files),
  # sets XMODIFIERS=@im=fcitx automatically, and with waylandFrontend=true
  # deliberately omits GTK_IM_MODULE (native Wayland apps use text-input-v3).
  #
  # NOTE: On Hyprland (wlroots), fcitx5's native trigger key (TriggerKeys in
  # globalOptions) does NOT work — Wayland input-method-v2 protocol doesn't
  # reliably deliver key events to fcitx5. We solve this with a Hyprland bind
  # in hyprland.conf: `bind = CTRL, space, exec, fcitx5-remote -t`.
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
        (fcitx5-rime.override {
          rimeDataPkgs = [
            rime-data
            (callPackage ../pkgs/rime-data-cantonese.nix { })
          ];
        })
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
    with pkgs;
    [
      wl-clipboard
      git
      ghostty
      eww
      dunst
      google-chrome
      hyprlock
      wechat-uos
    grim # Wayland screenshot backend
    slurp # Wayland region selector
    satty # Screenshot annotation editor (arrows, text, blur)
    xclip # X11 clipboard bridge (for XWayland apps like WeChat)
    jq # JSON processor (used by screenshot keybind to get active monitor)
    nwg-displays # GUI monitor layout tool (like Windows display settings)
    ]
    ++ [
      inputs.swww.packages.${pkgs.stdenv.hostPlatform.system}.swww
      inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-no-fhs
    ];
}
