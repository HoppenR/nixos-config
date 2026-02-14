{
  config,
  lib,
  ...
}:
{
  options.lab.postgres = {
    enable = lib.mkEnableOption "enable postgres lab configuration";
    bridgePodman = lib.mkEnableOption "access from podman0 bridge";
  };

  config = lib.mkIf config.lab.postgres.enable {
    services = {
      postgresql = {
        enable = true;
        dataDir = "/replicated/db/postgres";
        initdbArgs = [ "--data-checksums" ];
        settings = {
          full_page_writes = "off";
          listen_addresses = lib.mkForce "*";
        };
      };
    };
    networking.firewall.extraInputRules = lib.mkIf config.lab.postgres.bridgePodman ''
      iifname "podman0" tcp dport 5432 accept
    '';
  };
}
