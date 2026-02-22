{
  config,
  lib,
  pkgs,
  relations,
  ...
}:
let
  rel = relations.zfsReplication;
in
{
  config = lib.mkIf rel.isActive (
    lib.mkMerge [
      (lib.mkIf rel.isClient {
        sops.secrets."zfs-replicate-syncoid-ssh-key" = {
          key = "zfs-replicate/syncoid-ssh-key";
          owner = "syncoid";
          group = "syncoid";
          mode = "0600";
        };
        services = {
          sanoid = {
            enable = true;
            datasets."tank/replicated/db" = {
              autoprune = true;
              autosnap = true;
              recursive = true;
              hourly = 2;
              daily = 2;
              weekly = 2;
              weekly_wday = 0;
              monthly = 2;
              yearly = 2;
            };
          };
          syncoid = {
            enable = true;
            sshKey = "${config.sops.secrets."zfs-replicate-syncoid-ssh-key".path}";
            commands."push-to-${rel.host}" = {
              source = "tank/replicated/db";
              target = "syncoid@${rel.host}:holt/replicated/db";
              recursive = true;
              sendOptions = "p";
            };
          };
        };
      })
      (lib.mkIf rel.isHost {
        environment.systemPackages = [
          pkgs.lzop
          pkgs.mbuffer
        ];
        services = {
          openssh.enable = true;
          sanoid = {
            enable = true;
            datasets = {
              "holt/replicated/db" = {
                autosnap = false;
                autoprune = true;
                recursive = true;

                hourly = 24;
                daily = 7;
                weekly = 4;
                monthly = 3;
                yearly = 1;
              };
            };
          };
        };
        system.activationScripts.zfs-allow-syncoid = {
          text = ''
            ${lib.getExe pkgs.zfs} allow syncoid \
              canmount,compression,create,destroy,hold,mount,mountpoint,receive,release,recordsize,rollback,userprop \
              holt/replicated/db
          '';
        };
        users = {
          groups.syncoid = { };
          users.syncoid = {
            description = "ZFS Replication User";
            group = "syncoid";
            isSystemUser = true;
            openssh.authorizedKeys.keyFiles = [ ../keys/id_syncoid_replicate.pub ];
            shell = pkgs.bashInteractive;
          };
        };
      })
    ]
  );
}
