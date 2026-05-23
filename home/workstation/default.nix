{
  config,
  lib,
  osConfig,
  pkgs,
  identities,
  ...
}:
let
  writeZsh = pkgs.writers.makeScriptWriter { interpreter = lib.getExe pkgs.zsh; };
  writeZshBin = name: text: pkgs.writeScriptBin name ("#!${lib.getExe pkgs.zsh}\n" + text);

  vlog = writeZshBin "vlog" /* zsh */ ''
    setopt ERR_EXIT NO_UNSET PIPE_FAIL
    local filter='. | "[\(.__REALTIME_TIMESTAMP | tonumber / 1000000 | strflocaltime("%H:%M:%S"))] \(.MESSAGE)"'
    ${pkgs.systemd}/bin/journalctl --user --unit=notification-logger "$@" --output=json \
      | ${pkgs.jq}/bin/jq --raw-output "$filter" \
      | less +G
  '';

  monitors = [
    rec {
      enabled = true;
      desc = "Dell Inc. DELL P2425D ${serial}";
      mode = "2560x1440@100Hz";
      position = "-2560x0";
      scale = 1;
      serial = "DVH9D94";
      wallpaper = "${config.home.homeDirectory}/Pictures/backgrounds/bunny-pc-bg.png";
    }
    rec {
      enabled = true;
      desc = "Dell Inc. DELL P2425D ${serial}";
      mode = "2560x1440@100Hz";
      position = "0x0";
      scale = 1;
      serial = "CVH9D94";
      wallpaper = "${config.home.homeDirectory}/Pictures/backgrounds/saabbackground.png";
    }
    rec {
      enabled = false;
      desc = "California Institute of Technology ${serial}";
      mode = "1920x1200@60";
      position = "2560x0";
      scale = 1;
      serial = "0x1404";
      wallpaper = "${config.home.homeDirectory}/Pictures/backgrounds/hyprland-islands.png";
    }
  ];
