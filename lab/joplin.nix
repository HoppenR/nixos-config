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
  options.lab.joplin = {
    enable = lib.mkEnableOption "enable joplin lab configuration";
  };

  config = lib.mkMerge [
    (lib.mkIf rel.isActive {
      lab.rcloneMounts.services."joplin" = {
        enable = true;
        allowOther = true;
        sshKeyPublic = lib.mkIf rel.isHost ../keys/id_sftp_joplin.pub;
        sshKeySecret = lib.mkIf rel.isClient config.sops.secrets."sftp-joplin-ssh-key".path;
      };
    })
    (lib.mkIf config.lab.joplin.enable {
      lab = {
        endpoints.hosts = {
          "joplin".caddy.extraConfig = "reverse_proxy 127.0.0.1:${
            config.virtualisation.oci-containers.containers."joplin-server".environment.APP_PORT
          }";
        };
        postfix = {
          enable = true;
        };
        postgres = {
          enable = true;
        };
      };
      sops.secrets = {
        "sftp-joplin-ssh-key" = {
          key = "sftp/joplin-ssh-key";
          owner = config.users.users.joplin.name;
          inherit (config.users.users.joplin) group;
        };
      };
      users.users.joplin = {
        group = "joplin";
        isSystemUser = true;
        uid = 992;
        linger = true;
        createHome = true;
        home = "/var/lib/containers/joplin";
        subUidRanges = [
          {
            startUid = 200000;
            count = 65536;
          }
        ];
        subGidRanges = [
          {
            startGid = 200000;
            count = 65536;
          }
        ];
      };
      users.groups.joplin.gid = 989;

      virtualisation.oci-containers.containers."joplin-server" = rec {
        podman = {
          user = "joplin";
        };
        image = "joplin/server:latest";
        volumes = [
          "/run/postgresql:/run/postgresql"
          "/replicated/apps/joplin/remote:/app/storage"
        ];
        pull = "newer";
        extraOptions = [
          "--network=pasta:--tcp-ports,${environment.APP_PORT},--tcp-ns,${toString config.lab.postfix.port}"
          "--storage-opt=overlay.mount_program=${pkgs.fuse-overlayfs}/bin/fuse-overlayfs"
          "--storage-opt=overlay.mountopt=nodev,metacopy=on"
          "--user=1001:1001"
          "--userns=keep-id:uid=1001,gid=1001"
        ];

        environment = {
          APP_PORT = "22300";
          APP_BASE_URL = "https://joplin.${config.networking.domain}";

          DB_CLIENT = "pg";
          POSTGRES_HOST = "/run/postgresql";
          POSTGRES_DATABASE = "joplin";
          POSTGRES_USER = "joplin";

          STORAGE_DRIVER = "Type=Filesystem; Path=/app/storage";

          MAILER_ENABLED = "1";
          MAILER_HOST = "127.0.0.1";
          MAILER_NOREPLY_EMAIL = "contact@${config.networking.domain}";
          MAILER_NOREPLY_NAME = "Joplin Service";
          MAILER_PORT = toString config.lab.postfix.port;
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
            "rclone-joplin.service"
            "postgresql.service"
          ];
          requires = [
            "rclone-joplin.service"
            "postgresql.service"
          ];
          bindsTo = [
            "rclone-joplin.service"
          ];
        };
      };
    })
  ];
}
