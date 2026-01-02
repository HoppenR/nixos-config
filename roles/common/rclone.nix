{
  pkgs,
  roles,
  lib,
  config,
  ...
}:
let
  rcloneTypes = [
    "sftpHost"
    "rcloneMount"
  ];
in
{
  options.lab.rclone = {
    enable = lib.mkEnableOption "enable rclone lab configuration";
    type = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum rcloneTypes);
      default = null;
      description = "The rclone lab role";
    };
  };

  config = lib.mkIf config.lab.rclone.enable (
    lib.mkMerge [
      (lib.mkIf (config.lab.rclone.type == "rcloneMount") {
        systemd.services.rclone-mount-apps = {
          description = "Remote VFS Cache Mount (/mnt/rclone/apps)";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          stopIfChanged = false;
          serviceConfig = {
            Type = "notify";
            ExecStartPre = "/run/current-system/sw/bin/mkdir -p /mnt/rclone/apps";
            # TODO: mount to /replicated/apps/ instead after done testing
            ExecStart = ''
              ${lib.getExe pkgs.rclone} mount \
                ":sftp,host=${roles.storage.ipv4},user=sftpuser,key_file=/persist/etc/ssh/ssh_host_ed25519_key:/apps" \
                /mnt/rclone/apps \
                --config /dev/null \
                --allow-other \
                --vfs-cache-mode full \
                --vfs-cache-max-size 5Gi \
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
            ExecStop = "/run/current-system/sw/bin/umount /mnt/rclone/apps";
            Restart = "on-failure";
            RestartSec = "10s";
            User = "root";
          };
        };
        systemd.tmpfiles.rules = [
          "d /var/cache/rclone 0750 root root -"
        ];
        programs.ssh.knownHosts."${roles.storage.hostName}" = {
          hostNames = [
            roles.storage.hostName
            roles.storage.ipv4
          ];
          publicKey = roles.storage.publicKey;
        };
      })
      (lib.mkIf (config.lab.rclone.type == "sftpHost") {
        users = {
          groups.sftpuser = { };
          users.sftpuser = {
            isSystemUser = true;
            home = "/";
            group = "sftpuser";
            openssh.authorizedKeys.keys = [ roles.logic.publicKey ];
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
    ]
  );
}
