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
            daily = 4;
            recursive = true;
            autosnap = true;
            autoprune = true;
          };
        };
        syncoid = {
          enable = true;
          commands."push-to-${sink}" = {
            source = "tank/replicated/db";
            target = "root@${sink}:holt/replicated/db";
            recursive = true;
            extraArgs = [
              "--sendoptions=p"
              "--sshkey=${config.sops.secrets."zfs-replicate-syncoid-ssh-key".path}"
            ];
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
      users.users.root.openssh.authorizedKeys.keyFiles = [ ../keys/id_syncoid_replicate.pub ];
      services.sanoid = {
        enable = true;
        datasets."holt/replicated/db" = {
          hourly = 24;
          daily = 6;
          weekly = 3;
          monthly = 3;

          autosnap = false;
          autoprune = true;
          recursive = true;
        };
      };
    })
  ];
}
