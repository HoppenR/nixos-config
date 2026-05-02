{ lib, ... }:
{
  imports = [
    # Common
    ./greetd.nix
    ./openssh.nix
    # Relations
    ./relations.nix
    ./adguardhome.nix
    ./proxmox.nix
    ./rclone-mount.nix
    ./streams.nix
    ./zed.nix
    ./zfs-replication.nix
    # Specialized
    ./booklore.nix
    ./endpoints
    ./joplin.nix
    ./mysql.nix
    ./nextcloud.nix
    ./postfix.nix
    ./postgres.nix
    ./vaultwarden.nix
  ];

  options.lab = {
    mainUser = lib.mkOption {
      type = lib.types.str;
      default = "mainuser";
    };
  };
}
