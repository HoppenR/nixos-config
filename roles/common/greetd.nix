{
  config,
  lib,
  pkgs,
  ...
}:
let
  sp = builtins.fromJSON "\"\\u2007\"";
  greeingCommon = (
    lib.strings.escapeShellArg ''
      ${sp}        | \| |_ _|\ \/ / (\_/)  / _ \/ __|        ${sp}
      ${sp}        | .`  | |  >  < (='.'=)| (_) \__ \        ${sp}
      ${sp}        |_|\_|___|/_/\_\(")_(")_\___/|___/        ${sp}
    ''
  );
  roleArt = {
    logic = lib.strings.escapeShellArg ''
      ${sp}         * / __ | |/ /  /_\  |   \|_ _| *         ${sp}
      ${sp}          *\__ \| ' <  / * \ ┼─|)  | | *          ${sp}
      ${sp}         * |___/ _|\_\/_/ \_\|___/|___| *         ${sp}
      ${sp}          * ━━━━━━━━━━━━━━━━━━━━━━━━━━ *          ${sp}
    '';
    storage = lib.strings.escapeShellArg ''
      ${sp}| || |/ _ \|   \|   \|  \|/  |_ _||  \/  |_ _| _ \${sp}
      ${sp}| __ | (_) | |) | |) | |\|/|  | | | |\/|  | |    /${sp}
      ${sp}|_||_|\___/|___/|___/|_| | |_|___||_|  |_|___|_|_\${sp}
      ${sp}            -------------┴-------------           ${sp}
    '';
    workstation = lib.strings.escapeShellArg ''
      ${sp}    .     :    |  _ \_ _|| \/ | __| ..  .    .    ${sp}
      ${sp} . ..:  . .    | `  /| | |    | __|       :       ${sp}
      ${sp}  :    .  :    |__|_\___||_||_|___|   : .   :     ${sp}
      ${sp}   /  :/ .  /    /    /    /    /    /   :/    /  ${sp}
      ${sp}--------------------------------------------------${sp}
    '';
  };
  greetingEnding = lib.strings.escapeShellArg ''
    NixOS ${config.system.nixos.version}
  '';
  greeting = greeingCommon + roleArt.${config.networking.role} + greetingEnding;
in
{
  config.services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = ''
          ${lib.getExe pkgs.tuigreet} \
            --cmd "zsh --login" \
            --greeting ${greeting} \
            --user-menu \
            --time \
            --time-format %R
        '';
      };
      terminal = {
        vt = 1;
      };
    };
  };
}
