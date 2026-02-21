{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.lab.mysql = {
    enable = lib.mkEnableOption "enable mysql lab configuration";
    bridgePodman = lib.mkEnableOption "access from podman0 bridge";
  };

  config = lib.mkIf config.lab.mysql.enable {
    services = {
      mysql = {
        enable = true;
        package = pkgs.mariadb;
        dataDir = "/replicated/db/mariadb";
        settings.mysqld = {
          innodb_checksum_algorithm = "crc32";
          innodb_doublewrite = 0;
          innodb_flush_method = "O_DIRECT";
          innodb_page_size = "16k";
          innodb_use_atomic_writes = 0;
          innodb_use_native_aio = 0;
          bind-address = if config.lab.mysql.bridgePodman then "127.0.0.1,10.88.0.1" else "127.0.0.1";
        };
      };
    };
    # TODO:
    # Move to pasta
    # - OR -
    # networking.firewall.interfaces."podman0".allowedTCPPorts = [ config.services.mysql.settings.mysqld.port ];
    networking.firewall.extraInputRules = lib.mkIf config.lab.mysql.bridgePodman ''
      iifname "podman0" tcp dport ${toString config.services.mysql.settings.mysqld.port} accept
    '';
  };
}
