{
  lib,
  ...
}:
{
  options.lab = {
    mainUser = lib.mkOption {
      type = lib.types.str;
      default = "mainuser";
    };
  };
}
