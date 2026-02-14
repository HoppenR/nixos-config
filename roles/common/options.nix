{
  lib,
  ...
}:
{
  options.lab = {
    domainName = lib.mkOption {
      type = lib.types.str;
      default = "hoppenr.xyz";
    };
    mainUser = lib.mkOption {
      type = lib.types.str;
      default = "mainuser";
    };
  };
}
