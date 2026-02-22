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

  mkRcloneMount =
    {
      name,
      group ? name,
      allowOther ? true,
      sshKeySecret,
      ...
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
            args = [
              ":sftp,host=${sftpHostNode.ipv4},user=sftpuser-${name},key_file=${sshKeySecret}:/files"
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

  enabledMountpoints = lib.filterAttrs (_: v: v.enable) config.lab.rcloneMounts.services;
in
{
  options.lab.rcloneMounts = {
    isMountHost = lib.mkOption {
      type = lib.types.bool;
      default = config.networking.hostName == sftpHost;
      description = "convenience value to conditionally pass ssh public key";
      readOnly = true;
    };
    services = lib.mkOption {
      default = { };
      description = "attribute set of applications requiring clone mounts.";
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              enable = lib.mkEnableOption "enable this mount relationship";
              allowOther = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "whether to allow other users or namespaces access to the mount";
              };
              group = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "the group that owns the mount.";
              };
              sshKeySecret = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              sshKeyPublic = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (config.networking.hostName == rcloneMount) {
      systemd.services = lib.mapAttrs' (
        name: cfg: lib.nameValuePair "rclone-${name}" (mkRcloneMount ({ inherit name; } // cfg))
      ) enabledMountpoints;
    })
    (lib.mkIf (config.networking.hostName == sftpHost) {
      users = lib.mkMerge (map makeSftpUser (lib.attrNames enabledMountpoints));
      services = {
        openssh.extraConfig = lib.concatStringsSep "\n" (
          map makeSftpMatchBlock (lib.attrNames enabledMountpoints)
        );

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
          ]) (lib.attrNames enabledMountpoints)
        )
      );
    })
  ];
}
