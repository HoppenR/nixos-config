{ lib, ... }:
{
  imports = [
    # Common
    ./greetd.nix
    ./openssh.nix
    # Relations
    ./relations.nix
    ./rclone-mount.nix
    ./streams.nix
    ./syncthing.nix
    ./zfs-replication.nix
    # Specialized
    ./booklore.nix
    ./endpoints
    ./joplin.nix
    ./mysql.nix
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
