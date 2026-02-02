{
  lib,
  config,
  ...
}:

{
  options.lab.joplin = {
    enable = lib.mkEnableOption "enable joplin lab configuration";
  };

  config = lib.mkIf config.lab.joplin.enable {
    virtualisation.oci-containers.containers."joplin-server" = {
      image = "joplin/server:latest";
      volumes = [
        "/replicated/apps/joplin:/app/storage"
      ];
      ports = [ "127.0.0.1:22300:22300" ];
      environment = {
        APP_PORT = "22300";
        APP_BASE_URL = "https://joplin.hoppenr.xyz";

        DB_CLIENT = "pg";
        POSTGRES_HOST = "10.88.0.1";
        POSTGRES_PORT = "5432";
        POSTGRES_DATABASE = "joplin";
        POSTGRES_USER = "joplin";

        STORAGE_DRIVER = "Type=Filesystem; Path=/app/storage";

        MAILER_ENABLED = "1";
        MAILER_HOST = "10.88.0.1";
        MAILER_NOREPLY_EMAIL = "contact@hoppenr.xyz";
        MAILER_NOREPLY_NAME = "Joplin Service";
        MAILER_PORT = "25";
        MAILER_SECURITY = "none";
        MAILER_AUTH_USER = "";
        MAILER_AUTH_PASSWORD = "";
      };
    };

    # 2. Setup the existing Postgres service
    services.postgresql = {
      ensureDatabases = [ "joplin" ];
      ensureUsers = [
        {
          name = "joplin";
          ensureDBOwnership = true;
        }
      ];
      authentication = lib.mkAfter ''
        # TYPE  DATABASE    USER      ADDRESS         METHOD
        host    joplin      joplin    10.88.0.0/16    trust
      '';
    };

    systemd.services."podman-joplin-server" = {
      after = [
        "rclone-replicated-apps.service"
        "postgresql.service"
      ];
      requires = [
        "rclone-replicated-apps.service"
        "postgresql.service"
      ];
    };
  };
}
