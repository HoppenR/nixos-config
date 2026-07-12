{
  config,
  ...
}:
let
  mainUserObject = config.users.users.${config.lab.mainUser};
  mainUserUid = toString mainUserObject.uid;
  mainUserGid = toString config.users.groups.${mainUserObject.group}.gid;
in
{
  fileSystems."/home".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;

  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/nvme0n1";
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
              # TODO: look into full disk encryption instead?
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
          postCreateHook = /* bash */ ''
            if ! zfs list -H -o name "tank/local/root@blank" >/dev/null 2>&1; then
              zfs snapshot tank/local/root@blank
            fi
          '';
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
        "safe/steam" = {
          type = "zfs_fs";
          mountpoint = "/home/${config.lab.mainUser}/.local/share/Steam";
          postCreateHook =
            let
              mountpoint = "/mnt/tank-safe-steam";
            in
            /* bash */ ''
              mkdir -p ${mountpoint}
              mount -t zfs tank/safe/steam ${mountpoint}
              chown ${mainUserUid}:${mainUserGid} ${mountpoint}
              chmod 0755 ${mountpoint}
              umount ${mountpoint}
              rm -rf ${mountpoint}
            '';
          options = {
            mountpoint = "legacy";
            "com.sun:auto-snapshot" = "false";
          };
        };
      };
    };
  };
}
