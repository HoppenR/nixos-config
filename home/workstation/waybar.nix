{
  lib,
  pkgs,
  writeZsh,
  monitors,
  ...
}:
{
  config.programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings =
      let
        makeModules = mon: {
          modules-left = [
            "hyprland/workspaces"
            "tray"
            "hyprland/language"
            "hyprland/submap"
            "idle_inhibitor"
            "cpu"
            "temperature"
            "memory"
            "custom/spacer"
            "custom/timers"
          ];
          modules-center = [
            "clock"
          ];
          modules-right = [
            "bluetooth"
            "custom/spacer"
            "network#lan"
            "custom/spacer"
            "network#wifi"
            "custom/spacer"
            "pulseaudio"
            "custom/spacer"
            "custom/ddc-brightness#${mon.sn}"
            "custom/spacer"
            "battery"
            "custom/spacer"
            "custom/power"
          ];
        };

        commonMainBarConfig = {
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
              "connect-script" = writeZsh "wofi-bluetooth-connect.zsh" /* zsh */ ''
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
            format = "  ${lib.concatStrings (builtins.genList (n: "{icon${toString n}}") 16)}{usage:>3}%";
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
                    <object class="GtkMenuItem" id="logout">
                      <property name="label">Log out</property>
                    </object>
                  </child>
                  <child>
                    <object class="GtkSeparatorMenuItem" id="sep"/>
                  </child>
                  <child>
                    <object class="GtkMenuItem" id="reboot">
                      <property name="label">Reboot</property>
                    </object>
                  </child>
                  <child>
                    <object class="GtkMenuItem" id="shutdown">
                      <property name="label">Shutdown</property>
                    </object>
                  </child>
                  <child>
                    <object class="GtkMenuItem" id="suspend">
                      <property name="label">Suspend</property>
                    </object>
                  </child>
                </object>
              </interface>
            '';
            menu-actions = {
              logout = "${pkgs.systemd}/bin/systemd-run --user --scope --unit=manual-logout ${lib.getExe pkgs.hyprshutdown}";
              reboot = "${pkgs.systemd}/bin/systemd-run --user --scope --unit=manual-reboot ${lib.getExe pkgs.hyprshutdown} --post-cmd '${pkgs.systemd}/bin/systemctl reboot'";
              shutdown = "${pkgs.systemd}/bin/systemd-run --user --scope --unit=manual-shutdown ${lib.getExe pkgs.hyprshutdown} --post-cmd '${pkgs.systemd}/bin/systemctl poweroff'";
              suspend = "${pkgs.systemd}/bin/systemctl suspend";
            };
            on-click = writeZsh "hyprland-logout-dialog.zsh" /* zsh */ ''
              setopt ERR_EXIT NO_UNSET PIPE_FAIL
              ans="$(${pkgs.hyprland-qtutils}/bin/hyprland-dialog --title 'Exit Hyprland?' --text 'Are you sure?' --buttons 'Yes;No')"
              if [[ "$ans" == Yes ]]; then
                ${pkgs.systemd}/bin/systemd-run --user --scope --unit=manual-logout ${lib.getExe pkgs.hyprshutdown}
              fi
            '';
          };
          "custom/timers" = {
            exec = pkgs.writers.writePerl "timers.pl" { } /* perl */ ''
              use strict;
              use warnings;
              use JSON::PP;
              my $json = JSON::PP->new;
              my $now  = time();
              sub fmt_rel {
                  my $sec = shift;
                  return "0min" if $sec <= 60;
                  my @res;
                  my %units = (w => 604800, d => 86400, h => 3600, min => 60);
                  for my $suffix (sort keys %units) {
                      if (my $count = int($sec / $units{$suffix})) {
                          push @res, "$count$suffix";
                          last if @res == 2;
                          $sec %= $units{$suffix};
                      }
                  }
                  return join(" ", @res);
              }
              sub get_sys {
                  my ($subcmd, $is_user) = @_;
                  my $out = qx(systemctl @{[ !$is_user ? "" : '--user' ]} $subcmd --output json) or return [];
                  my $result = $json->decode($out);
                  return [ map { {
                      unit => $_->{unit} =~ s/\.(?:timer|service)$//r . (!$is_user ? "" : " --user"),
                      left => $_->{left} / 1e6 - $now,
                  } } @$result ]
              }
              my @failed = map { @{ get_sys('list-units --failed', $_) } } (0, 1);
              my @timers = sort { $a->{left} <=> $b->{left} } map { @{ get_sys('list-timers', $_) } } (0, 1);
              my @tooltip = ("--- Timers ---", map { sprintf "%s: %s", $_->{unit}, fmt_rel($_->{left}) } @timers);
              my ($text, $class) = ("none", "");
              if (@failed) {
                  $text = "Failed: " . $failed[0]{unit};
                  $class = "warning";
                  push @tooltip, "--- Failed ---", map { $_->{unit} } @failed;
              } elsif (@timers) {
                  $text = sprintf("%s: %s", $timers[0]{unit}, fmt_rel($timers[0]{left}));
              }
              print $json->encode({ text => " $text", class => $class, tooltip => join("\n", @tooltip) });
            '';
            interval = 60;
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
          memory = {
            format = " {percentage}%";
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
          temperature = {
            critical-threshold = 100;
            format = "{icon} {temperatureC}°C";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
          };
          tray = {
            icon-size = 32;
            show-passive-items = true;
            spacing = 4;
          };
          "hyprland/language" = {
            format-ru = "🇷🇺";
            format-sv = "🇸🇪";
            on-click = "hyprctl switchxkblayout all next";
          };
        };

        titleBarModules = {
          exclusive = false;
          layer = "top";
          height = 27;
          margin-top = 10;
          modules-center = [ "hyprland/window" ];
          passthrough = true;
          position = "top";
          "hyprland/window" = {
            format = "{}";
            max-length = 120;
            separate-outputs = true;
          };
        };

        makeDdcBrigtnessConfig = mon: num: {
          "custom/ddc-brightness#${mon.sn}" = {
            exec = writeZsh "get-ddc-${mon.sn}.zsh" /* zsh */ ''
              setopt ERR_EXIT NO_UNSET PIPE_FAIL
              repeat 5 do
                local raw_output=$(${lib.getExe pkgs.ddcutil} --sn ${mon.sn} getvcp 10 --brief)
                if [[ "$raw_output" =~ '^VCP 10 C ([0-9]+) 100$' ]]; then
                  print -r -- "$match[1]"
                  exit 0
                fi
                sleep 0.2
              done
              print -r -- "??"
            '';
            format = "󰖨 {text:>3}%";
            interval = "once";
            on-click = writeZsh "get-ddc-${mon.sn}.zsh" /* zsh */ ''
              setopt ERR_EXIT NO_UNSET PIPE_FAIL
              ${lib.getExe pkgs.ddcutil} --sn ${mon.sn} setvcp 10 + 10
              pkill -RTMIN+${toString (num + 8)} waybar
            '';
            on-click-right = writeZsh "get-ddc-${mon.sn}.zsh" /* zsh */ ''
              setopt ERR_EXIT NO_UNSET PIPE_FAIL
              ${lib.getExe pkgs.ddcutil} --sn ${mon.sn} setvcp 10 - 10
              pkill -RTMIN+${toString (num + 8)} waybar
            '';
            signal = num + 8;
            tooltip-format = ''
              Monitor: ${mon.desc}
              Brightness 󰖨 {text}%'';
          };
        };

        bars = (
          builtins.listToAttrs (
            lib.imap0 (i: mon: {
              name = "mainBar-${mon.sn}";
              value = {
                layer = "top";
                position = "top";
                output = mon.desc;
              }
              // (makeModules mon)
              // commonMainBarConfig
              // (makeDdcBrigtnessConfig mon i);
            }) monitors
          )
        );
      in
      bars
      // {
        "titleBar" = titleBarModules;
        "mainBar-laptop" = {
          layer = "top";
          position = "top";
          output = "eDP-1";
        }
        // commonMainBarConfig
        // {
          modules-left = [
            "hyprland/workspaces"
            "tray"
            "hyprland/language"
            "hyprland/submap"
            "idle_inhibitor"
            "cpu"
            "custom/spacer"
            "custom/timers"
          ];
          modules-center = [
            "clock"
          ];
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
        };
      };
    style = /* css */ ''
      window#waybar {
        background: none;
        font-size: 18px;
        font-family: "monospace";
        color: #c6d0f5;
      }
      tooltip label {
        font-family: "monospace";
        font-size: 16px;
      }
      #window,
      window#waybar.empty #window,
      window#waybar:not(.solo) #window {
        background-color: rgba(26, 27, 38, 0.0);
        color: rgba(198, 208, 245, 0.0);
        transition: all 0.3s ease-in-out;
      }
      window#waybar.solo #window {
        background-color: rgba(26, 27, 38, 0.5);
        color: rgba(198, 208, 245, 0.75);
        padding: 0.5rem 0.7rem;
        margin: 0;
        border-radius: 0 0 6px 6px;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        border: 0.5px solid #ffffff;
      }
      #clock,
      #workspaces {
        background-color: #1a1b26;
        opacity: 0.9;
        padding: 0.5rem 0.7rem;
        margin: 8px 0;
        border-radius: 6px;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        border: none;
        transition: background-color 0.2s ease-in-out, color 0.2s ease-in-out;
      }
      #workspaces {
        padding: 2px;
        margin-left: 7px;
        margin-right: 8px;
      }
      #workspaces > button {
        color: #babbf1;
        border-radius: 5px;
        padding: 0.5rem 0.7rem;
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
        font-size: 24px;
        color: #00f7e2;
      }
      #idle_inhibitor.deactivated {
        font-size: 24px;
        color: #005F60;
      }
      #idle_inhibitor,
      #language,
      #tray {
        margin-right: 8px;
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
      menu menuitem:hover,
      #tray window:hover {
        background-color: #005f60;
      }
      menu,
      tooltip,
      #tray window decoration {
        background-color: #1a1b26;
      }
      menu separator {
        background: black;
      }
      #backlight,
      #battery,
      #bluetooth,
      #cpu,
      #custom-ddc-brightness,
      #custom-power,
      #custom-spacer,
      #custom-timers,
      #memory,
      #network,
      #pulseaudio,
      #temperature {
        background-color: #1a1b26;
        opacity: 0.9;
        padding: 0.5rem 0.6rem;
        margin: 8px 0;
        border-radius: 0;
        box-shadow: none;
        min-width: 0;
        border: none;
        transition: background-color 0.2s ease-in-out, color 0.2s ease-in-out;
      }
      #cpu,
      #bluetooth {
        border-bottom-left-radius: 6px;
        border-top-left-radius: 6px;
        margin-left: 0;
        padding-left: 20px;
      }
      #custom-timers,
      #custom-power {
        border-bottom-right-radius: 6px;
        border-top-right-radius: 6px;
        margin-right: 7px;
        padding-right: 20px;
      }
      #battery.charging,
      #battery:not(.discharging),
      #bluetooth.connected,
      #clock,
      #workspaces button.active {
        color: #99d1db;
        font-weight: 600;
      }
      #battery.warning:not(.charging),
      #custom-timers.warning,
      #network.disconnected {
        color: #e78284;
      }
    '';
  };
}
