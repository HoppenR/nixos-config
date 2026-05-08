{
  config,
  lib,
  pkgs,
  writeZsh,
  ...
}:
let
  mkNftRules =
    name: opts:
    pkgs.writeText "nftables-${name}.conf" ''
      flush ruleset
      table inet nixos-fw {
        chain rpfilter {
          type filter hook prerouting priority mangle + 10; policy drop;
          meta nfproto ipv4 udp sport . udp dport { 68 . 67, 67 . 68 } accept comment "DHCPv4 client/server"
          fib saddr . mark . iif oif exists accept
          jump rpfilter-allow
          log level info prefix "rpfilter drop: "
        }
        chain rpfilter-allow {
          ${opts.firewall.extraReversePathFilterRules}
        }
        chain input {
          type filter hook input priority filter; policy drop;
          iifname "lo" accept
          icmpv6 type echo-reply accept
          ct state vmap { invalid : drop, established : accept, related : accept, new : jump input-allow, untracked : jump input-allow }
        }
        chain input-allow {
          icmpv6 type != { nd-redirect, 139 } accept
          ip6 daddr fe80::/64 udp dport 546 accept comment "DHCPv6 client"
          ${lib.optionalString (
            opts.firewall.tcp != [ ]
          ) "tcp dport { ${lib.concatStringsSep ", " (map toString opts.firewall.tcp)} } accept"}
          ${lib.optionalString (
            opts.firewall.udp != [ ]
          ) "udp dport { ${lib.concatStringsSep ", " (map toString opts.firewall.udp)} } accept"}
          ${opts.firewall.extraInputRules}
        }
        chain forward {
          type filter hook forward priority filter; policy drop;
          ct state vmap { established : accept, related : accept, new : jump forward-allow, untracked : jump forward-allow }
        }
        chain forward-allow {
          icmpv6 type != { router-renumbering, 139 } accept
          ct status dnat accept comment "allow port forward"
          ${opts.firewall.extraForwardRules}
        }
      }
    '';
  enabledNamespaces = lib.filterAttrs (_: ns: ns.enable) config.lab.namespaces;
  ruleConfigs = lib.mapAttrs mkNftRules enabledNamespaces;
in
{
  config = {
    systemd = {
      targets.multi-user.wants = map (n: "nftables@${n}.service") (lib.attrNames enabledNamespaces);
      services."nftables@" = {
        description = "nftables firewall for namespace %i";
        bindsTo = [ "netns@%i.service" ];
        after = [ "netns@%i.service" ];
        before = [ "network.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          NetworkNamespacePath = "/run/netns/ns-%i";
          ExecStart = "${writeZsh "load-nft-ns" ''
            ${lib.concatStrings (
              lib.mapAttrsToList (name: path: ''
                if [[ "$1" == "${name}" ]]; then
                  exec ${pkgs.nftables}/bin/nft -f ${path}
                fi
              '') ruleConfigs
            )}
            exit 1
          ''} %i";
          ExecStop = "${pkgs.nftables}/bin/nft flush ruleset";
        };
      };
    };
  };
}
