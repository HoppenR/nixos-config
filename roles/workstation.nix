{
  lib,
  pkgs,
  ...
}:
let
  mainUser = "christoffer";
in
{
  _module.args = {
    inherit mainUser;
  };

  imports = [
    ./common
  ];

  console.colors = lib.attrValues {
    c01_black = "1d1f21";
    c02_red = "dc322f";
    c03_green = "859900";
    c04_yellow = "b58900";
    c05_blue = "268bd2";
    c06_magenta = "d33682";
    c07_cyan = "2aa198";
    c08_white = "eee8d5";
    c09_blackFg = "002b36";
    c10_redFg = "cb4b16";
    c11_greenFg = "586e75";
    c12_yellowFg = "657b83";
    c13_blueFg = "839496";
    c14_magentaFg = "6c71c4";
    c15_cyanFg = "93a1a1";
    c16_whiteFg = "fdf6e3";
  };

  home-manager = {
    users = {
      ${mainUser} = import ../home/workstation.nix;
    };
  };

  lab = {
    greetd = {
      enable = true;
    };
  };

  networking = {
    wireless.iwd = {
      enable = true;
      settings = {
        General = {
          EnableNetworkConfiguration = true;
        };
        Network = {
          NameResolvingService = "systemd";
        };
      };
    };
  };

  programs = {
    hyprland.enable = true;
    steam.enable = true;
  };

  hardware = {
    bluetooth = {
      enable = true;
      settings = {
        Policy = {
          AutoEnable = "true";
        };
      };
    };
  };

  nixpkgs = {
    config.allowUnfreePredicate = (
      pkg:
      builtins.elem (lib.getName pkg) [
        "discord"
        "steam"
        "steam-unwrapped"
      ]
    );
    overlays = [
      (import ../overlays/kitty-single.nix)
    ];
  };

  services = {
    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      jack.enable = true;
    };
  };
}
