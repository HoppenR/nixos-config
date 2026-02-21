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
in
{
  config = lib.mkMerge [
    (lib.mkIf (config.networking.hostName == rcloneMount) {
      sops.secrets."rclone-sftpuser-ssh-key" = {
        key = "rclone/sftpuser-ssh-key";
        group = "sftpusers";
        mode = "0660";
      };
      users.groups.sftpusers = { };
      systemd.services =
        let
          mkRcloneMount = userName: {
            description = "Rclone mount for ${userName}";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            path = [ "/run/wrappers" ];
            serviceConfig = {
              Type = "notify";
              CacheDirectory = "rclone-${userName}";
              ExecStart = ''
                ${lib.getExe pkgs.rclone} mount \
                  ":sftp,host=${sftpHostNode.ipv4},user=sftpuser,key_file=${
                    config.sops.secrets."rclone-sftpuser-ssh-key".path
                  }:/apps/${userName}" \
                  /replicated/apps/${userName}/remote \
                  --config /dev/null \
                  --vfs-cache-mode full \
                  --vfs-cache-max-size 4Gi \
                  --vfs-write-back 5m \
                  --cache-dir %C/rclone-${userName} \
                  --uid ${toString config.users.users.${userName}.uid} \
                  --gid ${toString config.users.groups.${userName}.gid} \
                  --dir-cache-time 48h \
                  --attr-timeout 48h \
                  --vfs-cache-max-age 48h \
                  --allow-other
              '';
              ExecStop = "${pkgs.fuse}/bin/fusermount3 -u -z /replicated/apps/${userName}/remote";
              Restart = "on-failure";
              User = userName;
              Group = userName;
            };
          };
        in
        {
          # TODO:
          # "rclone-booklore" = mkRcloneMount "booklore";
          "rclone-joplin" = mkRcloneMount "joplin";
          "rclone-syncthing" = mkRcloneMount "syncthing";
        };
    })
    (lib.mkIf (config.networking.hostName == sftpHost) {
      users = {
        groups.sftpuser = { };
        users.sftpuser = {
          isSystemUser = true;
          home = "/"; # Note that this is relative to the ChrootDirectory
          group = "sftpuser";
          openssh.authorizedKeys.keyFiles = [ ../keys/id_rclone_sftpuser.pub ];
        };
      };
      services = {
        openssh.extraConfig = ''
          Match User sftpuser
            ChrootDirectory /srv/sftp
            ForceCommand internal-sftp
            PasswordAuthentication no
            AllowTcpForwarding no
            X11Forwarding no
        '';
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
    })
  ];
}
