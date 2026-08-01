{
  appimageTools,
  fetchurl,
  lib,
}:

let
  pname = "orca-ide";
  orcaVersion = "1.4.163";
  orcaHash = "sha256-OWphybstsEMdTSOqqKUcR2+HW1mxWQYj2JFPsnpVIEk=";

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
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=orca-ide %U'
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
