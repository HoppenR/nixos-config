{ lib, ... }:
let
  roles = {
    "yubikey-authentication" = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBv9CF8A6PvfbAFi8lLfb7iIABaT60Y8/99sFx27LjA cardno:32_457_220";
    };
    logic = {
      hostName = "skadi";
      ipv4 = "192.168.0.41";
      ipv6 = "fd42:36f4:199c::41";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5h7nWVcRhCpsi8RfiqyCr5tUyWQj53/VfoP7dp2mgd skadi_host_key";
      authorizedRoles = [
        "workstation"
        "yubikey-authentication"
      ];
    };
    storage = {
      hostName = "hoddmimir";
      ipv4 = "192.168.0.42";
      ipv6 = "fd42:36f4:199c::42";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP4IiOlJ3msxiPyqfa8jRT0kKuNeIXC9GOx+wgo4UGSC hoddmimir_host_key";
      authorizedRoles = [
        "logic"
        "workstation"
        "yubikey-authentication"
      ];
    };
    gamehost = {
      hostName = "gladsheim";
      ipv4 = "192.168.0.43";
      ipv6 = "fd42:36f4:199c::43";
      authorizedRoles = [
        "logic"
        "yubikey-authentication"
      ];
    };
    hypervisor = {
      hostName = "yggdrasil";
      ipv4 = "192.168.0.44";
      ipv6 = "fd42:36f4:199c::44";
      authorizedRoles = [
        "logic"
        "yubikey-authentication"
      ];
    };
    workstation = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJRxoYKlDRdNI4GoqjKKXhp4Tve9+1/TaukRAlQOV2rd christoffer@rime";
      hostName = "rime";
      ipv4 = "192.168.0.51";
      ipv6 = "fd42:36f4:199c::51";
    };
  };

  resolveKeys = map (role: roles.${role}.publicKey);
  rolesToKeys = conf: if conf ? authorizedRoles then resolveKeys conf.authorizedRoles else [ ];
  processedRoles = lib.mapAttrs (name: conf: conf // { authorizedKeys = rolesToKeys conf; }) roles;
in
processedRoles
