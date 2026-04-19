{
  lib,
  config,
  pkgs,
  relations,
  net,
  ...
}:
let
  rel = relations.rcloneMounts;
in
{
  options.lab.nextcloud = {
    enable = lib.mkEnableOption "enable nextcloud lab configuration";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      readOnly = true;
    };
    machine = lib.mkOption {
      type = lib.types.addCheck lib.types.attrs (attrs: (attrs ? id));
      description = "attribute set containing at least 'id'";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf rel.isActive {
      lab.rcloneMounts.services."nextcloud" = {
        enable = true;
        allowOther = true;
        mountpoint = "data";
        sshKeyPublic = lib.mkIf rel.isHost ../keys/id_sftp_nextcloud.pub;
        sshKeySecret = lib.mkIf rel.isClient config.sops.secrets."sftp-nextcloud-ssh-key".path;
      };
    })
    (lib.mkIf config.lab.nextcloud.enable {
      lab = {
        endpoints.hosts = {
          "cloud".caddy.extraConfig = ''
            root ${config.services.nginx.virtualHosts."cloud.${config.networking.domain}".root}
            file_server
            encode zstd gzip
            header {
              ?Permissions-Policy interest-cohort=()
              ?Referrer-Policy no-referrer
              ?Strict-Transport-Security "max-age=31536000; includeSubDomains"
              ?X-Content-Type-Options nosniff
              ?X-Frame-Options sameorigin
              ?X-Permitted-Cross-Domain-Policies none
              ?X-Robots-Tag "noindex, nofollow"
              ?X-XSS-Protection "1; mode=block"
              -X-Powered-By
            }
            handle_path /push/* {
              reverse_proxy unix/${config.services.nextcloud.notify_push.socketPath} {
                header_up Host {host}
                flush_interval -1
              }
            }
            redir /.well-known/carddav /remote.php/dav/ 301
            redir /.well-known/caldav /remote.php/dav/ 301
            rewrite /.well-known/host-meta /public.php?service=host-meta
            rewrite /.well-known/host-meta.json /public.php?service=host-meta-json

            @forbidden {
                path /build/* /tests/* /config/* /lib/* /3rdparty/* /templates/*
                path /data/* /autotest* /occ* /issue* /indie* /db_* /console*
                path /.*
                not path /.well-known/*
            }
            error @forbidden 404

            @is_versioned {
                path *.css *.js *.mjs *.svg *.gif *.ico *.jpg *.jpeg *.png *.webp *.wasm *.tflite *.map *.ttf
                query v=*
            }
            @not_versioned {
                path *.css *.js *.mjs *.svg *.gif *.ico *.jpg *.jpeg *.png *.webp *.wasm *.tflite *.map *.ttf
                not query v=*
            }
            header @is_versioned Cache-Control "max-age=15778463, immutable"
            header @not_versioned Cache-Control "max-age=15778463"

            php_fastcgi unix/${config.services.phpfpm.pools.nextcloud.socket} {
              env front_controller_active true
              env modHeadersAvailable true
            }
          '';
        };
      };

      sops.secrets = {
        "nextcloud-adminpass" = {
          key = "nextcloud/adminpass";
          owner = config.users.users.nextcloud.name;
          inherit (config.users.users.nextcloud) group;
        };
        "sftp-nextcloud-ssh-key" = {
          key = "sftp/nextcloud-ssh-key";
          owner = config.users.users.nextcloud.name;
          inherit (config.users.users.nextcloud) group;
        };
      };

      users = {
        users = {
          nextcloud = {
            uid = 990;
            extraGroups = [ "redis-nextcloud" ];
          };
        };
        groups.nextcloud = {
          members = lib.mkForce [
            config.users.users.nextcloud.name
            # for access to config.services.nextcloud.notify_push.socketPath
            config.users.users.caddy.name
          ];
          gid = 987;
        };
      };

      systemd.services = {
        "caddy" = {
          after = [ "nextcloud-notify_push.service" ];
          wants = [ "nextcloud-notify_push.service" ];
          serviceConfig = {
            ReadWritePaths = [ config.services.nextcloud.notify_push.socketPath ];
          };
        };
        "redis-nextcloud" = {
          after = [ "rclone-nextcloud.service" ];
          requires = [ "rclone-nextcloud.service" ];
          bindsTo = [ "rclone-nextcloud.service" ];
        };
        "nextcloud-setup" = {
          after = [
            "rclone-nextcloud.service"
            "redis-nextcloud.service"
          ];
          requires = [
            "rclone-nextcloud.service"
            "redis-nextcloud.service"
          ];
          bindsTo = [ "rclone-nextcloud.service" ];
        };
        "phpfpm-nextcloud" = {
          after = [
            "rclone-nextcloud.service"
            "redis-nextcloud.service"
            "nextcloud-setup.service"
          ];
          requires = [
            "rclone-nextcloud.service"
            "nextcloud-setup.service"
          ];
          bindsTo = [ "rclone-nextcloud.service" ];
        };
      };

      services = {
        nextcloud = {
          enable = true;
          datadir = "/replicated/apps/nextcloud";
          extraAppsEnable = true;
          hostName = "cloud.${config.networking.domain}";
          https = true;
          maxUploadSize = "10G";
          package = pkgs.nextcloud33;

          # configureRedis runs redis as the nextcloud user instead of the
          # intended redis-nextcloud user
          caching.redis = true;
          configureRedis = false;

          appstoreEnable = false;
          extraApps = {
            inherit (config.services.nextcloud.package.packages.apps)
              calendar
              # notify_push
              ;
          };
          notify_push.enable = true;

          settings = {
            default_phone_region = "SE";
            "memcache.local" = "\\OC\\Memcache\\APCu";
            "memcache.distributed" = "\\OC\\Memcache\\Redis";
            "memcache.locking" = "\\OC\\Memcache\\Redis";
            mail_domain = config.networking.domain;
            mail_from_address = "contact";
            mail_sendmailmode = "smtp";
            mail_smtpauth = false;
            mail_smtphost = "127.0.0.1";
            mail_smtpport = 25;
            mail_smtpsecure = "";
            redis = {
              host = config.services.redis.servers.nextcloud.unixSocket;
              port = 0;
            };
            trusted_proxies = [
              "127.0.0.1"
              "::1"
              (net.ip net.mgmt config.networking.hostName)
              (net.ip6 net.mgmt config.networking.hostName)
            ];
          };
          config = {
            adminpassFile = config.sops.secrets."nextcloud-adminpass".path;
            adminuser = "admin";
            dbtype = "pgsql";
            dbuser = "nextcloud";
          };
          database.createLocally = true;
        };
        phpfpm = {
          pools.nextcloud.settings = {
            catch_workers_output = "yes";
            "listen.owner" = config.users.users.caddy.name;
            "listen.group" = config.users.groups.caddy.name;
          };
        };
        redis.servers = {
          nextcloud.enable = true;
        };
      };
    })
  ];
}
