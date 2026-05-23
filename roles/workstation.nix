{
  config,
  inputs,
  lib,
  pkgs,
  inventory,
  topology,
  net,
  ...
}:
let
  machine = inventory.${config.networking.hostName};
  gateway = topology.${machine.topology}.gateway;
in
{
  imports = [
    ./common.nix
  ];

  assertions = [
    {
      assertion =
        !config.home-manager.users.${config.lab.mainUser}.wayland.windowManager.hyprland.systemd.enable;
      message = ''
        UWSM is enabled globally, but Home Manager's native Hyprland systemd target 
        integration is still active for main user '${config.lab.mainUser}'.
        Please set 'wayland.windowManager.hyprland.systemd.enable = false;' in your
        Home Manager configuration to prevent target activation conflicts.
      '';
    }
  ];

  boot = {
    kernel.sysctl = {
      "net.ipv4.conf.all.arp_announce" = 2;
      "net.ipv4.conf.all.arp_ignore" = 1;
      "net.ipv4.conf.default.arp_announce" = 2;
      "net.ipv4.conf.default.arp_ignore" = 1;
    };
    # P2425D config:
    kernelModules = [ "i2c-dev" ];
  };

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

  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      android-tools
      ;
  };

  home-manager = {
    users = {
      ${config.lab.mainUser} = import ../home/workstation;
    };
  };

  users = {
    users = {
      ${config.lab.mainUser} = {
        # P2425D config:
        extraGroups = [ "i2c" ];
      };
    };
  };

  lab = {
    greetd.enable = true;
    mainUser = "christoffer";
  };

  networking = {
    firewall = {
      interfaces."vlan-mgmt".allowedUDPPorts = [
        # mDNS
        5353
      ];
    };
    wireless.iwd = {
      enable = true;
      settings.General.EnableNetworkConfiguration = false;
    };
  };
  systemd.network = {
    netdevs = {
      "30-lan0" = {
        netdevConfig = {
          Kind = "bond";
          Name = "lan0";
          MACAddress = config.systemd.network.links."20-laptop-lan".matchConfig.MACAddress;
        };
        bondConfig = {
          Mode = "active-backup";
          MIIMonitorSec = "200ms";
        };
      };
      "30-vlan-mgmt" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan-mgmt";
        };
        vlanConfig.Id = 10;
      };
      "30-vlan-guest" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan-guest";
        };
        vlanConfig.Id = 20;
      };
    };
    networks = {
      "40-dock-lan0" = {
        matchConfig.Name = "dock-lan";
        networkConfig = {
          Bond = "lan0";
          PrimarySlave = true;
        };
      };
      "40-laptop-lan0" = {
        matchConfig.Name = "laptop-lan";
        networkConfig = {
          Bond = "lan0";
        };
      };
      "45-lan0" = {
        matchConfig.Name = "lan0";
        vlan = [
          "vlan-mgmt"
          "vlan-guest"
        ];
        networkConfig = {
          DHCP = false;
          IPv6AcceptRA = false;
          KeepConfiguration = "static";
          LinkLocalAddressing = false;
        };
      };
      "50-vlan-mgmt" = {
        matchConfig.Name = "vlan-mgmt";
        addresses = [
          {
            Address = "${net.ip net.mgmt config.networking.hostName}/24";
            RouteMetric = 10;
          }
          {
            Address = "${net.ip6 net.mgmt config.networking.hostName}/64";
            RouteMetric = 10;
          }
        ];
        domains = [ config.networking.domain ];
        networkConfig = {
          DNS = [
            (net.ip net.mgmt gateway)
            (net.ip6 net.mgmt gateway)
          ];
          IPv4ReversePathFilter = "loose";
          IPv6AcceptRA = false;
          KeepConfiguration = "static";
          NTP = [
            (net.ip net.mgmt gateway)
            (net.ip6 net.mgmt gateway)
          ];
          MulticastDNS = true;
        };
        routes = [
          {
            Destination = "${net.ip net.mgmt gateway}/32";
            Metric = 10;
          }
          {
            Gateway = net.ip net.mgmt gateway;
            GatewayOnLink = true;
            Metric = 10;
          }
          {
            Destination = "${net.ip6 net.mgmt gateway}/128";
            Metric = 10;
          }
          {
            Gateway = net.ip6 net.mgmt gateway;
            GatewayOnLink = true;
            Metric = 10;
          }
        ];
      };
      "50-vlan-guest" = {
        matchConfig.Name = "vlan-guest";
        addresses = [
          {
            Address = "${net.ip net.guest config.networking.hostName}/24";
            RouteMetric = 20;
          }
          {
            Address = "${net.ip6 net.guest config.networking.hostName}/64";
            RouteMetric = 20;
          }
        ];
        networkConfig = {
          DNS = [
            (net.ip net.guest gateway)
            (net.ip6 net.guest gateway)
          ];
          IPv4ReversePathFilter = "loose";
          IPv6AcceptRA = false;
          KeepConfiguration = "static";
          MulticastDNS = true;
        };
        routes = [
          {
            Destination = "${net.ip net.guest gateway}/32";
            Metric = 20;
          }
          {
            Gateway = net.ip net.guest gateway;
            GatewayOnLink = true;
            Metric = 20;
          }
          {
            Destination = "${net.ip6 net.guest gateway}/128";
            Metric = 20;
          }
          {
            Gateway = net.ip6 net.guest gateway;
            GatewayOnLink = true;
            Metric = 20;
          }
        ];
      };
      "50-laptop-wifi" = {
        matchConfig.Name = "laptop-wifi";
        domains = [ config.networking.domain ];
        networkConfig = {
          DHCP = true;
          IPv4ReversePathFilter = "loose";
          IPv6AcceptRA = true;
          MulticastDNS = "resolve";
        };
        dhcpV4Config = {
          RouteMetric = 100;
        };
        ipv6AcceptRAConfig = {
          RouteMetric = 100;
        };
      };
    };
  };

  programs = {
    hyprland = {
      enable = true;
      withUWSM = true;
    };
    steam.enable = true;
    ssh = {
      extraConfig = ''
        Host ssh.${config.networking.domain}
          User mainuser
          ProxyCommand ${lib.getExe pkgs.cloudflared} access ssh --hostname %h
      '';
    };
  };

  security = {
    run0.enableSudoAlias = true;
    sudo.enable = false;
  };

  hardware = {
    i2c = {
      enable = true;
    };
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
    config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "steam"
        "steam-unwrapped"
      ];
    overlays = [
      inputs.streamshower.overlays.default
    ];
  };

  services = {
    resolved = {
      settings.Resolve = {
        MulticastDNS = true;
      };
    };
    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      jack.enable = true;
    };
  };
}
