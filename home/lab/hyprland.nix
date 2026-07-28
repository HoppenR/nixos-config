{
  config,
  lib,
  pkgs,
  ...
}:
let
  attrsToXkb =
    let
      mkIndent = level: lib.concatStrings (lib.genList (_: "  ") level);
      formatValue = v: if lib.isList v then "[ ${lib.concatStringsSep ", " v} ]" else ''"${v}"'';
      formatBlockBody =
        level: isKeyBlock: attrs:
        let
          formatEntryValue = k: if k == "_elements" then formatValue else formatNode (level + 1) k;
          formatEntry = k: v: (mkIndent (level + 1)) + formatEntryValue k v;
          mkEntries = lib.concatMapAttrsStringSep (if isKeyBlock then ",\n" else "\n") formatEntry;
        in
        "{\n${mkEntries attrs}\n${mkIndent level}};";
      formatNode =
        level: key: value:
        if key == "include" then
          ''include "${value}"''
        else if lib.isAttrs value then
          "${key} ${formatBlockBody level (lib.hasPrefix "replace key " key) value}"
        else
          "${key} = ${formatValue value}";
    in
    lib.concatMapAttrsStringSep "\n" (formatNode 0);

  moduleOptions = {
    key = lib.mkOption {
      type = lib.types.str;
    };
    mods = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    options = lib.mkOption {
      type = lib.types.submodule {
        options = {
          mouse = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
          };
          repeating = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
          };
        };
      };
      default = { };
    };
    settings = lib.mkOption {
      type = lib.types.submodule {
        options = {
          uwsm = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          terminal = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        };
      };
      default = { };
    };
  };

  mkHyprlandBind = (
    args:
    let
      extraKeys =
        moduleOptions
        |> lib.attrNames
        |> lib.removeAttrs args
        |> lib.attrNames;
      dsp =
        assert lib.assertMsg (lib.length extraKeys == 1) "Bind must have exactly one dispatcher.";
        lib.head extraKeys;

      withUWSM = (config.lab.hyprland.uwsm || args.settings.uwsm) && lib.hasPrefix "exec_" dsp;

      dspArgs =
        lib.optionals withUWSM [
          (lib.getExe pkgs.uwsm)
          "app"
          (lib.optionalString args.settings.terminal "-T")
          "--"
        ]
        ++ lib.toList args.${dsp};

      concatLuaDspArg =
        dspArgs
        |> lib.toList
        |> lib.intersperse " "
        |> lib.foldr (
          current: acc:
          if acc != [ ] && lib.isString current && lib.isString (lib.head acc) then
            [ (current + lib.head acc) ] ++ lib.tail acc
          else
            [ current ] ++ acc
        ) [ ]
        |> map (lib.generators.toLua { })
        |> lib.concatStringsSep " .. ";
    in
    {
      _args = [
        (lib.strings.concatStringsSep " + " (args.mods ++ [ args.key ]))
        (lib.generators.mkLuaInline "hl.dsp.${dsp}(${concatLuaDspArg})")
        (lib.filterAttrs (_: x: x != null) args.options)
      ];
    }
  );

  enabledMonitors = lib.filter (lib.getAttr "enabled") config.lab.hyprland.monitors;
in
{
  options.lab.hyprland = {
    uwsm = lib.mkEnableOption "Enable UWSM integration";
    monitors = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
    };
    binds = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = moduleOptions;
          freeformType = lib.types.attrs;
        }
      );
      default = [ ];
    };
  };

  config = {
    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = !config.lab.hyprland.uwsm;
      configType = "lua";
      settings = {
        animation = [
          {
            enabled = true;
            bezier = "movingLine";
            leaf = "borderangle";
            speed = 100.0;
            style = "loop";
          }
        ];
        bind = map mkHyprlandBind config.lab.hyprland.binds;
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
            kb_file = pkgs.writeText "hyprland.xkb" (attrsToXkb {
              xkb_keymap = {
                xkb_compat.include = "complete";
                xkb_keycodes.include = "evdev+aliases(qwerty)";
                xkb_symbols = {
                  include = "pc+se+ru:2+inet(evdev)";
                  "replace key <AD12>" = {
                    _elements = [
                      # Originals
                      "diaeresis"
                      "asciicircum"
                      "asciitilde"
                      "caron"
                      # Replacements on Hyper modifier
                      "dead_diaeresis"
                      "dead_circumflex"
                      "dead_tilde"
                      "dead_caron"
                    ];
                    type = "EIGHT_LEVEL";
                  };
                  "replace key <AE12>" = {
                    _elements = [
                      # Originals
                      "acute"
                      "grave"
                      "plusminus"
                      "notsign"
                      # Replacements on Hyper modifier
                      "dead_acute"
                      "dead_grave"
                      "plusminus"
                      "notsign"
                    ];
                    type = "EIGHT_LEVEL";
                  };
                  "replace key <CAPS>" = {
                    "symbols[Group1]" = [
                      "ISO_Next_Group"
                      "Caps_Lock"
                    ];
                    type = "TWO_LEVEL";
                  };
                  # Bind Print Screen as the Hyper modifier
                  "replace key <PRSC>" = {
                    _elements = [ "ISO_Level5_Shift" ];
                    type = "ONE_LEVEL";
                  };
                };
                xkb_types.include = "complete";
              };
            });
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
        }) config.lab.hyprland.monitors;
        workspace_rule = map (ws: {
          default = lib.mod ws 5 == 1;
          monitor = "desc:${(lib.elemAt enabledMonitors ((ws - 1) / 5)).desc}";
          workspace = ws;
        }) (lib.range 1 (5 * lib.length enabledMonitors));
      };
      xwayland.enable = true;
    };
  };
}
