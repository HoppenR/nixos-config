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

  rcloneMountNode = topology.${rcloneMount};
  sftpHostNode = topology.${sftpHost};
in
{
  config = lib.mkMerge [
    (lib.mkIf (config.networking.hostName == rcloneMount) {
      systemd.services."rclone-replicated-apps" = {
        description = "Remote App VFS Cache Mount";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        stopIfChanged = false;
        serviceConfig = {
          Type = "notify";
          # TODO: make the mount at /replicated/apps/syncthing/
          #       with syncthing.homeDir the same ?
          #       with users.users.syncthing.createHome ?
          #     no because it will create the directory before everyt▸
          # TODO: is --cache-dir needed? This is probably the default
          ExecStart = ''
            ${lib.getExe pkgs.rclone} mount \
              ":sftp,host=${sftpHostNode.ipv4},user=sftpuser,key_file=/persist/etc/ssh/ssh_host_ed25519_key:/apps" \
              /replicated/apps \
              --allow-non-empty \
              --config /dev/null \
              --allow-other \
              --vfs-cache-mode full \
              --vfs-cache-max-size 8Gi \
              --vfs-write-back 5m \
              --dir-cache-time 336h \
              --attr-timeout 336h \
              --cache-dir /var/cache/rclone \
              --vfs-cache-max-age 48h \
              --rc
          '';
          ExecStartPost = ''
            ${lib.getExe pkgs.rclone} rc vfs/refresh recursive=true --url localhost:5572
          '';
          # TODO: --lazy?
          ExecStop = "/run/current-system/sw/bin/umount /replicated/apps";
          Restart = "on-failure";
          RestartSec = "10s";
          User = "root";
        };
      };
      # TODO: needed?
      systemd.tmpfiles.rules = [
        "d /var/cache/rclone 0750 root root -"
      ];
    })
    (lib.mkIf (config.networking.hostName == sftpHost) {
      users = {
        groups.sftpuser = { };
        users.sftpuser = {
          isSystemUser = true;
          home = "/"; # Note that this is relative to the ChrootDirectory
          group = "sftpuser";
          openssh.authorizedKeys.keys = [ rcloneMountNode.publicKey ];
        };
      };
      services.openssh.extraConfig = ''
        Match User sftpuser
          ChrootDirectory /mnt/sftp
          ForceCommand internal-sftp
          PasswordAuthentication no
          AllowTcpForwarding no
          X11Forwarding no
      '';
    })
  ];
}
