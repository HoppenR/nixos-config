{
  config,
  lib,
  pkgs,
  ...
}:
let
  pusher = "skadi";
  sink = "hoddmimir";
in
{
  config = lib.mkMerge [
    (lib.mkIf (config.networking.hostName == pusher) {
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
          commands."push-to-${sink}" = {
            source = "tank/replicated/db";
            target = "syncoid@${sink}:holt/replicated/db";
            recursive = true;
            sendOptions = "p";
          };
        };
      };
    })

    (lib.mkIf (config.networking.hostName == sink) {
      environment.systemPackages = [
        pkgs.lzop
        pkgs.mbuffer
      ];
      services.openssh.enable = true;
      users.users.syncoid = {
        description = "ZFS Replication User";
        group = "syncoid";
        isSystemUser = true;
        openssh.authorizedKeys.keyFiles = [ ../keys/id_syncoid_replicate.pub ];
        shell = pkgs.bashInteractive;
      };
      users.groups.syncoid = { };
      system.activationScripts.zfs-allow-syncoid = {
        text = ''
          ${lib.getExe pkgs.zfs} allow syncoid \
            canmount,compression,create,destroy,hold,mount,mountpoint,receive,release,recordsize,rollback,userprop \
            holt/replicated/db
        '';
      };
      services.sanoid = {
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
    })
  ];
}
