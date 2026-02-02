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
    virtualisation.oci-containers.containers."booklore" = {
      image = "booklore/booklore:latest";
      volumes = [
        "/replicated/apps/booklore/bookdrop:/bookdrop"
        "/replicated/apps/booklore/books:/books"
        "/replicated/apps/booklore/data:/app/data"
      ];
      ports = [ "127.0.0.1:6060:6060" ];
      environment = {
        DATABASE_URL = "jdbc:mariadb://10.88.0.1:3306/booklore";
        DATABASE_USERNAME = "booklore";
        DATABASE_PASSWORD = "111";
        BOOKLORE_PORT = "6060";
        SWAGGER_ENABLED = "false";
      };
    };
    services.mysql = {
      ensureDatabases = [ "booklore" ];
      ensureUsers = [
        {
          name = "booklore@10.88.%";
          ensurePermissions = {
            "booklore.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };
    systemd.services."podman-booklore" = {
      after = [
        "rclone-replicated-apps.service"
        "mysql.service"
      ];
      requires = [
        "rclone-replicated-apps.service"
        "mysql.service"
      ];
    };
  };
}
