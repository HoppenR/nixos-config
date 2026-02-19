{
  config,
  lib,
  ...
}:
{
  options.lab.postgres = {
    enable = lib.mkEnableOption "enable postgres lab configuration";
  };

  config = lib.mkIf config.lab.postgres.enable {
    services = {
      postgresql = {
        enable = true;
        dataDir = "/replicated/db/postgres";
        initdbArgs = [ "--data-checksums" ];
        settings = {
          full_page_writes = "off";
        };
      };
    };
  };
}
