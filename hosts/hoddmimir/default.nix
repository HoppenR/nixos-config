{
  config,
  inventory,
  topology,
  ...
}:
let
  machine = inventory.${config.networking.hostName};
  gateway = topology.${machine.topology}.gateway;
in
{
  imports = [
    ../../roles/storage.nix
    ./hardware-configuration.nix
  ];

  boot = {
    zfs = {
      forceImportRoot = true;
      extraPools = [ "holt" ];
    };
  };

  networking = {
    hostId = "299a21e5";
    hostName = "hoddmimir";
  };
  services = {
    zfs = {
      trim = {
        enable = true;
        interval = "monthly";
      };
    };
  };
  systemd.network = {
    links."20-lan0" = {
      matchConfig.MACAddress = "bc:24:11:14:eb:fb";
      linkConfig.Name = "lan0";
    };
    networks."40-lan0" = {
      matchConfig.Name = "lan0";
      networkConfig = {
        Address = [
          "${machine.ipv4}/24"
          "${machine.ipv6}/64"
        ];
        Gateway = [
          inventory.${gateway}.ipv4
          inventory.${gateway}.ipv6
        ];
        DNS = [ inventory.${gateway}.ipv4 ];
        Domains = [ config.networking.domain ];
        IPv6AcceptRA = true;
      };
    };
  };
  system.stateVersion = "25.11";
}