in
{
  _module.args = { inherit monitors; };
  home = {
    packages = builtins.attrValues {
      inherit
        vlog
        ;

      inherit (pkgs)
        ddcutil
        koreader
        libnotify
        mpv
        scrcpy
        telegram-desktop
        wl-clipboard
        ;
    };
    pointerCursor = {
      enable = true;
      package = pkgs.phinger-cursors;
      name = "phinger-cursors-dark";
      hyprcursor.enable = true;
    };
    sessionVariables = {
      BROWSER = "firefox";
      TERMINAL = "wezterm";
    };
    stateVersion = "25.11";
  };

  imports = [
    ./waybar.nix
    ./hyprland.nix
  ];

  programs = {
    yazi = {
      enable = true;
      shellWrapperName = "y";
    };
    direnv = {
      enable = true;
    };
    neovim = {
      initLua = /* lua */ ''
        vim.env.nix = '/persist/nixos'
        vim.env.personal = '${config.home.homeDirectory}/Projects/personal'
      '';
    };
    firefox = {
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
      languagePacks = [
        "en-US"
        "sv-SE"
      ];
      profiles.default = {
        isDefault = true;
        settings = {
          "layout.css.devPixelsPerPx" = "1.25";
        };
      };
      policies = {
        ExtensionSettings = {
          "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
            installation_mode = "force_installed";
          };
        };
      };
    };
    hyprlock = {
      enable = true;
      settings = {
        general = {
          hide_cursor = true;
          ignore_empty_input = true;
        };
        background = [
          {
            path = "${config.home.homeDirectory}/Pictures/backgrounds/Palma_screensaver_Bunny_leaping_from_moon.png";
            blur_passes = 3;
            blur_size = 8;
          }
        ];
        input-field = [
          {
            monitor = "";
            size = "200, 50";
            position = "0, -200";
            dots_center = true;
            fade_on_empty = false;
            font_color = "rgb(254, 254, 254)";
            inner_color = "rgb(26, 27, 38)";
            outline_thickness = 2;
          }
        ];
        label = [
          {
            text = "$TIME";
            position = "0, 0";
            halign = "center";
            valign = "center";
            font_size = 80;
            font_family = "Maple Mono NF Italic";
            color = "rgb(205, 214, 244)";
          }
        ];
      };
    };
    joplin-desktop = {
      enable = true;
      general.editor = "${lib.getExe pkgs.wezterm} start -- ${lib.getExe config.programs.neovim.finalPackage}";
      extraConfig = {
        "sync.9.path" = "https://joplin.${osConfig.networking.domain}";
        "sync.9.username" = identities.people.christoffer.email;
      };
      sync = {
        interval = "5m";
        target = "joplin-server";
      };
    };
    wezterm = {
      enable = true;
      extraConfig = /* lua */ ''
        local act = wezterm.action
        wezterm.on('trigger-less-with-scrollback', function(window, pane)
          local dims = pane:get_dimensions()
          local text = pane:get_lines_as_escapes(dims.scrollback_rows)
          local name = os.tmpname()
          local f = assert(io.open(name, 'w+'))
          f:write(text)
          f:flush()
          f:close()
          window:perform_action(act.SplitPane {
            direction = "Down",
            size = { Percent = 95 },
            command = {
              args = {
                'less',
                '--force',
                '--chop-long-lines',
                '--RAW-CONTROL-CHARS',
                '+G',
                name,
              },
            },
          }, pane)
          wezterm.sleep_ms(1000)
          os.remove(name)
        end)

        wezterm.on('format-window-title', function(tab, pane, tabs, panes, config)
          local user_vars = tab.active_pane.user_vars
          local title = tab.active_pane.title
          local nix_shell = user_vars.IN_NIX_SHELL
          if nix_shell and nix_shell ~= "" then
              title = ' ' .. title
          end
          return title
        end)

        return {
          font = wezterm.font("monospace"),
          font_size = 17.0,
          color_scheme = "Tokyo Night",
          window_background_opacity = 0.9,
          text_background_opacity = 1.0,
          audible_bell = "Disabled",
          visual_bell = {
            fade_in_duration_ms = 75,
            fade_out_duration_ms = 425,
            target = 'CursorColor',
          },
          scrollback_lines = 5000,
          enable_tab_bar = true,
          use_fancy_tab_bar = false,
          tab_bar_at_bottom = false,
          hide_tab_bar_if_only_one_tab = false,
          keys = {
            { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'DefaultDomain' },
            { key = 'y', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
            { key = '1', mods = 'ALT', action = act.ActivateTab(0) },
            { key = '2', mods = 'ALT', action = act.ActivateTab(1) },
            { key = '3', mods = 'ALT', action = act.ActivateTab(2) },
            { key = '4', mods = 'ALT', action = act.ActivateTab(3) },
            { key = 'H', mods = 'CTRL|SHIFT', action = act.EmitEvent 'trigger-less-with-scrollback' },
          },
        }
      '';
    };
    obs-studio = {
      enable = true;
    };
    zsh = {
      initContent = /* zsh */ ''
        function reset_prog_title() {
          printf "\033]1337;SetUserVar=%s=%s\007" "IN_NIX_SHELL" "$(echo -n "$IN_NIX_SHELL" | base64)"
          print -Pn "\e]2;%~\a"
        }
        add-zsh-hook precmd reset_prog_title
      '';
      dirHashes = {
        nix = "/persist/nixos";
        personal = "${config.home.homeDirectory}/Projects/personal";
        projects = "${config.home.homeDirectory}/Projects";
      };
      shellAliases = {
        run0 = "${pkgs.systemd}/bin/run0 --background='48;2;0;95;96' --setenv=TERM=xterm-256color --via-shell";
      };
    };
  };

  services = {
    gpg-agent.pinentry.package = pkgs.wayprompt;
    hypridle = {
      enable = true;
      settings = {
        general = {
          after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
          before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";
          lock_cmd = "${pkgs.procps}/bin/pidof --single-shot hyprlock || ${lib.getExe pkgs.hyprlock}";
          unlock_cmd = "${pkgs.procps}/bin/pkill -USR1 hyprlock";
        };
        listener = [
          {
            timeout = 900;
            on-timeout = "${pkgs.systemd}/bin/loginctl lock-session";
          }
          {
            timeout = 1200;
            on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
            on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
          }
          {
            timeout = 1800;
            on-timeout = "${pkgs.systemd}/bin/systemctl suspend";
          }
        ];
      };
    };
    hyprlauncher = {
      enable = true;
      settings = {
        finders = {
          desktop_icons = false;
        };
        ui = {
          window_size = "800 520";
        };
      };
    };
    hyprpaper = {
      enable = true;
      settings = {
        splash = false;
        preload = lib.unique (map (m: m.wallpaper) monitors);
        wallpaper = map (m: {
          monitor = "desc:${m.desc}";
          path = m.wallpaper;
        }) monitors;
      };
    };
    hyprpolkitagent = {
      enable = true;
    };
    hyprsunset = {
      enable = true;
      settings = {
        max-gamma = 150;

        profile = [
          {
            time = "6:00";
            identity = true;
          }
          {
            time = "21:30";
            temperature = 5000;
            gamma = 0.8;
          }
        ];
      };
    };
    nextcloud-client = {
      enable = true;
    };
  };

  systemd.user = {
    services = {
      hyprlauncher = {
        Install.WantedBy = lib.mkForce [ ];
      };

      notification-logger = {
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = writeZsh "notification-logger.zsh" /* zsh */ ''
            setopt ERR_EXIT NO_UNSET PIPE_FAIL
            busctl_match=(
                interface=org.freedesktop.Notifications
                member=Notify
                type=method_call
            )
            ${pkgs.systemd}/bin/busctl --user --json=short --match="''${(j:,:)busctl_match[@]}" monitor \
                | ${lib.getExe pkgs.jq} --unbuffered --compact-output --raw-output \
                  '.payload.data | [.[0], .[3], .[4]] | @tsv' \
                | while IFS=$'\t' read -r app_name summary body; do
              if [[ "$app_name" == "Telegram Desktop" ]]; then
                if [[ "$body" =~ 'Reacted (.*) to your (.*)' ]]; then
                  body_str=" $match[1] ($match[2])"
                else
                  body_str=": $body"
                fi
                if [[ "$summary" == Kittykins ]]; then
                  print -r -- "<5>💜 $summary$body_str"
                else
                  print -r -- " $summary$body_str"
                fi
              else
                print -r -- "($app_name)🔔 $summary - $body"
              fi
            done
          '';
          SyslogIdentifier = "notification-logger";
          Restart = "always";
          RestartSec = 10;
        };
        Unit = {
          After = [ "graphical-session.target" ];
          ConditionEnvironment = "WAYLAND_DISPLAY";
          Description = "dbus notification logging service";
          PartOf = "graphical-session.target";
        };
      };
      hyprnotify = {
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.hyprnotify}/bin/hyprnotify";
          Restart = "always";
        };
        Unit = {
          After = [ "graphical-session.target" ];
          ConditionEnvironment = "WAYLAND_DISPLAY";
          Description = "`hyprctl notify` daemon for dbus clients";
          PartOf = "graphical-session.target";
        };
      };
    };
  };

  xdg = {
    desktopEntries = rec {
      "scrcpy-pixel" = {
        name = "Scrcpy Pixel";
        genericName = "Android Mirror";
        exec = "${lib.getExe pkgs.scrcpy} --render-driver=vulkan --video-codec=h265 --keyboard=uhid --video-bit-rate=16M --stay-awake";
        icon = "phone";
        terminal = false;
        categories = [ "Utility" ];
      };
      "scrcpy-virt-pixel" = {
        name = "Scrcpy Pixel (Virtual)";
        genericName = "Android Virtual Display";
        exec = "${scrcpy-pixel.exec} --new-display=2508x1344/250";
        icon = "phone";
        terminal = false;
        categories = [ "Utility" ];
      };
      "wezterm-open" = {
        name = "Wezterm Open Directory";
        genericName = "Terminal Emulator";
        exec = "${lib.getExe pkgs.wezterm} start --cwd %f";
        terminal = false;
        mimeType = [ "inode/directory" ];
      };
    };
    configFile = {
      "hypr/hyprtoolkit.conf".text = ''
        background = 0xFF1B1C21
        base = 0xFF1E1F20
        alternate_base = 0xFF005F60
        text = 0xFF26BDBD
        bright_text = 0xFF52FFFF
        accent = 0xFF52FFFF
        accent_secondary = 0xFF0D4747
        font_family_monospace = monospace
        h1_size = 19
        h2_size = 18
        h3_size = 16
        font_size = 15
        small_font_size = 12
        rounding_large = 10
        rounding_small = 5
      '';
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/*" = [ "nvim.desktop" ];
        "inode/directory" = [ "wezterm-open.desktop" ];
      };
    };
  };
}
