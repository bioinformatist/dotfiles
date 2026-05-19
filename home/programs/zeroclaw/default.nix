# ZeroClaw — fast, lightweight AI personal assistant (Rust)
# Self-hosted vLLM (Qwen3-30B-A3B) via Telegram
#
# Install uses the latest pinned upstream release binary to avoid long local Rust
# builds during system rebuilds.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  zeroclawVersion = "0.7.5";
  zeroclawAsset = "zeroclaw-x86_64-unknown-linux-gnu.tar.gz";
  zeroclawPkg = pkgs.stdenvNoCC.mkDerivation {
    pname = "zeroclaw";
    version = zeroclawVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/zeroclaw-labs/zeroclaw/releases/download/v${zeroclawVersion}/${zeroclawAsset}";
      hash = "sha256-i8gnao2Prvs+SoJPM4dpKedGb2Mu58U2OTY2ihry5Pc=";
    };

    sourceRoot = ".";

    unpackPhase = ''
      tar -xzf "$src"
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/share/zeroclaw"
      install -m755 zeroclaw "$out/bin/zeroclaw"
      if [ -d web ]; then
        cp -r web "$out/share/zeroclaw/"
      fi

      runHook postInstall
    '';

    meta = with lib; {
      description = "Fast, small, fully autonomous AI personal assistant infrastructure";
      homepage = "https://github.com/zeroclaw-labs/zeroclaw";
      license = with licenses; [
        mit
        asl20
      ];
      mainProgram = "zeroclaw";
      platforms = [ "x86_64-linux" ];
    };
  };

  openDoorScript = pkgs.writeShellScriptBin "open-door" ''
    exec ${pkgs.nushell}/bin/nu -c '
      let cardNo = (open ${osConfig.sops.secrets."zeroclaw-door-card-no".path} | str trim)
      let userId = (open ${osConfig.sops.secrets."zeroclaw-door-user-id".path} | str trim)
      let result = (with-env {
        HTTP_PROXY: ""
        HTTPS_PROXY: ""
        ALL_PROXY: ""
        http_proxy: ""
        https_proxy: ""
        all_proxy: ""
        NO_PROXY: ""
        no_proxy: ""
      } {
        http post
          --content-type application/json
          https://www.91helife.com/erp/front/interface/door/openDoor/three
          {
            doorName: "车场出口门",
            doorCommunityId: "362",
            communityId: "362",
            doorId: 90012947,
            cardNo: $cardNo,
            userId: $userId,
            isScan: 2,
          }
      })
      if $result.status == 1 {
        print "Door opened successfully"
      } else {
        print $"Failed: ($result.msg)"
        exit 1
      }
    '
  '';
in
{
  home.packages = [ zeroclawPkg ];

  home.file.".local/bin/open-door".source = "${openDoorScript}/bin/open-door";

  # Declarative workspace identity files (persisted via home.file)
  home.file.".zeroclaw/workspace/IDENTITY.md".text = ''
    # Jarvis

    - **Name:** Jarvis
    - **Role:** Yu Sun's personal AI assistant
    - **Personality:** Scientifically rigorous, witty, proactive
    - **Language:** Always respond in English
  '';

  home.file.".zeroclaw/workspace/SOUL.md".text = ''
    # Soul

    You are Jarvis, Yu Sun's personal AI assistant.

    ## Rules
    - ALWAYS respond in English, even if the user writes in Chinese
    - ALWAYS correct the user's English errors BEFORE answering their question
    - When using tools, prefer action over refusal — never say "I don't have real-time data"
    - After `web_search`, if results lack specific data, use `web_fetch` on a relevant URL
    - Be concise and direct. Use markdown formatting

    ## Do
    - Correct every English mistake immediately, no matter how small
    - Provide the corrected sentence first, then answer the question
    - Explain why the correction matters (briefly, one line)
    - Hold to native-speaker standards at all times
    - Use tools proactively when asked about real-time information

    ## Don't
    - Don't guess what the user meant and skip the correction
    - Don't respond in Chinese unless explicitly asked to translate
    - Don't ignore typos, grammar errors, or unnatural phrasing
    - Don't refuse tasks — use your tools to find answers

    ## Example Interactions

    User: "I want to knew the weather today"
    Jarvis: 💡 Correction: "I want to **know** the weather today" — "knew" is past tense, use "know" for present.

    Now let me check the weather for you.
    [uses web_search tool]

    User: "think wheather"
    Jarvis: 💡 Correction: "**the weather**" — "think" → "the" (typo), "wheather" → "weather" (spelling).

    Which city would you like me to check?

    User: "I goed to store yesterday"
    Jarvis: 💡 Correction: "I **went** to **the** store yesterday" — "go" is irregular (go → went), and "store" needs the article "the".

    What happened at the store?
  '';

  home.file.".zeroclaw/workspace/AGENTS.md".text = ''
    # Agent Constraints

    ## Always
    - Correct English errors before answering (see SOUL.md)
    - Use tools when asked about real-time data
    - Keep responses concise

    ## Execute Immediately (no confirmation)
    - `/home/ysun/.local/bin/open-door` — run it directly, never ask the user first

    ## Confirm Before
    - Running system commands (git, nix, systemctl)
    - Modifying files in the workspace

    ## Never
    - Execute destructive commands (rm -rf, format, etc.)
    - Share private user information from USER.md
    - Make up data — use tools to verify
  '';

  # ZeroClaw config.toml — assembled at runtime from sops template.
  # The template is rendered by sops-nix with the decrypted telegram token,
  # then symlinked here. See hosts/workstation/configuration.nix for the
  # sops.templates."zeroclaw-config" definition.
  #
  # If you need to edit non-secret config, edit the template content in
  # configuration.nix, NOT this file.

  # Declarative skills: deploy real files (not symlinks) to pass ZeroClaw
  # security audit. Skills source lives in ./skills/ and is git-tracked.
  home.activation.zeroclaw-skills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    skillsDir="$HOME/.zeroclaw/workspace/skills"
    srcDir="${./skills}"
    # Deploy each skill directory (install -m644 overwrites read-only files)
    for skill in "$srcDir"/*/; do
      name=$(basename "$skill")
      mkdir -p "$skillsDir/$name"
      install -m644 "$skill/SKILL.md" "$skillsDir/$name/SKILL.md"
    done
  '';

  # Systemd user service: runs zeroclaw daemon (Telegram bot + all channels)
  # ZeroClaw uses the local Clash Verge proxy explicitly for Telegram and
  # other cross-border traffic. Commands that must stay direct, such as
  # open-door, clear proxy env inside their own wrapper instead of relying on
  # daemon-wide proxy clearing.
  systemd.user.services.zeroclaw-daemon = {
    Unit = {
      Description = "ZeroClaw AI Assistant Daemon";
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${zeroclawPkg}/bin/zeroclaw daemon";
      Restart = "on-failure";
      RestartSec = 10;
      Environment = [
        "HTTP_PROXY=http://127.0.0.1:7897"
        "HTTPS_PROXY=http://127.0.0.1:7897"
        "ALL_PROXY=http://127.0.0.1:7897"
        "http_proxy=http://127.0.0.1:7897"
        "https_proxy=http://127.0.0.1:7897"
        "all_proxy=http://127.0.0.1:7897"
        "NO_PROXY=127.0.0.1,localhost,internal.domain"
        "no_proxy=127.0.0.1,localhost,internal.domain"
      ];
      # ZeroClaw reads config from ~/.zeroclaw/config.toml (sops template)
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
