{
  config,
  lib,
  osConfig,
  pkgs,
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
      desc = "Dell Inc. DELL P2425D ${serial}";
      mode = "2560x1440@100Hz";
      pos = "-2560x0";
      scale = 1;
      serial = "DVH9D94";
      wallpaper = "${config.home.homeDirectory}/Pictures/backgrounds/bunny-pc-bg.png";
    }
    rec {
      desc = "Dell Inc. DELL P2425D ${serial}";
      mode = "2560x1440@100Hz";
      pos = "0x0";
      scale = 1;
      serial = "CVH9D94";
      wallpaper = "${config.home.homeDirectory}/Pictures/backgrounds/saabbackground.png";
    }
    rec {
      desc = "California Institute of Technology ${serial}";
      mode = "1920x1200@60";
      pos = "2560x0";
      scale = 1;
      serial = "0x1404";
      wallpaper = "${config.home.homeDirectory}/Pictures/backgrounds/hyprland-islands.png";
    }
  ];
in
{
  _module.args = { inherit writeZsh monitors; };
  home = {
    packages = builtins.attrValues {
      inherit
        vlog
        ;

      inherit (pkgs)
        ddcutil
        discord
        hyprshutdown
        koreader
        libnotify
        scrcpy
        units
        wl-clipboard
        ;
    };
    sessionVariables = {
      BROWSER = "firefox";
      TERMINAL = "kitty";
    };
    stateVersion = "25.11";
  };

  imports = [
    ./waybar.nix
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
      general.editor = "${lib.getExe pkgs.kitty} --execute ${lib.getExe config.programs.neovim.finalPackage}";
      extraConfig = {
        "sync.9.path" = "https://joplin.${osConfig.lab.domainName}";
        "sync.9.username" = "christofferlundell@protonmail.com";
      };
      sync = {
        interval = "5m";
        target = "joplin-server";
      };
    };
    kitty = {
      enable = true;
      shellIntegration = {
        enableZshIntegration = true;
      };
      settings = {
        font_family = "monospace";
        font_size = 17;
        disable_ligatures = "cursor";
        scrollback_lines = 5000;
        enable_audio_bell = false;
        visual_bell_duration = 0.5;
        visual_bell_color = "black";
        window_alert_on_bell = true;
        remember_window_size = false;
        tab_bar_edge = "top";
        tab_bar_style = "powerline";
        tab_bar_align = "left";
        tab_bar_min_tabs = 1;
        tab_title_template = "{index}: {tab.active_exe}";
        background = "#1a1b26";
        background_opacity = 0.9;
        "map ctrl+alt+1" = "first_window";
        "map ctrl+alt+2" = "second_window";
        "map ctrl+alt+3" = "third_window";
        "map kitty_mod+t" = "new_tab_with_cwd";
        "map kitty_mod+y" = "new_tab";
        "map alt+1" = "goto_tab 1";
        "map alt+2" = "goto_tab 2";
        "map alt+3" = "goto_tab 3";
        "map alt+4" = "goto_tab 4";
        cursor_trail = 1;
        cursor_trail_decay = "0.1 0.1";
        cursor_trail_start_threshold = 2;
      };
    };
    obs-studio = {
      enable = true;
    };
    zsh = {
      dirHashes = {
        nix = "/persist/nixos";
        personal = "${config.home.homeDirectory}/Projects/personal";
      };
      shellAliases = rec {
        run0 = "${pkgs.systemd}/bin/run0 --background='48;2;0;95;96' --setenv=TERM=xterm-256color --via-shell";
        scrcpy-Pixel = "${lib.getExe pkgs.scrcpy} --render-driver=vulkan --video-codec=h265 --keyboard=uhid --video-bit-rate=16M --stay-awake";
        scrcpy-virt-Pixel = "${scrcpy-Pixel} --new-display=2508x1344/250";
        ssh = "${pkgs.kitty}/bin/kitten ssh";
        units = "${lib.getExe pkgs.units} --history ${config.xdg.stateHome}/units/history";
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
  };

  systemd.user = {
    services = {
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
              if [[ "$app_name" == discord ]]; then
                if [[ "$body" =~ 'Reacted (.*) to your (.*)' ]]; then
                  body_str=" $match[1] ($match[2])"
                else
                  body_str=": $body"
                fi
                if [[ "$summary" == Kittykins ]]; then
                  print -r -- "<5>💜 $summary$body_str"
                else
                  print -r -- " $summary$body_str"
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

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    settings = {
      animation = [
        "borderangle, 1, 100, movingLine, loop"
      ];
      bezier = [ "movingLine, 0, 0, 1, 1" ];
      cursor = {
        no_hardware_cursors = true;
      };
      general = {
        gaps_in = 10;
        gaps_out = "10, 25, 25, 25";
        "col.active_border" = "rgba(81a1c1ee) rgba(00ffccee) rgba(99d1ffee) rgba(8839efee) 45deg";
      };
      misc = {
        vrr = 2;
      };
      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          new_optimizations = true;
          passes = 2;
          size = 6;
        };
      };
      "$mod_apps" = "MOD3";
      "$mod_move" = "SUPER";
      "$mod_hypr" = "MOD5";
      "$menu_opts" = "--insensitive --match=multi-contains";
      "$run_menu" = "${lib.getExe pkgs.wofi} --show=run $menu_opts";
      "$drun_menu" = "${lib.getExe pkgs.wofi} --show=drun $menu_opts";
      "$terminal" = "${lib.getExe pkgs.kitty}";
      "$quickterm" = "${pkgs.kitty}/bin/kitten quick-access-terminal";
      bind = [
        "$mod_apps, RETURN, exec, $terminal"
        "$mod_apps, a, exec, ${lib.getExe pkgs.pavucontrol}"
        "$mod_apps, d, exec, $drun_menu"
        "$mod_apps, e, exec, $terminal --execute ${lib.getExe config.programs.neovim.finalPackage}"
        "$mod_apps, f, exec, ${lib.getExe pkgs.grimblast} --notify save area ${config.home.homeDirectory}/Pictures/Screenshots/snapshot_$(date +%F_%H-%M-%S).png"
        "$mod_apps, q, exec, $run_menu"
        "$mod_apps, w, exec, ${lib.getExe config.programs.firefox.finalPackage}"
        "$mod_hypr+SHIFT, q, killactive"
        "$mod_hypr, Space, togglefloating"
        "$mod_hypr, f, fullscreen"
        "$mod_move, h, movefocus, l"
        "$mod_move, j, movefocus, d"
        "$mod_move, k, movefocus, u"
        "$mod_move, l, movefocus, r"
        "$mod_move, q, workspace, 1"
        "$mod_move, w, workspace, 2"
        "$mod_move, e, workspace, 3"
        "$mod_move, r, workspace, 4"
        "$mod_move, t, workspace, 5"
        "$mod_move, y, workspace, 6"
        "$mod_move, u, workspace, 7"
        "$mod_move, i, workspace, 8"
        "$mod_move, o, workspace, 9"
        "$mod_move+SHIFT, q, movetoworkspacesilent, 1"
        "$mod_move+SHIFT, w, movetoworkspacesilent, 2"
        "$mod_move+SHIFT, e, movetoworkspacesilent, 3"
        "$mod_move+SHIFT, r, movetoworkspacesilent, 4"
        "$mod_move+SHIFT, t, movetoworkspacesilent, 5"
        "$mod_move+SHIFT, y, movetoworkspacesilent, 6"
        "$mod_move+SHIFT, u, movetoworkspacesilent, 7"
        "$mod_move+SHIFT, i, movetoworkspacesilent, 8"
        "$mod_move+SHIFT, o, movetoworkspacesilent, 9"
        "$mod_move+SHIFT, h, movewindow, l"
        "$mod_move+SHIFT, j, movewindow, d"
        "$mod_move+SHIFT, k, movewindow, u"
        "$mod_move+SHIFT, l, movewindow, r"
      ];
      binde = [
        ", XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86MonBrightnessUp, exec, ${lib.getExe pkgs.brightnessctl} --class=backlight set +20%"
        ", XF86MonBrightnessDown, exec, ${lib.getExe pkgs.brightnessctl} --class=backlight set 20%-"
        "$mod_hypr, l, resizeactive, 50 0"
        "$mod_hypr, h, resizeactive, -50 0"
        "$mod_hypr, k, resizeactive, 0 -50"
        "$mod_hypr, j, resizeactive, 0 50"
      ];
      bindm = [
        "$mod_move, mouse:272, movewindow"
        "$mod_move, mouse:273, resizewindow"
      ];
      env = [
        "NIXOS_OZONE_WL,1"
      ];
      workspace = [
        "1,monitor:$mon_1,default:true"
        "2,monitor:$mon_1"
        "3,monitor:$mon_1"
        "4,monitor:$mon_1"
        "5,monitor:$mon_1"
        "6,monitor:$mon_2,default:true"
        "7,monitor:$mon_2"
        "8,monitor:$mon_2"
        "9,monitor:$mon_2"
      ];
      device = {
        name = "at-translated-set-2-keyboard";
        repeat_delay = 200;
        repeat_rate = 25;
      };
      input = {
        kb_layout = "se";
        repeat_delay = 200;
        repeat_rate = 25;
        kb_file = "${pkgs.writeText "hyprland.xkb" /* xkb */ ''
          xkb_keymap {
            xkb_keycodes { include "evdev+aliases(qwerty)" };
            xkb_types { include "complete" };
            xkb_compat { include "complete" };
            xkb_symbols {
              include "pc+se+ru:2+inet(evdev)"
              replace key <PRSC> { [ ISO_Level5_Shift ] };
              replace key <AD12> { type = "EIGHT_LEVEL", [ diaeresis, asciicircum, asciitilde, caron, dead_diaeresis, dead_circumflex, dead_tilde, dead_caron ] };
              replace key <AE12> { type = "EIGHT_LEVEL", [ acute, grave, plusminus, notsign, dead_acute, dead_grave, plusminus, notsign ] };
              replace key <CAPS> {
                type = "TWO_LEVEL",
                symbols[Group1] = [ ISO_Next_Group, Caps_Lock ]
              };
            };
          };
        ''}";
      };
    }
    // (lib.listToAttrs (
      lib.imap1 (i: mon: {
        name = "$mon_${toString i}";
        value = "desc:${mon.desc}";
      }) monitors
    ))
    // {
      monitor = map (m: "desc:${m.desc}, ${m.mode}, ${m.pos}, ${toString m.scale}") monitors;
    };
    xwayland.enable = true;
  };

  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/*" = [ "nvim.desktop" ];
        "inode/directory" = [ "kitty-open.desktop" ];
      };
    };
  };
}
