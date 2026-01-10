{
  lib,
  ...
}:
let
  mainUser = "mainuser";
in
{
  _module.args = {
    inherit mainUser;
  };

  imports = [
    ./common
  ];

  boot = {
    # TODO: look into kernel params for ZFS ARC
    # kernelParams = [
    #   # 4GiB = 4 * 1024 * 1024 * 1024 = 4294967296 byte
    #   "zfs.zfs_arc_max=4294967296"
    #   # 2GiB = 2 * 1024 * 1024 * 1024 = 2147483600 byte
    #   "zfs.zfs_arc_min=2147483648"
    # ];
  };

  console.colors = lib.attrValues {
    c01_black = "1a1c19";
    c02_red = "8b2635";
    c03_green = "52691e";
    c04_yellow = "8a4a02";
    c05_blue = "053318";
    c06_magenta = "5d3a3a";
    c07_cyan = "2d5a27";
    c08_white = "d2b48c";
    c09_blackFg = "4a4a4a";
    c10_redFg = "c0392b";
    c11_greenFg = "7eb356";
    c12_yellowFg = "e67e22";
    c13_blueFg = "f39c12";
    c14_magentaFg = "a0522d";
    c15_cyanFg = "2ecc71";
    c16_whiteFg = "fdf5e6";
  };

  home-manager = {
    users = {
      ${mainUser} = import ../home/storage.nix;
    };
  };

  lab = {
    greetd = {
      enable = true;
      theme = "container=blue;action=yellow;button=yellow;window=black";
      useZshLogin = true;
    };
  };

  services = {
    pipewire.enable = false;
    openssh = {
      # TODO: make into common and enable only when lab.sshd.enable
      enable = true;
      hostKeys = [
        {
          path = "/persist/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
      settings = {
        AuthenticationMethods = "publickey";
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  # users.users.${mainUser}.extraGroups = [
  #   "dialout"
  #   "tty"
  # ];
}
