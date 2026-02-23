{
  config,
  lib,
  ...
}:
{
  imports = [
    ./common.nix
  ];

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
      ${config.lab.mainUser} = import ../home/storage.nix;
    };
  };

  lab = {
    greetd = {
      enable = true;
      theme = "container=blue;action=yellow;button=yellow;window=black";
      useZshLogin = true;
    };
    openssh.enable = true;
  };

  services = {
    pipewire.enable = false;
  };
}
