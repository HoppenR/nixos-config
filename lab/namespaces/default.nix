{
  lib,
  ...
}:
{
  imports = [
    ./network.nix
    ./nftables.nix
  ];

  options.lab.namespaces = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable namespace ${name}";
            };
            gatewayMac = lib.mkOption {
              type = lib.types.strMatching "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}";
              description = "MAC address for the egress neighbor (gateway) in the transit segment";
            };
            search = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether to include domain search in resolv.conf";
            };
            extraHosts = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Additional lines to append to this namespace /etc/hosts";
            };
            firewall = {
              tcp = lib.mkOption {
                type = lib.types.listOf lib.types.int;
                default = [ ];
              };
              udp = lib.mkOption {
                type = lib.types.listOf lib.types.int;
                default = [ ];
              };
              extraInputRules = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
              extraForwardRules = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
              extraReversePathFilterRules = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
            };
          };
        }
      )
    );
  };
}
