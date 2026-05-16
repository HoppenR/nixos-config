{
  fileSystems."/home".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;

  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            name = "boot";
            start = "1M";
            end = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0077"
                "dmask=0077"
              ];
            };
          };
          swap = {
            size = "8G";
            content = {
              type = "swap";
              randomEncryption = true;
              discardPolicy = "both";
            };
          };
          zfs = {
            name = "zfs";
            size = "100%";
            content = {
              type = "zfs";
              pool = "tank";
            };
          };
        };
      };
    };
    zpool.tank = {
      type = "zpool";
      rootFsOptions = {
        compression = "zstd";
        acltype = "posixacl";
        xattr = "sa";
        atime = "off";
        canmount = "off";
      };
      datasets = {
        "local/root" = {
          type = "zfs_fs";
          mountpoint = "/";
          options.mountpoint = "legacy";
        };
        "local/nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.mountpoint = "legacy";
        };
        "local/var-log" = {
          type = "zfs_fs";
          mountpoint = "/var/log";
          options.mountpoint = "legacy";
        };
        "replicated/apps" = {
          type = "zfs_fs";
          mountpoint = "/replicated/apps";
          options = {
            mountpoint = "legacy";
            quota = "1G";
          };
        };
        "replicated/db/mariadb" = {
          type = "zfs_fs";
          mountpoint = "/replicated/db/mariadb";
          options = {
            mountpoint = "legacy";
            recordsize = "16K";
          };
        };
        "replicated/db/postgres" = {
          type = "zfs_fs";
          mountpoint = "/replicated/db/postgres";
          options = {
            mountpoint = "legacy";
            recordsize = "8K";
          };
        };
        "replicated/web" = {
          type = "zfs_fs";
          mountpoint = "/replicated/web";
          options.mountpoint = "legacy";
        };
        "safe/home" = {
          type = "zfs_fs";
          mountpoint = "/home";
          options.mountpoint = "legacy";
        };
        "safe/persist" = {
          type = "zfs_fs";
          mountpoint = "/persist";
          options.mountpoint = "legacy";
        };
      };
    };
  };
}
