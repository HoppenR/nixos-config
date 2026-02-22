{
  config,
  lib,
  ...
}:
{
  options.lab = {
    openssh.enable = lib.mkEnableOption "enable openssh lab config";
  };

  config = lib.mkIf config.lab.openssh.enable {
    services = {
      openssh = {
        enable = true;
        hostKeys = [
          {
            path = "/persist/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
        settings = {
          AuthenticationMethods = "publickey";
          KbdInteractiveAuthentication = false;
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };
    };
  };
}
