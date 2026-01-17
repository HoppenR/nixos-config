{
  config,
  lib,
  pkgs,
  ...
}:
let
  writeZsh = pkgs.writers.makeScriptWriter {
    interpreter = lib.getExe pkgs.zsh;
  };

  vlog = pkgs.writeScriptBin "vlog" ''
    #!${lib.getExe pkgs.zsh}
    local filter='. | "[\(.__REALTIME_TIMESTAMP | tonumber / 1000000 | strflocaltime("%H:%M:%S"))] \(.MESSAGE)"'

    ${pkgs.systemd}/bin/journalctl --user --unit=notification-logger "$@" --output=json \
      | ${pkgs.jq}/bin/jq --raw-output "$filter" \
      | less +G
  '';
in
{
  home = {
    sessionVariables = {
      BROWSER = "firefox";
      TERMINAL = "kitty";
    };
    packages = builtins.attrValues {
      inherit
        vlog
        ;

      inherit (pkgs)
        discord
        koreader
        libnotify
        scrcpy
        wl-clipboard
        ;
    };
    stateVersion = "25.11";
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    settings = {
      "$mod_apps" = "MOD3";
      "$mod_move" = "SUPER";
      "$mod_hypr" = "MOD5";
      "$mon_dock" = "desc:Acer Technologies Acer XF270H 0x542079DA";
      "$mon_bltn" = "desc:California Institute of Technology 0x1404";
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
        "$mod_apps, f, exec, ${lib.getExe pkgs.hyprshot} --mode region --output-folder ${config.home.homeDirectory}/Pictures/screenshots"
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
      workspace = [
        "1,monitor:$mon_dock,default:true"
        "2,monitor:$mon_dock"
        "3,monitor:$mon_dock"
        "4,monitor:$mon_dock"
        "5,monitor:$mon_dock"
        "6,monitor:$mon_bltn,default:true"
        "7,monitor:$mon_bltn"
        "8,monitor:$mon_bltn"
        "9,monitor:$mon_bltn"
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
              replace key <CAPS> {
                type = "TWO_LEVEL",
                symbols[Group1] = [ ISO_Next_Group, Caps_Lock ]
              };
            };
          };
        ''}";
      };
      monitor = [
        "$mon_bltn, 1920x1200@60, 0x0, 1"
        "$mon_dock, 1920x1080@144, -1920x0, 1"
      ];
    };
    xwayland.enable = true;
  };

  programs = {
    firefox = {
      enable = true;
      languagePacks = [
        "en-US"
        "sv-SE"
      ];
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
    kitty = {
      enable = true;
      shellIntegration = {
        enableZshIntegration = true;
      };
      settings = {
        font_family = "monospace";
        font_size = 15;
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
        background_opacity = 0.95;
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
    waybar = {
      enable = true;
      systemd.enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          modules-left = [
            "hyprland/workspaces"
            "tray"
            "hyprland/language"
            "hyprland/submap"
            "idle_inhibitor"
            "cpu"
            "custom/timers"
          ];
          modules-center = [ "clock" ];
          modules-right = [
            "bluetooth"
            "custom/spacer"
            "network#lan"
            "custom/spacer"
            "network#wifi"
            "custom/spacer"
            "pulseaudio"
            "custom/spacer"
            "backlight"
            "custom/spacer"
            "battery"
            "custom/spacer"
            "custom/power"
          ];
          backlight = {
            format = "󰖨 {percent:>3}%";
          };
          battery = {
            format = "{icon} {capacity:>3}%";
            format-icons = {
              charging = [
                "󰢜"
                "󰂆"
                "󰂇"
                "󰂈"
                "󰢝"
                "󰂉"
                "󰢞"
                "󰂊"
                "󰂋"
                "󰂅"
              ];
              default = [
                "󰁺"
                "󰁻"
                "󰁼"
                "󰁽"
                "󰁾"
                "󰁿"
                "󰂀"
                "󰂁"
                "󰂂"
                "󰁹"
              ];
            };
            full-at = 70;
          };
          bluetooth = {
            format = "";
            format-disabled = "󰂲";
            format-connected = "󰂱 {num_connections}";
            tooltip-format = " {device_alias}";
            tooltip-format-connected = "{device_enumerate}";
            tooltip-format-enumerate-connected = " {device_alias}";
            on-click = "${lib.getExe pkgs.kitty} --execute bluetoothctl";
            menu = "on-click-right";
            menu-file = pkgs.writeText "waybar-bluetooth-menu.xml" /* xml */ ''
              <?xml version="1.0" encoding="UTF-8"?>
               <interface>
                <object class="GtkMenu" id="menu">
                  <child>
                    <object class="GtkMenuItem" id="connect-script">
                      <property name="label">Manage Connections</property>
                    </object>
                  </child>
                </object>
              </interface>
            '';
            menu-actions = {
              "connect-script" = writeZsh "wofi-bluetooth-connect.zsh" ''
                setopt ERR_EXIT NO_UNSET PIPE_FAIL
                typeset -a action_list
                for line in "''${(@f)$(${pkgs.bluez}/bin/bluetoothctl devices)}"; do
                  if [[ "$line" =~ '^Device ([0-9A-F:]+) (.+)$' ]]; then
                    info="$(${pkgs.bluez}/bin/bluetoothctl info "$match[1]")"
                    if [[ "$info" == *"Connected: yes"* ]]; then
                      action_list+=("[x] Disconnect from $match[2] -- $match[1]")
                    elif [[ "$info" == *"Connected: no"* ]]; then
                      action_list+=("[ ] Connect to $match[2] -- $match[1]")
                    fi
                  fi
                done
                if (( ''${#action_list} == 0 )); then
                  exit 0
                fi
                wofi_opts=(
                  --show dmenu
                  --insensitive
                  --match=multi-contains
                  --prompt "Bluetooth Connect/Disconnect"
                  --cache-file /dev/null
                )
                selection=$(print -rl -- $action_list | ${lib.getExe pkgs.wofi} $wofi_opts)
                if [[ "$selection" =~ '^\[(.)\] (Connect to|Disconnect from) (.*) -- (.*)$' ]]; then
                  device_path="/org/bluez/hci0/dev_''${match[4]//:/_}"
                  if [[ "$match[1]" == "x" ]]; then
                    notify-send "Bluetooth" "Disconnecting from $match[3]"
                    busctl call --timeout=15 org.bluez "$device_path" org.bluez.Device1 Disconnect
                  elif [[ "$match[1]" == " " ]]; then
                    notify-send "Bluetooth" "Connecting to $match[3]..."
                    busctl call --timeout=15 org.bluez "$device_path" org.bluez.Device1 Connect
                    notify-send "Bluetooth" "Connected to $match[3]."
                  fi
                fi
              '';
            };
          };
          clock = {
            locale = "sv_SE.UTF-8";
            tooltip-format = "{:L%A %F}";
          };
          cpu = {
            format = "  ${lib.concatStrings (builtins.genList (n: "{icon${toString n}}") 16)} {usage:>2}%";
            format-icons = [
              "▁"
              "▂"
              "▃"
              "▄"
              "▅"
              "▆"
              "▇"
              "█"
            ];
            on-click = "${lib.getExe pkgs.kitty} --execute ${lib.getExe pkgs.btop} --preset 1";
          };
          "custom/spacer" = {
            format = "│";
            interval = "once";
            tooltip = false;
          };
          "custom/power" = {
            format = "⏻";
            tooltip = false;
            menu = "on-click-right";
            menu-file = pkgs.writeText "waybar-powermenu.xml" /* xml */ ''
              <?xml version="1.0" encoding="UTF-8"?>
              <interface>
                <object class="GtkMenu" id="menu">
                  <child>
                    <object class="GtkMenuItem" id="shutdown">
                      <property name="label">Shutdown</property>
                    </object>
                  </child>
                  <child>
                    <object class="GtkMenuItem" id="reboot">
                      <property name="label">Reboot</property>
                    </object>
                  </child>
                  <child>
                    <object class="GtkMenuItem" id="suspend">
                      <property name="label">Suspend</property>
                    </object>
                  </child>
                  <child>
                    <object class="GtkSeparatorMenuItem" id="sep"/>
                  </child>
                  <child>
                    <object class="GtkMenuItem" id="logout">
                      <property name="label">Exit Hyprland</property>
                    </object>
                  </child>
                </object>
              </interface>
            '';
            menu-actions = {
              shutdown = "${pkgs.systemd}/bin/systemctl poweroff";
              reboot = "${pkgs.systemd}/bin/systemctl reboot";
              suspend = "${pkgs.systemd}/bin/systemctl suspend";
              logout = "${pkgs.hyprland}/bin/hyprctl dispatch exit";
            };
            on-click = writeZsh "hyprland-poweroff-dialog.zsh" ''
              ans="$(${pkgs.hyprland-qtutils}/bin/hyprland-dialog --title 'Exit Hyprland?' --text 'Are you sure?' --buttons 'Yes;No')"
              if [[ "$ans" == Yes ]]; then
                ${pkgs.hyprland}/bin/hyprctl dispatch exit
              fi
            '';
          };
          "custom/timers" = {
            exec = pkgs.writers.writePerl "timers.pl" { } ''
              use strict;
              use warnings;

              my @tooltip_lines;
              my @timer_table = qx(systemctl --quiet list-timers);
              my $first_timer;
              die "list-timers command exited with non-zero status: $?\n" if $? != 0;

              if (scalar @timer_table != 0) {
                  my $re_date = qr/\w{3} [\d-]{10} [\d:]{8} \w{3,4}/;
                  my $re_last = qr/-|$re_date/;
                  my $re_unit = qr/years?|months?|weeks?|days?|h|min|s/;
                  my $re_qnty = qr/\d{1,2} ?$re_unit/;
                  my $re_time = qr/$re_qnty ?$re_qnty?/;
                  my $re_pass = qr/-|$re_time ago/;
                  my $re_main = qr/
                      ^
                      $re_date\s+            # NEXT
                      (?<time>$re_time)\s    # LEFT
                      $re_last\s+            # LAST
                      $re_pass\s             # PASSED
                      (?<name>\S+)\.timer\s+   # UNIT
                      \k<name>\.service        # ACTIVATES
                      $
                  /x;
                  push @tooltip_lines, "--- Timers ---";
                  my @timers = map { /$re_main/ ? "$+{name}: $+{time}" : () } @timer_table;
                  $first_timer = $timers[0];
                  push @tooltip_lines, @timers;
              }

              my @fail_table = qx(systemctl --quiet list-units --failed --plain);
              my $first_failed;
              die "list-units command exited with non-zero status: $?\n" if $? != 0;

              if (scalar @fail_table != 0) {
                  my $re_failed = qr/(?<name>\S+)\.service/;
                  push @tooltip_lines, "--- Failed units ---";
                  my @failed = map { /$re_failed/ ? "$+{name}" : () } @fail_table;
                  $first_failed = $failed[0];
                  push @tooltip_lines, @failed;
              }

              my $class = (scalar @fail_table == 0) ? "" : 'warning';
              my $text = (defined $first_failed) ? "Failed: $first_failed" : ($first_timer // "none");
              my $tooltip = join('\n', @tooltip_lines);
              printf '{"class":"%s","text":" %s","tooltip":"%s"}', $class, $text, $tooltip;
            '';
            interval = 300;
            on-click = "${lib.getExe pkgs.kitty} --execute ${pkgs.systemd}/bin/systemctl --user status";
            return-type = "json";
          };
          idle_inhibitor = {
            format = "{icon}";
            format-icons = {
              activated = "󰒳 ";
              deactivated = "󰒲 ";
            };
            "timeout" = 60;
          };
          "network#lan" = {
            format-disconnected = "󱘖 no lan";
            format-ethernet = "󰌘 {ifname}";
            interface = "lan0";
            on-click = "${lib.getExe pkgs.kitty} --execute ${lib.getExe pkgs.btop} --preset 3";
            tooltip-format = ''
              󰈀 {ifname} via {gwaddr}
              IP: {ipaddr}/{cidr}'';
          };
          "network#wifi" = {
            format-disconnected = "󰤮 no wifi";
            format-wifi = "{icon} {essid}";
            format-icons = [
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
            interface = "laptop-wifi";
            on-click = "${lib.getExe pkgs.kitty} --execute ${pkgs.iwd}/bin/iwctl";
            tooltip-format = ''
               {essid} ({signalStrength}%)
              IP: {ipaddr}/{cidr}
              Freq: {frequency}MHz'';
          };
          pulseaudio = {
            format = "{icon} {volume:>3}%";
            format-muted = " {volume:>3}%";
            format-icons = {
              default = [
                ""
                ""
                ""
              ];
            };
            on-click = "${lib.getExe pkgs.pavucontrol}";
          };
          tray = {
            icon-size = 24;
            show-passive-items = true;
            spacing = 4;
          };
          "hyprland/language" = {
            format-ru = "🇷🇺";
            format-sv = "🇸🇪";
            on-click = "hyprctl switchxkblayout all next";
          };
        };
      };
      style = /* css */ ''
        * {
          background: transparent;
          font-size: 14px;
          font-family: "monospace";
          color: #c6d0f5;
        }
        #clock,
        #cpu,
        #workspaces {
          background-color: #1a1b26;
          padding: 0.3rem 0.7rem;
          margin: 5px 0px;
          border-radius: 6px;
          box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
          min-width: 0;
          border: none;
          transition: background-color 0.2s ease-in-out, color 0.2s ease-in-out;
        }
        #workspaces {
          padding: 2px;
          margin-left: 7px;
          margin-right: 5px;
        }
        #workspaces > button {
          color: #babbf1;
          border-radius: 5px;
          padding: 0.3rem 0.7rem;
          background: transparent;
          transition: all 0.2s ease-in-out;
          border: none;
          outline: none;
          box-shadow: none;
        }
        #workspaces > button:hover {
          background-image: none;
          text-shadow: none;
        }
        #workspaces button.active {
          background-color: rgba(153, 209, 219, 0.1);
        }
        #idle_inhibitor.activated {
          font-size: 18px;
          color: #00f7e2;
        }
        #idle_inhibitor.deactivated {
          font-size: 18px;
          color: #005F60;
        }
        #custom-timers {
          font-size: 10px;
          text-shadow: 1px 1px black;
        }
        #cpu,
        #idle_inhibitor,
        #language,
        #tray {
          margin-right: 5px;
        }
        menu menuitem label,
        #tray window {
          color: #656c73;
        }
        menu menuitem:hover label,
        tooltip label,
        #tray window:hover {
          color: white;
        }
        menu,
        tooltip,
        #tray window decoration {
          background-color: #1a1b26;
        }
        menu separator {
          background: black;
        }
        #bluetooth,
        #custom-spacer,
        #custom-power,
        #pulseaudio,
        #backlight,
        #network,
        #battery {
          background-color: #1a1b26;
          padding: 0.3rem 0.6rem;
          margin: 5px 0px;
          border-radius: 0;
          box-shadow: none;
          min-width: 0;
          border: none;
          transition: background-color 0.2s ease-in-out, color 0.2s ease-in-out;
        }
        #bluetooth {
          border-bottom-left-radius: 6px;
          border-top-left-radius: 6px;
          margin-left: 0px;
          padding-left: 20px;
        }
        #custom-power {
          border-bottom-right-radius: 6px;
          border-top-right-radius: 6px;
          margin-right: 7px;
          padding-right: 20px;
        }
        #battery:not(.discharging),
        #battery.charging,
        #bluetooth.connected,
        #clock {
          color: #99d1db;
        }
        #clock {
          font-weight: 600;
        }
        #network.disconnected {
          color: #e78284;
        }
        #battery.warning:not(.charging) {
          color: #e78284;
        }
      '';
    };
    zsh = {
      shellAliases = {
        run0 = "${pkgs.systemd}/bin/run0 --background='48;2;0;95;96' --setenv=TERM=xterm-256color --via-shell";
        ssh = "${pkgs.kitty}/bin/kitten ssh";
        scrcpy-Pixel = "${lib.getExe pkgs.scrcpy} --new-display=1880x992/140 --render-driver=vulkan --video-codec=h265 --keyboard=uhid --mouse=uhid --video-bit-rate=16M --stay-awake";
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
        ipc = "on";
        splash = true;
        splash_offset = 2.0;
        preload = [
          "${config.home.homeDirectory}/Pictures/backgrounds/saturn-rings.png"
        ];
        wallpaper = [
          ",${config.home.homeDirectory}/Pictures/backgrounds/saturn-rings.png"
        ];
      };
    };
    hyprpolkitagent = {
      enable = true;
    };
  };

  systemd.user.services = {
    notification-logger = {
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = writeZsh "notification-logger.zsh" ''
          read_dbus_string() {
            local input
            read -r input
            print -r -- "''${(Q)input#string }"
          }
          declare -a session_args
          session_args=(
              type='method_call'
              interface='org.freedesktop.Notifications'
              member='Notify'
          )
          ${pkgs.coreutils}/bin/stdbuf --output=L \
              ${pkgs.dbus}/bin/dbus-monitor "''${(j:,:)session_args}" \
              | while read -r line; do
            if [[ "$line" =~ member=Notify ]]; then
              app_name=$(read_dbus_string)
              repeat 2 read -r _
              summary=$(read_dbus_string)
              body=$(read_dbus_string)
              if [[ "$app_name" == discord ]]; then
                local body_str=""
                if [[ "$body" =~ 'Reacted(.*)to your(.*)' ]]; then
                  body_str=" $match[1] ($match[2])"
                else
                  body_str=": $body"
                fi
                if [[ "$summary" == Kitty ]]; then
                  print -r -- "<5>💜 $summary$body_str"
                else
                  print -r -- " $summary$body_str"
                fi
              else
                print -r -- "($app_name)🔔 $summary - $body"
              fi
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
        X-Restart-Triggers = [ "" ];
      };
    };
    hyprnotify = {
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.hyprnotify}/bin/hyprnotify";
        Restart = "always";
        RestartSec = 10;
      };
      Unit = {
        After = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
        Description = "`hyprctl notify` daemon for dbus clients";
        PartOf = "graphical-session.target";
      };
    };
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
