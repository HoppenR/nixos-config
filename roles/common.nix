{
  config,
  identities,
  inputs,
  lib,
  pkgs,
  inventory,
  topology,
  ...
}:
let
  machine = inventory.${config.networking.hostName};
  writeZsh = pkgs.writers.makeScriptWriter { interpreter = lib.getExe pkgs.zsh; };

  net = {
    mgmt = 10;
    guest = 20;
    iot = 30;
    subnet = vlan: top: "${top.ipBase}.${toString vlan}.0/24";
    subnet6 = vlan: top: "${top.ip6Base}:${toString vlan}::0/64";
    ip =
      vlan: hostName:
      let
        host = inventory.${hostName};
        base = topology.${host.topology}.ipBase;
      in
      "${base}.${toString vlan}.${toString host.id}";
    ip6 =
      vlan: hostName:
      let
        host = inventory.${hostName};
        base = topology.${host.topology}.ip6Base;
      in
      "${base}:${toString vlan}::${toString host.id}";
  };
in
{

  imports = [
    ../lab
    inputs.streamserver.nixosModules.default

    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  _module.args = { inherit net writeZsh; };

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  console = {
    packages = builtins.attrValues {
      inherit (pkgs)
        terminus_font
        ;
    };
    font = "Lat2-Terminus16";
    keyMap = "sv-latin1";
  };

  environment = {
    shellAliases = {
      l = null;
      ll = "ls --almost-all -lh";
      ls = "ls --color=auto";
    };
    systemPackages =
      (builtins.attrValues {
        inherit (pkgs)
          gcc
          git
          neovim-unwrapped
          psmisc
          sops
          yubikey-manager
          ;
      })
      ++ [
        (pkgs.symlinkJoin {
          name = "neovim-system-aliases";
          paths = [ pkgs.neovim-unwrapped ];
          postBuild = ''
            ln -s ${lib.getExe pkgs.neovim-unwrapped} $out/bin/vi
            ln -s ${lib.getExe pkgs.neovim-unwrapped} $out/bin/vim
          '';
        })
      ];
  };

  fonts.packages = builtins.attrValues {
    inherit (pkgs)
      fira-code
      cozette
      noto-fonts
      ;
    inherit (pkgs.maple-mono)
      NF
      ;
    inherit (pkgs.nerd-fonts)
      jetbrains-mono
      ;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs identities writeZsh; };
    users = {
      ${config.lab.mainUser} = ../home/common;
    };
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "sv_SE.UTF-8";
      LC_MONETARY = "sv_SE.UTF-8";
      LC_MEASUREMENT = "sv_SE.UTF-8";
      LC_PAPER = "sv_SE.UTF-8";
      LC_NUMERIC = "sv_SE.UTF-8";
    };
  };

  networking = {
    domain = "hoppenr.xyz";
    nftables.enable = true;
    firewall.backend = "nftables";
    resolvconf.enable = lib.mkDefault false;
    useNetworkd = true;
    useDHCP = false;
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      allowed-users = [ "@wheel" ];
      trusted-users = [ "@wheel" ];
    };
  };

  programs = {
    ssh = {
      knownHosts = lib.mapAttrs (hostName: hostData: {
        hostNames = [
          hostName
          (net.ip net.mgmt hostName)
          (net.ip6 net.mgmt hostName)
        ];
        publicKey = hostData.publicKey;
      }) (lib.filterAttrs (hostName: hostData: hostData ? publicKey) inventory);
      extraConfig =
        let
          mainuserHome = config.home-manager.users.${config.lab.mainUser};
        in
        ''
          Match localuser ${config.lab.mainUser}
            AddKeysToAgent yes
            IdentityFile ${mainuserHome.xdg.stateHome}/ssh/id_ed25519
            UserKnownHostsFile ${mainuserHome.xdg.stateHome}/ssh/known_hosts.d/%k
          Match localuser root
            IdentityFile /persist/etc/ssh/ssh_host_ed25519_key
        '';
    };
    zsh.enable = true;
  };

  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age = {
      keyFile = "/persist/var/lib/sops-nix/age-pq.txt";
      sshKeyPaths = lib.mkForce [ ];
    };
    secrets.user-password.neededForUsers = true;
  };

  security = {
    pam.u2f = {
      enable = true;
      settings = {
        userpresence = 1;
        cue = true;
      };
    };
    polkit = {
      enable = true;
      debug = true;
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          polkit.log("user " +  subject.user + " is attempting action " + action.id + " from PID " + subject.pid);
        });

        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.policykit.exec") {
            return polkit.Result.AUTH_ADMIN_KEEP;
          }
        });

        polkit.addRule(function(action, subject) {
          if (action.id.indexOf("org.freedesktop.systemd1.") == 0) {
            return polkit.Result.AUTH_ADMIN_KEEP;
          }
        });
      '';
    };
  };

  services = {
    pcscd.enable = true;
    resolved = {
      enable = lib.mkDefault true;
      settings.Resolve = {
        LLMNR = false;
        MulticastDNS = true;
      };
    };
    udev = {
      packages = builtins.attrValues {
        inherit (pkgs)
          yubikey-personalization
          ;
      };
    };
    zfs = {
      autoScrub = {
        enable = true;
        interval = "monthly";
      };
    };
  };

  time.timeZone = "Europe/Stockholm";

  users = {
    mutableUsers = false;
    users = {
      ${config.lab.mainUser} = {
        extraGroups = [
          "video"
          "input"
          "disk"
          "wheel"
        ];
        hashedPasswordFile = config.sops.secrets.user-password.path;
        isNormalUser = true;
        shell = pkgs.zsh;
        openssh.authorizedKeys.keys = lib.concatMap (
          name: identities.people.${name}.publicKeys
        ) machine.admins;
      };
      "root" = {
        hashedPassword = null;
      };
    };
  };
}
