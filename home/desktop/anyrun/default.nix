{
  anyrun,
  pkgs,
  ...
}:
let
  sys = pkgs.stdenv.hostPlatform.system;
  # Map plugin library name → Nix derivation.
  # The .so files inside each derivation are at $out/lib/lib<name>.so.
  pluginDefs = {
    "libapplications.so" = anyrun.packages.${sys}.applications;
    "librink.so" = anyrun.packages.${sys}.rink;
    "libshell.so" = anyrun.packages.${sys}.shell;
    "libsymbols.so" = anyrun.packages.${sys}.symbols;
    "libwebsearch.so" = anyrun.packages.${sys}.websearch;
  };

  # Build xdg.configFile entries for plugin symlinks
  pluginFiles = builtins.listToAttrs (
    map (soName: {
      name = "anyrun/plugins/${soName}";
      value = { source = "${pluginDefs.${soName}}/lib/${soName}"; };
    }) (builtins.attrNames pluginDefs)
  );
in
{
  # Install anyrun binary
  home.packages = [
    anyrun.packages.${sys}.anyrun
  ];

  # Merge plugin symlinks + config files into a single xdg.configFile attrset
  xdg.configFile = pluginFiles // {
    # Main config (RON format)
    "anyrun/config.ron".text = ''
      Config(
        // Centered horizontally, slightly below top
        x: Fraction(0.5),
        y: Absolute(200),

        width: Absolute(800),
        height: Absolute(1),

        hide_icons: false,
        ignore_exclusive_zones: false,
        layer: Overlay,
        hide_plugin_info: false,
        close_on_click: true,
        show_results_immediately: false,
        max_entries: None,

        plugins: [
          "libapplications.so",
          "librink.so",
          "libshell.so",
          "libsymbols.so",
          "libwebsearch.so",
        ],
      )
    '';

    # Websearch plugin config — default to Google
    "anyrun/websearch.ron".text = ''
      Config(
        prefix: "?",
        engines: [Google],
      )
    '';

    # GTK4 CSS theme — dark glassmorphism style matching Hyprland theme
    "anyrun/style.css".text = ''
      @define-color accent rgba(51, 204, 255, 0.9);
      @define-color accent-dim rgba(51, 204, 255, 0.4);
      @define-color bg-color rgba(22, 22, 22, 0.85);
      @define-color fg-color #eeeeee;
      @define-color desc-color #aaaaaa;

      window {
        background: transparent;
      }

      box.main {
        padding: 12px;
        margin: 10px;
        border-radius: 16px;
        border: 2px solid @accent-dim;
        background-color: @bg-color;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.6);
      }

      text {
        min-height: 36px;
        padding: 8px 12px;
        border-radius: 8px;
        color: @fg-color;
        font-size: 16px;
        caret-color: @accent;
      }

      .matches {
        background-color: transparent;
        border-radius: 12px;
        margin-top: 8px;
      }

      box.plugin:first-child {
        margin-top: 4px;
      }

      box.plugin.info {
        min-width: 200px;
      }

      list.plugin {
        background-color: transparent;
      }

      label.match {
        color: @fg-color;
        font-size: 14px;
      }

      label.match.description {
        font-size: 11px;
        color: @desc-color;
      }

      label.plugin.info {
        font-size: 13px;
        color: @desc-color;
      }

      .match {
        padding: 6px 10px;
        border-radius: 8px;
        background: transparent;
        transition: all 0.15s ease;
      }

      .match:selected {
        border-left: 3px solid @accent;
        background: rgba(51, 204, 255, 0.08);
      }
    '';
  };
}
