{
  pkgs,
  lib,
  config,
  topology,
  ...
}:
let
  rcloneMount = "skadi";
  sftpHost = "hoddmimir";
  sftpHostNode = topology.${sftpHost};
  # TODO: make this list into an option.lab.apps so that each service
  #       can add to this in a respective file
  # Requires ssh key:
  #   public:  ../keys/id_sftp_${name}.pub
  #   private: sftp/${name}-ssh-key (sops)
  # Provides for rcloneMount:
  #   service-private remote storage at /replicated/apps/${name}/remote
  apps = {
    "booklore" = { };
    "joplin" = { };
    "syncthing" = {
      allowOther = false;
    };
  };

  mkRcloneMount =
    {
      name,
      group ? name,
      allowOther ? true,
    }:
    {
      description = "Rclone mount for ${name}";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ "/run/wrappers" ];
      serviceConfig = {
        Type = "notify";
        CacheDirectory = "rclone-${name}";
        ExecStart =
          let
            ssh-key-path = config.sops.secrets."sftp-${name}-ssh-key".path;
            args = [
              ":sftp,host=${sftpHostNode.ipv4},user=sftpuser-${name},key_file=${ssh-key-path}:/files"
              "/replicated/apps/${name}/remote"
              "--config=/dev/null"
              "--vfs-cache-mode=full"
              "--vfs-cache-max-size=4Gi"
              "--vfs-write-back=5m"
              "--cache-dir=%C/rclone-${name}"
              "--uid=${toString config.users.users.${name}.uid}"
              "--gid=${toString config.users.groups.${group}.gid}"
              "--dir-cache-time=48h"
              "--attr-timeout=48h"
              "--vfs-cache-max-age=48h"
            ]
            ++ lib.optionals allowOther [ "--allow-other" ];
          in
          "${lib.getExe pkgs.rclone} mount ${lib.escapeShellArgs args}";
        ExecStop = "${pkgs.fuse}/bin/fusermount3 -u -z /replicated/apps/${name}/remote";
        Restart = "on-failure";
        User = name;
        Group = group;
      };
    };

  makeSftpMatchBlock = name: ''
    Match User sftpuser-${name}
      ChrootDirectory /srv/sftp/apps/${name}
      ForceCommand internal-sftp
      PasswordAuthentication no
      AllowTcpForwarding no
      X11Forwarding no
  '';

  makeSftpUser = name: {
    groups."sftpuser-${name}" = { };
    users."sftpuser-${name}" = {
      isSystemUser = true;
      home = "/"; # Note that this is relative to the ChrootDirectory
      group = "sftpuser-${name}";
      openssh.authorizedKeys.keyFiles = [ ../keys/id_sftp_${name}.pub ];
    };
  };
in
{
  config = lib.mkMerge [
    (lib.mkIf (config.networking.hostName == rcloneMount) {
      sops.secrets = lib.mapAttrs' (
        name: _:
        lib.nameValuePair "sftp-${name}-ssh-key" {
          key = "sftp/${name}-ssh-key";
          owner = config.users.users.${name}.name;
          inherit (config.users.users.${name}) group;
        }
      ) apps;
      systemd.services = lib.mapAttrs' (
        name: cfg: lib.nameValuePair "rclone-${name}" (mkRcloneMount ({ inherit name; } // cfg))
      ) apps;
    })
    (lib.mkIf (config.networking.hostName == sftpHost) {
      users = lib.mkMerge (map makeSftpUser (lib.attrNames apps));
      services = {
        openssh.extraConfig = lib.concatStringsSep "\n" (map makeSftpMatchBlock (lib.attrNames apps));

        sanoid = {
          enable = true;
          datasets = {
            "holt/replicated/apps" = {
              autosnap = true;
              autoprune = true;
              recursive = true;

              hourly = 0;
              daily = 30;
              weekly = 4;
              monthly = 6;
              yearly = 0;
            };
          };
        };
      };
      systemd.tmpfiles.rules = (
        lib.concatLists (
          map (name: [
            "d /srv/sftp/apps/${name} 0755 root root - -"
            "d /srv/sftp/apps/${name}/files 0700 sftpuser-${name} sftpuser-${name} - -"
          ]) (lib.attrNames apps)
        )
      );
    })
  ];
}
