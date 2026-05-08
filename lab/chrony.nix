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
  options.lab.chrony = {
    enable = lib.mkEnableOption "enable chrony lab configuration";
  };

  config = lib.mkIf config.lab.chrony.enable {
    lab.namespaces = {
      mgmt.firewall = {
        udp = [
          123 # NTP
          323 # Chrony control
        ];
      };
    };
    systemd.services = {
      chronyd = {
        after = [ "setup-network@mgmt.service" ];
        requires = [ "setup-network@mgmt.service" ];
        serviceConfig = {
          BindPaths = [
            "/etc/netns/ns-mgmt/hosts:/etc/hosts"
            "/etc/netns/ns-mgmt/resolv.conf:/etc/resolv.conf"
          ];
          NetworkNamespacePath = "/run/netns/ns-mgmt";
        };
      };
    };
    services = {
      chrony = {
        enable = true;
        enableNTS = true;
        extraConfig = ''
          allow ${net.subnet net.mgmt top}
          allow ${net.subnet6 net.mgmt top}
          bindaddress ${net.ip net.mgmt config.networking.hostName}
          bindaddress ${net.ip6 net.mgmt config.networking.hostName}
        '';
        servers = [
          "nts.netnod.se"
          "nts.ntp.se"
        ];
      };
    };
  };
}
