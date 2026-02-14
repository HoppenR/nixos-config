{
  lib,
  ...
}:
{
  options.lab = {
    domainName = lib.mkOption {
      type = lib.types.str;
    };
  };
}
