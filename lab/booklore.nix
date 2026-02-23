{
  lib,
  config,
  pkgs,
  relations,
  ...
}:
let
  rel = relations.rcloneMounts;
in
{
  options.lab.booklore = {
    enable = lib.mkEnableOption "enable booklore lab configuration";
    port = lib.mkOption {
      type = lib.types.port;
      default = 6060;
      readOnly = true;
    };
  };

  config = lib.mkMerge [
    (lib.mkIf rel.isActive {
      lab.rcloneMounts.services."booklore" = {
        enable = true;
        allowOther = true;
        sshKeyPublic = lib.mkIf rel.isHost ../keys/id_sftp_booklore.pub;
        sshKeySecret = lib.mkIf rel.isClient config.sops.secrets."sftp-booklore-ssh-key".path;
      };
    })
    (lib.mkIf config.lab.booklore.enable {
      lab = {
        endpoints.hosts = {
          "booklore".caddy.extraConfig = "reverse_proxy 127.0.0.1:${toString config.lab.booklore.port}";
        };
        mysql = {
          enable = true;
        };
      };

      users.users.booklore = {
        group = "booklore";
        isSystemUser = true;
        uid = 994;
        linger = true;
        createHome = true;
        home = "/var/lib/containers/booklore";
        subUidRanges = [
          {
            startUid = 265536;
            count = 65536;
          }
        ];
        subGidRanges = [
          {
            startGid = 265536;
            count = 65536;
          }
        ];
      };
      users.groups.booklore.gid = 991;

      sops = {
        secrets = {
          "sftp-booklore-ssh-key" = {
            key = "sftp/booklore-ssh-key";
            owner = config.users.users.booklore.name;
            inherit (config.users.users.booklore) group;
          };
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
            owner = config.users.users.booklore.name;
            inherit (config.users.users.booklore) group;
          };
        };
      };

      virtualisation.oci-containers.containers."booklore" = {
        podman = {
          user = "booklore";
        };
        image = "booklore/booklore:latest";
        volumes = [
          "/replicated/apps/booklore/remote/bookdrop:/bookdrop"
          "/replicated/apps/booklore/remote/books:/books"
          "/replicated/apps/booklore/remote/data:/app/data"
        ];
        pull = "newer";
        extraOptions = [
          "--network=pasta:--tcp-ports,${toString config.lab.booklore.port},--tcp-ns,${toString config.services.mysql.settings.mysqld.port},--tcp-ns,${toString config.lab.postfix.port}"
          "--storage-opt=overlay.mount_program=${pkgs.fuse-overlayfs}/bin/fuse-overlayfs"
          "--storage-opt=overlay.mountopt=nodev,metacopy=on"
          "--user=0:0"
        ];
        environmentFiles = [
          config.sops.templates."booklore-env".path
        ];
        environment = {
          DATABASE_URL = "jdbc:mariadb://127.0.0.1:${toString config.services.mysql.settings.mysqld.port}/booklore";
          DATABASE_USERNAME = "booklore";
          BOOKLORE_PORT = toString config.lab.booklore.port;
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
              echo "CREATE USER IF NOT EXISTS 'booklore'@'127.0.0.1';"
              echo "ALTER USER 'booklore'@'127.0.0.1' IDENTIFIED BY '$(cat ${
                config.sops.secrets."mysql-booklore-password".path
              })';"
              echo "GRANT ALL PRIVILEGES ON booklore.* TO 'booklore'@'127.0.0.1';"
              echo "INSERT INTO booklore.email_provider_v2
                (user_id, name, host, port, username, password, from_address, auth, start_tls, is_default, shared)
                VALUES (1, 'Postfix', '127.0.0.1', ${toString config.lab.postfix.port}, \"\", \"\", 'Booklore Service <contact@${config.networking.domain}>', 0, 0, 1, 1)
                ON DUPLICATE KEY UPDATE
                  host = VALUES(host),
                  port = VALUES(port),
                  from_address = VALUES(from_address);"
              echo "FLUSH PRIVILEGES;"
            ) | ${config.services.mysql.package}/bin/mariadb -N
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
          bindsTo = [
            "rclone-booklore.service"
          ];
        };
      };
    })
  ];
}
