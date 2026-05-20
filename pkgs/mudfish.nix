{
  autoPatchelfHook,
  dhcpcd,
  elfutils,
  fetchurl,
  glib,
  gtk3,
  iproute2,
  lib,
  libayatana-appindicator,
  ncurses,
  nettools,
  openssl,
  procps,
  stdenv,
  zlib,
}:

stdenv.mkDerivation rec {
  pname = "mudfish";
  version = "6.5.2";

  src = fetchurl {
    url = "https://mudfish.net/releases/mudfish-${version}-linux-x86_64.sh";
    hash = "sha256-z2ldR0gMNvIGeJEgELboIc49HSBE4mlWoV8Pv62fd+Q=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    elfutils
    glib
    gtk3
    libayatana-appindicator
    ncurses
    openssl
    stdenv.cc.cc.lib
    zlib
  ];

  unpackPhase = ''
    runHook preUnpack
    sh "$src" --target source --noexec
    cd source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -dm755 "$out/opt/mudfish/${version}"
    cp -a bin etc sbin share "$out/opt/mudfish/${version}/"

    install -dm755 "$out/bin"
    install -dm755 "$out/libexec/mudfish"
    cat > "$out/libexec/mudfish/dhclient" <<'EOF'
    #!${stdenv.shell}
    pidfile=
    release=0
    iface=

    while [ "$#" -gt 0 ]; do
      case "$1" in
        -pf)
          pidfile="$2"
          shift 2
          ;;
        -r)
          release=1
          shift
          ;;
        -d)
          shift
          ;;
        -*)
          shift
          ;;
        *)
          iface="$1"
          shift
          ;;
      esac
    done

    if [ -z "$iface" ]; then
      echo "dhclient compatibility wrapper: missing interface" >&2
      exit 1
    fi

    ${iproute2}/bin/ip link set "$iface" up || true
    ${iproute2}/bin/ip route replace 10.254.0.1 dev "$iface" || true

    if [ "$release" = 1 ]; then
      ${dhcpcd}/bin/dhcpcd -k "$iface" || true
      ${iproute2}/bin/ip route del 10.254.0.1 dev "$iface" 2>/dev/null || true
      [ -n "$pidfile" ] && rm -f "$pidfile"
      exit 0
    fi

    ${dhcpcd}/bin/dhcpcd -4 -G -f /dev/null -t 30 --nohook resolv.conf --nohook hostname "$iface"
    status=$?
    if [ "$status" = 0 ] && [ -n "$pidfile" ]; then
      ${procps}/bin/pidof dhcpcd > "$pidfile" 2>/dev/null || true
    fi
    exit "$status"
    EOF
    chmod 755 "$out/libexec/mudfish/dhclient"

    cat > "$out/bin/mudrun-headless" <<EOF
    #!${stdenv.shell}
    export PATH="$out/libexec/mudfish:${
      lib.makeBinPath [
        iproute2
        nettools
      ]
    }:\$PATH"
    exec /opt/mudfish/${version}/bin/mudrun-headless "\$@"
    EOF
    cat > "$out/bin/mudrun" <<EOF
    #!${stdenv.shell}
    export PATH="$out/libexec/mudfish:${
      lib.makeBinPath [
        iproute2
        nettools
      ]
    }:\$PATH"
    exec /opt/mudfish/${version}/bin/mudrun "\$@"
    EOF
    chmod 755 "$out/bin/mudrun-headless" "$out/bin/mudrun"

    runHook postInstall
  '';

  meta = {
    description = "Mudfish Cloud VPN";
    homepage = "https://mudfish.net/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "mudrun-headless";
  };
}
