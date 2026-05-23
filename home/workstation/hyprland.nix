{
  config,
  lib,
  pkgs,
  monitors,
  ...
}:
let
  mod_apps = "MOD3";
  mod_hypr = "MOD5";
  mod_move = "SUPER";
  enabledMonitors = lib.filter (lib.getAttr "enabled") monitors;
  workspaceCharacters = lib.stringToCharacters "qwertyuiop";
  workspaceKeys = lib.listToAttrs (lib.imap1 (n: k: lib.nameValuePair k n) workspaceCharacters);
  mkHyprlandBinds = map (
    args:
    let
      dsp =
        lib.removeAttrs args [
          "mods"
          "key"
          "options"
        ]
        |> lib.attrNames
        |> lib.head;
      concatArgs =
        args.${dsp}
        |> lib.toList
        |> lib.intersperse " "
        |> lib.foldl' (
          acc: current:
          if acc == [ ] || !lib.isString (lib.last acc) || !lib.isString current then
            acc ++ [ current ]
          else
            (lib.init acc) ++ [ (lib.last acc + current) ]
        ) [ ]
        |> map (lib.generators.toLua { })
        |> lib.concatStringsSep " .. ";
    in
    {
      _args = [
        (lib.strings.concatStringsSep " + " ((args.mods or [ ]) ++ [ args.key ]))
        (lib.generators.mkLuaInline "hl.dsp.${dsp}(${concatArgs})")
        args.options or { }
      ];
    }
  );
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    # NOTE: UWSM already handles target activation:
    systemd.enable = false;
    configType = "lua";
    settings = {
      terminal._var = lib.getExe pkgs.wezterm;
      animation = [
        {
          enabled = true;
          bezier = "movingLine";
          leaf = "borderangle";
          speed = 100.0;
          style = "loop";
        }
      ];
      bind = mkHyprlandBinds (
        [
          # --- Application Launchers (hl.dsp.exec_raw) ---
          {
            mods = [ mod_apps ];
            key = "RETURN";
            exec_raw = lib.generators.mkLuaInline "terminal";
          }
          {
            mods = [ mod_apps ];
            key = "a";
            exec_raw = lib.getExe pkgs.pavucontrol;
          }
          {
            mods = [ mod_apps ];
            key = "d";
            exec_raw = lib.getExe pkgs.hyprlauncher;
          }
          {
            mods = [ mod_apps ];
            key = "e";
            exec_raw = [
              (lib.generators.mkLuaInline "terminal")
              "start"
              (lib.getExe config.programs.neovim.finalPackage)
            ];
          }
          {
            mods = [ mod_apps ];
            key = "w";
            exec_raw = lib.getExe config.programs.firefox.finalPackage;
          }
          {
            mods = [ mod_apps ];
            key = "f";
            exec_raw = [
              (lib.getExe pkgs.grimblast)
              "--notify"
              "save"
              "area"
              "${config.home.homeDirectory}/Pictures/Screenshots/snapshot_$(date +%F_%H-%M-%S).png"
            ];
          }
          # --- Window Core Actions (hl.dsp.window) ---
          {
            mods = [
              mod_hypr
              "SHIFT"
            ];
            key = "q";
            "window.close" = [ ];
          }
          {
            mods = [ mod_hypr ];
            key = "Space";
            "window.float".action = "toggle";
          }
          {
            mods = [ mod_hypr ];
            key = "f";
            "window.fullscreen".action = "toggle";
          }
          # --- Directional Navigation (hl.dsp.focus hl.dsp.window.move hl.dsp.window.resize) ---
          {
            mods = [ mod_move ];
            key = "h";
            focus.direction = "l";
          }
          {
            mods = [ mod_move ];
            key = "j";
            focus.direction = "d";
          }
          {
            mods = [ mod_move ];
            key = "k";
            focus.direction = "u";
          }
          {
            mods = [ mod_move ];
            key = "l";
            focus.direction = "r";
          }
          {
            mods = [
              mod_move
              "SHIFT"
            ];
            key = "h";
            "window.move".direction = "l";
          }
          {
            mods = [
              mod_move
              "SHIFT"
            ];
            key = "j";
            "window.move".direction = "d";
          }
          {
            mods = [
              mod_move
              "SHIFT"
            ];
            key = "k";
            "window.move".direction = "u";
          }
          {
            mods = [
              mod_move
              "SHIFT"
            ];
            key = "l";
            "window.move".direction = "r";
          }
          {
            mods = [ mod_hypr ];
            key = "l";
            "window.resize" = {
              x = 50;
              y = 0;
              relative = true;
            };
            options.repeating = true;
          }
          {
            mods = [ mod_hypr ];
            key = "h";
            "window.resize" = {
              x = -50;
              y = 0;
              relative = true;
            };
            options.repeating = true;
          }
          {
            mods = [ mod_hypr ];
            key = "k";
            "window.resize" = {
              x = 0;
              y = -50;
              relative = true;
            };
            options.repeating = true;
          }
          {
            mods = [ mod_hypr ];
            key = "j";
            "window.resize" = {
              x = 0;
              y = 50;
              relative = true;
            };
            options.repeating = true;
          }
          # --- Hardware & Media Controls (hl.dsp.exec_raw) ---
          {
            key = "XF86AudioRaiseVolume";
            exec_raw = [
              "${pkgs.wireplumber}/bin/wpctl"
              "set-volume"
              "-l"
              "1.0"
              "@DEFAULT_AUDIO_SINK@"
              "5%+"
            ];
            options.repeating = true;
          }
          {
            key = "XF86AudioLowerVolume";
            exec_raw = [
              "${pkgs.wireplumber}/bin/wpctl"
              "set-volume"
              "-l"
              "1.0"
              "@DEFAULT_AUDIO_SINK@"
              "5%-"
            ];
            options.repeating = true;
          }
          {
            key = "XF86AudioMute";
            exec_raw = [
              "${pkgs.wireplumber}/bin/wpctl"
              "set-mute"
              "@DEFAULT_AUDIO_SINK@"
              "toggle"
            ];
          }
          {
            key = "XF86MonBrightnessUp";
            exec_raw = [
              (lib.getExe pkgs.brightnessctl)
              "--class=backlight"
              "set"
              "+20%"
            ];
            options.repeating = true;
          }
          {
            key = "XF86MonBrightnessDown";
            exec_raw = [
              (lib.getExe pkgs.brightnessctl)
              "--class=backlight"
              "set"
              "20%-"
            ];
            options.repeating = true;
          }
          {
            mods = [ mod_move ];
            key = "mouse:272";
            "window.drag" = [ ];
            options.mouse = true;
          }
          {
            mods = [ mod_move ];
            key = "mouse:273";
            "window.resize" = [ ];
            options.mouse = true;
          }
        ]
        # --- Workspace Focus Binds (hl.dsp.focus.workspace) ---
        ++ (lib.mapAttrsToList (key: num: {
          mods = [ mod_move ];
          inherit key;
          focus.workspace = num;
        }) workspaceKeys)
        # --- Move Window to Workspace Binds (hl.dsp.window.move) ---
        ++ (lib.mapAttrsToList (key: num: {
          mods = [
            mod_move
            "SHIFT"
          ];
          inherit key;
          "window.move" = {
            workspace = num;
            follow = false;
          };
        }) workspaceKeys)
      );
      config = {
        animations = {
          enabled = true;
        };
        cursor = {
          no_hardware_cursors = true;
        };
        general = {
          gaps_in = 10;
          gaps_out = 25;
          col = {
            active_border = {
              colors = [
                "rgba(81a1c1ee)"
                "rgba(00ffccee)"
                "rgba(99d1ffee)"
                "rgba(8839efee)"
              ];
              angle = 45;
            };
          };
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
      };
      curve = [
        {
          _args = [
            "movingLine"
            {
              points = lib.genList (n: lib.genList (_: n) 2) 2;
              type = "bezier";
            }
          ];
        }
      ];
      device = {
        name = "at-translated-set-2-keyboard";
        repeat_delay = 200;
        repeat_rate = 25;
      };
      env = [
        {
          _args = [
            "NIXOS_OZONE_WL"
            1
          ];
        }
      ];
      monitor = map (m: {
        disabled = !m.enabled;
        inherit (m) mode position scale;
        output = "desc:${m.desc}";
      }) monitors;
      workspace_rule = map (ws: {
        default = lib.mod ws 5 == 1;
        monitor = "desc:${(lib.elemAt enabledMonitors ((ws - 1) / 5)).desc}";
        workspace = ws;
      }) (lib.range 1 (5 * lib.length enabledMonitors));
    };
    xwayland.enable = true;
  };
}
