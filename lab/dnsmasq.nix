{
  config,
  lib,
  inventory,
  topology,
  net,
  ...
}:
let
  machine = inventory.${config.networking.hostName};
  top = topology.${machine.topology};
in
{
  options.lab.dnsmasq = {
    enable = lib.mkEnableOption "enable dnsmasq lab configuration";
  };

  config = lib.mkIf config.lab.dnsmasq.enable {
    lab.namespaces = {
      guest.firewall = {
        tcp = [
          53 # DNS
        ];
        udp = [
          53 # DNS
          67 # DHCPv4
          547 # DHCPv6
        ];
      };
    };
    systemd.services = {
      dnsmasq = {
        after = [ "setup-network@guest.service" ];
        requires = [ "setup-network@guest.service" ];
        serviceConfig = {
          BindPaths = [
            "/etc/netns/ns-guest/hosts:/etc/hosts"
            "/etc/netns/ns-guest/resolv.conf:/etc/resolv.conf"
          ];
          NetworkNamespacePath = "/run/netns/ns-guest";
        };
      };
    };
    services = {
      dnsmasq = {
        enable = true;
        settings = {
          bind-interfaces = true;
          bogus-priv = true;
          domain-needed = true;
          enable-ra = true;
          expand-hosts = true;
          interface = "vlan-guest";
          no-hosts = true;
          no-resolv = true;
          dhcp-host = lib.flatten (
            lib.mapAttrsToList (
              hostName: hostData:
              lib.optional (
                hostData ? mac && hostData != machine
              ) "${hostData.mac},${net.ip net.guest hostName},${hostName}"
            ) inventory
          );
          dhcp-option = [
            "option:router,${net.ip net.guest config.networking.hostName}"
            "option:dns-server,${net.ip net.guest config.networking.hostName}"
            "option:ntp-server,162.159.200.1" # time.cloudflare.com
            "option6:dns-server,[${net.ip6 net.guest config.networking.hostName}]"
          ];
          dhcp-range = [
            "${top.ipBase}.${toString net.guest}.127,${top.ipBase}.${toString net.guest}.254,24h"
            "::,constructor:vlan-guest,ra-stateless,64"
          ];
          server = [
            "9.9.9.9"
            "149.112.112.112"
          ];
        };
      };
    };
  };
}
