{
  lib,
  config,
  ...
}:
{
  options.lab.booklore = {
    enable = lib.mkEnableOption "enable booklore lab configuration";
  };

  config = lib.mkIf config.lab.booklore.enable {
    lab.mysql = {
      enable = true;
      bridgePodman = true;
    };
    sops = {
      secrets = {
        "mysql-booklore-password" = {
          key = "mysql/booklore-password";
          owner = config.users.users.mysql.name;
          inherit (config.users.users.mysql) group;
        };
      };
      templates = {
        "booklore-env" = {
          content = ''
            DATABASE_PASSWORD=${config.sops.placeholder."mysql-booklore-password"}
          '';
        };
      };
    };
    virtualisation.oci-containers.containers."booklore" = {
      image = "booklore/booklore:latest";
      volumes = [
        "/replicated/apps/booklore/remote/bookdrop:/bookdrop"
        "/replicated/apps/booklore/remote/books:/books"
        "/replicated/apps/booklore/remote/data:/app/data"
      ];
      ports = [ "127.0.0.1:6060:6060" ];
      environmentFiles = [
        config.sops.templates."booklore-env".path
      ];
      environment = {
        DATABASE_URL = "jdbc:mariadb://host.containers.internal:${toString config.services.mysql.settings.mysqld.port}/booklore";
        DATABASE_USERNAME = "booklore";
        BOOKLORE_PORT = "6060";
        SWAGGER_ENABLED = "false";
      };
    };
    services.mysql = {
      ensureDatabases = [ "booklore" ];
    };
    systemd.services = {
      mysql = {
        postStart = lib.mkAfter /* bash */ ''
          (
            echo "CREATE USER IF NOT EXISTS 'booklore'@'10.88.%';"
            echo "ALTER USER 'booklore'@'10.88.%' IDENTIFIED BY '$(cat ${
              config.sops.secrets."mysql-booklore-password".path
            })';"
            echo "GRANT ALL PRIVILEGES ON booklore.* TO 'booklore'@'10.88.%';"
            echo "FLUSH PRIVILEGES;"
          ) | ${config.services.mysql.package}/bin/mysql -N
        '';
        restartTriggers = [
          config.sops.secrets."mysql-booklore-password".path
        ];
      };
      "podman-booklore" = {
        after = [
          "rclone-booklore.service"
          "mysql.service"
        ];
        requires = [
          "rclone-booklore.service"
          "mysql.service"
        ];
      };
    };
  };
}
