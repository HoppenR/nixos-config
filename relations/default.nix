{ ... }:
{
  imports = [
    ./rclone-mount.nix
    ./streamserver.nix
    ./syncthing.nix
    ./zfs-replication.nix
  ];
}
