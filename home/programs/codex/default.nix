{ inputs }:

{
  config,
  lib,
  ...
}:

let
  cfg = config.dotfiles.codex;
in
{
  imports = [
    inputs.codex-base.homeManagerModules.default
  ];

  options.dotfiles.codex = {
    trustedProjects = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "Extra project roots that Codex should treat as trusted.";
    };

    writableRoots = lib.mkOption {
      type = with lib.types; listOf str;
      default = [
        "${config.home.homeDirectory}/.codex/memories"
      ];
      description = "Extra directories that Codex may write in workspace-write mode.";
    };

    githubTokenFile = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to a GitHub token file used by the GitHub MCP server.";
    };

    context7ApiKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to a Context7 API key file used by the authenticated fallback MCP server.";
    };

    stopSlop.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the stop-slop Codex prose-editing skill.";
    };

    ponytail.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the complete Ponytail Codex skill bundle; Improve independently requires ponytail-review.";
    };

    mattPocockSkills.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install a narrow global subset of Matt Pocock's engineering Codex skills.";
    };

    improve.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the Codex-adapted Improve workflow and its isolated executors and reviewers.";
    };

    personalRules.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to add the broader command rules used by a personal workstation operator.";
    };
  };

  config = {
    programs.codexBase = {
      enable = true;
      trustedProjects = cfg.trustedProjects;
      writableRoots = cfg.writableRoots;
      githubTokenFile = if cfg.githubTokenFile == "" then null else cfg.githubTokenFile;
      context7ApiKeyFile = if cfg.context7ApiKeyFile == "" then null else cfg.context7ApiKeyFile;
      stopSlop.enable = cfg.stopSlop.enable;
      ponytail.enable = cfg.ponytail.enable;
      mattPocockSkills.enable = cfg.mattPocockSkills.enable;
      improve.enable = cfg.improve.enable;
    };

    home.file.".codex/rules/personal.rules" = lib.mkIf cfg.personalRules.enable {
      text = ''
        prefix_rule(pattern=["nl", "-ba"], decision="allow")
        prefix_rule(pattern=["wc"], decision="allow")
        prefix_rule(pattern=["stat"], decision="allow")
        prefix_rule(pattern=["file"], decision="allow")

        prefix_rule(pattern=["env", "NIXPKGS_ALLOW_UNFREE=1", "nix", "flake", "check"], decision="allow")
        prefix_rule(pattern=["nix", "flake", "update"], decision="allow")
        prefix_rule(pattern=["nix", "flake", "show"], decision="allow")
        prefix_rule(pattern=["nix", "flake", "metadata"], decision="allow")
        prefix_rule(pattern=["nix", "path-info"], decision="allow")
        prefix_rule(pattern=["nix", "config", "show"], decision="allow")

        prefix_rule(pattern=["git", "branch"], decision="allow")
        prefix_rule(pattern=["git", "ls-files"], decision="allow")

        prefix_rule(pattern=["systemctl", "is-active"], decision="allow")
        prefix_rule(pattern=["systemctl", "status"], decision="allow")
        prefix_rule(pattern=["systemctl", "show"], decision="allow")
        prefix_rule(pattern=["systemctl", "list-units"], decision="allow")

        prefix_rule(pattern=["date"], decision="allow")
        prefix_rule(pattern=["uname"], decision="allow")
        prefix_rule(pattern=["hostname"], decision="allow")
        prefix_rule(pattern=["uptime"], decision="allow")
        prefix_rule(pattern=["df"], decision="allow")
        prefix_rule(pattern=["free"], decision="allow")
      '';
    };
  };
}
