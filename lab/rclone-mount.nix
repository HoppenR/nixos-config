{
  pkgs,
  lib,
  config,
  inventory,
  relations,
  ...
}:
let
  rel = relations.rcloneMounts;
  # NOTE: filesystem expectations
  # Expects on mountHost:   /replicated/apps/ | {name}/remote owned by {name}
  # Expects on mountClient: /srv/sftp/apps/{name} | /files owned by sftp-{name}

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
              ":sftp,host=${inventory.${rel.host}.ipv4},user=sftpuser-${name},key_file=${sshKeySecret}:/files"
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

  makeSftpUser = name: cfg: {
    groups."sftpuser-${name}" = { };
    users."sftpuser-${name}" = {
      isSystemUser = true;
      home = "/"; # Note that this is relative to the ChrootDirectory
      group = "sftpuser-${name}";
      openssh.authorizedKeys.keyFiles = [ cfg.sshKeyPublic ];
    };
  };

  enabledMountpoints = lib.filterAttrs (_: v: v.enable) config.lab.rcloneMounts.services;
in
{
  options.lab.rcloneMounts = {
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
                type = lib.types.nullOr lib.types.path;
                default = null;
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkIf rel.isActive (
    lib.mkMerge [
      (lib.mkIf rel.isClient {
        systemd.services = lib.mapAttrs' (
          name: cfg: lib.nameValuePair "rclone-${name}" (mkRcloneMount ({ inherit name; } // cfg))
        ) enabledMountpoints;
      })
      (lib.mkIf rel.isHost {
        users = lib.mkMerge (lib.mapAttrsToList makeSftpUser enabledMountpoints);
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
    ]
  );
}
