{ ... }:
{
  imports = [
    ./rclone-mount.nix
    ./streamserver.nix
    ./syncthing.nix
    ./zrepl-backups.nix
  ];
}
