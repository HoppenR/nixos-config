{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
let
  asciibnnuy = lib.strings.escapeShellArg ''
    _  _ ___ __  __           ___  ___
    | \| |_ _|\ \/ /  (\_/)   / _ \/ __|
    | .`  | |  >  <  (='.'=) | (_) \__ \
    |_|\_|___|/_/\_\ (")_(")  \___/|___/
  '';
  mainUser = "christoffer";
in
{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  environment = {
    shellAliases = {
      l = null;
      ll = "ls --almost-all -lh";
      ls = "ls --color=auto";
    };
    systemPackages = builtins.attrValues {
      inherit (pkgs)
        glibc
        gcc
        ;
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Stockholm";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "sv_SE.UTF-8";
    LC_MONETARY = "sv_SE.UTF-8";
    LC_MEASUREMENT = "sv_SE.UTF-8";
    LC_PAPER = "sv_SE.UTF-8";
    LC_NUMERIC = "sv_SE.UTF-8";
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

  users = {
    mutableUsers = false;
    users = {
      "${mainUser}" = {
        extraGroups = [
          "video"
          "input"
          "disk"
          "wheel"
        ];
        hashedPasswordFile = config.sops.secrets.user-password.path;
        isNormalUser = true;
        shell = pkgs.zsh;
      };
      "root" = {
        hashedPassword = null;
      };
    };
  };

  programs = {
    hyprland.enable = true;
    ssh.extraConfig = ''
      Host *
        AddKeysToAgent yes
        IdentityFile ~/.local/state/ssh/id_ed25519
        UserKnownHostsFile ~/.local/state/ssh/known_hosts.d/%k
    '';
    zsh.enable = true;
    steam.enable = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users = {
      "${mainUser}" = import ./home.nix;
    };
  };

  hardware.graphics.enable = true;

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "discord"
      "steam"
      "steam-unwrapped"
    ];

  fonts.packages = builtins.attrValues {
    inherit (pkgs.nerd-fonts)
      jetbrains-mono
      ;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    allowed-users = [ "@wheel" ];
  };

  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = ''
            ${pkgs.tuigreet}/bin/tuigreet \
              --greeting ${asciibnnuy} \
              --user-menu \
              --time \
              --time-format %R
          '';
          user = "${mainUser}";
        };
        terminal = {
          vt = 1;
        };
      };
    };
    pipewire = {
      enable = true;
      pulse.enable = true;
    };
    resolved.enable = true;
    udev = {
      packages = builtins.attrValues {
        inherit (pkgs)
          yubikey-personalization
          ;
      };
    };
  };

  security.pam.u2f = {
    enable = true;
    settings = {
      authfile = "/etc/u2f_keys";
      userpresence = 1;
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [ ];
  networking.firewall.enable = true;

  system.stateVersion = "25.05"; # Did you read the comment?
}
