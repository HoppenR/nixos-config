{
  config,
  lib,
  net,
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
        listenAddresses = [
          {
            addr = net.ip net.mgmt config.networking.hostName;
            port = 22;
          }
          {
            addr = net.ip6 net.mgmt config.networking.hostName;
            port = 22;
          }
        ];
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
          UseDns = true;
        };
      };
    };
  };
}
