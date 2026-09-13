{
  appimageTools,
  fetchurl,
  lib,
}:

let
  pname = "orca-ide";
  orcaVersion = "1.4.201";
  orcaHash = "sha256-wz3WY7pC5LF+WLHvvqW7GyJ2etMgu7zeoGsnwibFI7Q=";

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${orcaVersion}/orca-linux.AppImage";
    hash = orcaHash;
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname src;
    version = orcaVersion;
  };
in
appimageTools.wrapType2 {
  inherit pname src;
  version = orcaVersion;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/orca-ide.desktop -t $out/share/applications/
    cp -r ${appimageContents}/usr/share/icons $out/share/
    substituteInPlace $out/share/applications/orca-ide.desktop \
      --replace-fail 'Exec=AppRun %U' 'Exec=orca-ide %U'
  '';

  extraPkgs = pkgs: [
    pkgs.at-spi2-core
  ];

  meta = {
    description = "Agent development environment for running coding agents in isolated worktrees";
    homepage = "https://github.com/stablyai/orca";
    changelog = "https://github.com/stablyai/orca/releases/tag/v${orcaVersion}";
    license = lib.licenses.mit;
    mainProgram = "orca-ide";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
