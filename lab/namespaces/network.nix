{
  lib,
  config,
  pkgs,
  net,
  writeZsh,
  ...
}:
let
  mkSetupNetworkScript =
    name: data:
    writeZsh "setup-network-${name}" /* zsh */ ''
      sysctl -w net.ipv4.ip_forward=1
      ip link set lo up
      ip link set vlan-${name} up
      ip addr replace ${net.ip net.${name} config.networking.hostName}/24 dev vlan-${name}
      ip addr replace ${net.ip6 net.${name} config.networking.hostName}/64 dev vlan-${name}
      ip neighbor replace 172.26.${toString net.${name}}.1 lladdr "${data.gatewayMac}" dev veth-${name}
      sysctl -w net.ipv4.conf.vlan-${name}.forwarding=1
      sysctl -w net.ipv4.conf.vlan-${name}.rp_filter=1
      ip link set veth-${name} up
      ip addr replace 172.26.${toString net.${name}}.2/30 dev veth-${name}
      ip route replace default via 172.26.${toString net.${name}}.1
      sysctl -w net.ipv4.conf.veth-${name}.forwarding=1
      sysctl -w net.ipv4.conf.veth-${name}.rp_filter=1
    '';
  enabledNamespaces = lib.filterAttrs (_: ns: ns.enable) config.lab.namespaces;
  namespaceConfigs = lib.mapAttrs mkSetupNetworkScript enabledNamespaces;
in
{
  config = {
    environment.etc = lib.concatMapAttrs (name: ns: {
      "netns/ns-${name}/hosts".text = ''
        127.0.0.1 localhost
        ::1 localhost
        127.0.0.2 ${lib.optionalString ns.search "${config.networking.hostName}.${config.networking.domain} "}${config.networking.hostName}
        ${ns.extraHosts}
      '';
      "netns/ns-${name}/resolv.conf".text = ''
        nameserver 127.0.0.1
        nameserver ::1
        nameserver ${net.ip net.${name} config.networking.hostName}
        nameserver ${net.ip6 net.${name} config.networking.hostName}
        ${lib.optionalString ns.search "search ${config.networking.domain}"}
        options edns0 trust-ad
      '';
    }) enabledNamespaces;
    systemd = {
      targets = {
        multi-user.wants = map (name: "setup-network@${name}.service") (lib.attrNames enabledNamespaces);
      };
      services = {
        "netns@" = {
          before = [ "network.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.iproute2}/bin/ip netns add ns-%i";
            ExecStop = "${pkgs.iproute2}/bin/ip netns del ns-%i";
          };
        };
        "move-netdev@" = {
          after = [ "netns@%i.service" ];
          requires = [ "netns@%i.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${
              writeZsh "move-netdev.zsh" /* zsh */ ''
                for i in {1..50}; do
                  if ${pkgs.iproute2}/bin/ip link show vlan-$1 >/dev/null 2>&1; then
                    ${pkgs.iproute2}/bin/ip link set vlan-$1 netns ns-$1
                    break
                  fi
                  sleep 0.1
                done
                for i in {1..50}; do
                  if ${pkgs.iproute2}/bin/ip link show veth-$1 >/dev/null 2>&1; then
                    ${pkgs.iproute2}/bin/ip link set veth-$1 netns ns-$1
                    break
                  fi
                  sleep 0.1
                done
              ''
            } %i";
          };
        };
        "setup-network@" = {
          after = [ "move-netdev@%i.service" ];
          requires = [ "move-netdev@%i.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            NetworkNamespacePath = "/run/netns/ns-%i";
            ExecStart = "${writeZsh "setup-netdevs-ns" ''
              ${lib.concatStrings (
                lib.mapAttrsToList (name: path: ''
                  if [[ "$1" == "${name}" ]]; then
                    exec ${path}
                  fi
                '') namespaceConfigs
              )}
              exit 1
            ''} %i";
          };
        };
      };
    };
  };
}
