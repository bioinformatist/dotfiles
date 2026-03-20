{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "rime-data-cantonese";
  version = "2026-03-07-unstable";

  src = fetchFromGitHub {
    owner = "rime";
    repo = "rime-cantonese";
    rev = "ec6ee73e83138fc47e658bbdc7a6b1d67e3075fc";
    hash = "sha256-ePoZAuAFk83DjybVpJMtpsITrYsQX2u1mqED29/zsag=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/rime-data
    cp *.yaml $out/share/rime-data/
    cp *.txt $out/share/rime-data/
    [ -d opencc ] && cp -r opencc $out/share/rime-data/

    runHook postInstall
  '';

  meta = {
    description = "Rime Cantonese (Jyutping) input schema";
    homepage = "https://github.com/rime/rime-cantonese";
    license = lib.licenses.cc-by-40;
    platforms = lib.platforms.all;
  };
}
