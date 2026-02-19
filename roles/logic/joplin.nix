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
    lab = {
      postfix = {
        enable = true;
        bridgePodman = true;
      };
      postgres = {
        enable = true;
      };
    };
    users.users.joplin = {
      group = "joplin";
      isSystemUser = true;
      uid = 992;
    };
    users.groups.joplin.gid = 989;

    virtualisation.oci-containers.containers."joplin-server" = {
      image = "joplin/server:latest";
      volumes = [
        "/run/postgresql:/run/postgresql"
        "/replicated/apps/joplin:/app/storage"
      ];
      ports = [ "127.0.0.1:22300:22300" ];
      extraOptions = [
        "--user=1001:1001"
        "--uidmap=0:100000:1"
        "--gidmap=0:100000:1"
        "--uidmap=1001:${toString config.users.users.joplin.uid}:1"
        "--gidmap=1001:${toString config.users.groups.joplin.gid}:1"
      ];

      environment = {
        APP_PORT = "22300";
        APP_BASE_URL = "https://joplin.${config.lab.domainName}";

        DB_CLIENT = "pg";
        POSTGRES_HOST = "/run/postgresql";
        POSTGRES_DATABASE = "joplin";
        POSTGRES_USER = "joplin";

        STORAGE_DRIVER = "Type=Filesystem; Path=/app/storage";

        MAILER_ENABLED = "1";
        MAILER_HOST = "10.88.0.1";
        MAILER_NOREPLY_EMAIL = "contact@${config.lab.domainName}";
        MAILER_NOREPLY_NAME = "Joplin Service";
        MAILER_PORT = "25";
        MAILER_SECURITY = "none";
        MAILER_AUTH_USER = "";
        MAILER_AUTH_PASSWORD = "";
      };
    };

    services.postgresql = {
      ensureDatabases = [ "joplin" ];
      ensureUsers = [
        {
          name = "joplin";
          ensureDBOwnership = true;
        }
      ];
    };

    systemd.services = {
      "podman-joplin-server" = {
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
  };
}
