{ pkgs, ... }:

let
  mudfishRoot = "/opt/mudfish/${pkgs.mudfish.version}";
  mudfishStoreRoot = "${pkgs.mudfish}/opt/mudfish/${pkgs.mudfish.version}";
  mudfishDhclient = "${pkgs.mudfish}/libexec/mudfish/dhclient";
in
{
  environment.systemPackages = [
    pkgs.mudfish
  ];

  systemd.tmpfiles.rules = [
    "d /opt 0755 root root -"
    "d /opt/mudfish 0755 root root -"
    "d ${mudfishRoot} 0755 root root -"
    "L+ ${mudfishRoot}/bin - - - - ${mudfishStoreRoot}/bin"
    "L+ ${mudfishRoot}/etc - - - - ${mudfishStoreRoot}/etc"
    "L+ ${mudfishRoot}/sbin - - - - ${mudfishStoreRoot}/sbin"
    "L+ ${mudfishRoot}/share - - - - ${mudfishStoreRoot}/share"
    "d ${mudfishRoot}/var 0755 root root -"

    "d /usr/sbin 0755 root root -"
    "L+ /usr/sbin/ip - - - - ${pkgs.iproute2}/bin/ip"
    "L+ /usr/sbin/ifconfig - - - - ${pkgs.nettools}/bin/ifconfig"
    "L+ /usr/sbin/route - - - - ${pkgs.nettools}/bin/route"
    "L+ /usr/sbin/iptables - - - - ${pkgs.iptables}/bin/iptables"
    "L+ /usr/sbin/sysctl - - - - ${pkgs.procps}/bin/sysctl"
    "L+ /usr/sbin/dhclient - - - - ${mudfishDhclient}"

    "d /sbin 0755 root root -"
    "L+ /sbin/ifconfig - - - - ${pkgs.nettools}/bin/ifconfig"
    "L+ /sbin/route - - - - ${pkgs.nettools}/bin/route"
    "L+ /sbin/iptables - - - - ${pkgs.iptables}/bin/iptables"
    "L+ /sbin/dhclient - - - - ${mudfishDhclient}"
  ];
}
