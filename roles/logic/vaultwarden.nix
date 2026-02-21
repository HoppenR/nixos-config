{
  lib,
  config,
  ...
}:
{
  options.lab.vaultwarden = {
    enable = lib.mkEnableOption "enable vaultwarden lab configuration";
  };

  config = lib.mkIf config.lab.vaultwarden.enable {
    lab = {
      postfix.enable = true;
      postgres.enable = true;
    };
    sops = {
      secrets = {
        "vaultwarden-admin-token" = {
          key = "vaultwarden/admin-token";
          owner = config.users.users.vaultwarden.name;
          inherit (config.users.users.vaultwarden) group;
        };
      };
      templates = {
        "vaultwarden-env" = {
          content = ''
            ADMIN_TOKEN='${config.sops.placeholder."vaultwarden-admin-token"}'
          '';
        };
      };
    };
    services = {
      vaultwarden = {
        enable = true;
        dbBackend = "postgresql";
        configurePostgres = true;
        domain = "vaultwarden.${config.networking.domain}";
        environmentFile = config.sops.templates."vaultwarden-env".path;
        config = {
          ROCKET_ADDRESS = "::1";
          ROCKET_PORT = 8222;
          SIGNUPS_ALLOWED = false;
          SMTP_FROM = "contact@${config.networking.domain}";
          SMTP_FROM_NAME = "Vaultwarden Service";
          SMTP_HOST = "127.0.0.1";
          SMTP_PORT = 25;
          SMTP_SECURITY = "off";
        };
      };
    };

    systemd.services = {
      vaultwarden = {
        restartTriggers = [
          config.sops.templates."vaultwarden-env".path
        ];
      };
    };
  };
}
