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
        bridgePodman = true;
      };
    };
    sops = {
      secrets = {
        "postgresql-joplin-password" = {
          key = "postgresql/joplin-password";
          owner = config.users.users.postgres.name;
          inherit (config.users.users.postgres) group;
        };
      };
      templates = {
        "joplin-server-env" = {
          content = ''
            POSTGRES_PASSWORD=${config.sops.placeholder."postgresql-joplin-password"}
          '';
        };
      };
    };
    virtualisation.oci-containers.containers."joplin-server" = {
      image = "joplin/server:latest";
      volumes = [
        "/replicated/apps/joplin:/app/storage"
      ];
      ports = [ "127.0.0.1:22300:22300" ];
      environmentFiles = [
        config.sops.templates."joplin-server-env".path
      ];
      environment = {
        APP_PORT = "22300";
        APP_BASE_URL = "https://joplin.${config.lab.domainName}";

        DB_CLIENT = "pg";
        POSTGRES_HOST = "10.88.0.1";
        POSTGRES_PORT = "5432";
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
      authentication = lib.mkAfter ''
        # TYPE  DATABASE  USER        ADDRESS         METHOD
        host    joplin    joplin      10.88.0.0/16    scram-sha-256
      '';
    };

    systemd.services = {
      postgresql-setup = {
        restartTriggers = [
          config.sops.secrets."postgresql-joplin-password".path
        ];
        script = lib.mkAfter /* bash */ ''
          psql -tAc "ALTER USER joplin WITH PASSWORD '$(cat ${config.sops.secrets.postgresql-joplin-password.path})';"
        '';
      };
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
