{ lib, roles, ... }:
let
  roleList = builtins.attrNames roles;
in
{
  options.networking.role = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum roleList);
    default = null;
    description = "The role of the machine. Currently maps to a single host or device";
  };
}
