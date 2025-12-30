{ lib, ... }:
let
  roles = {
    "yubikey-authentication" = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBv9CF8A6PvfbAFi8lLfb7iIABaT60Y8/99sFx27LjA cardno:32_457_220";
    };
    logic = {
      hostName = "skadi";
      ipv4 = "192.168.0.41";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5h7nWVcRhCpsi8RfiqyCr5tUyWQj53/VfoP7dp2mgd";
      authorizedRoles = [
        "workstation"
        "yubikey-authentication"
      ];
    };
    storage = {
      hostName = "hoddmimir";
      ipv4 = "192.168.0.42";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAHSGeQW1b4j5uOKhWWwuj1ciGZ9MO47Ucl+8jlXVWIL";
      authorizedRoles = [
        "logic"
        "yubikey-authentication"
      ];
    };
    gamehost = {
      hostName = "gladsheim";
      ipv4 = "192.168.0.43";
      authorizedRoles = [
        "logic"
        "yubikey-authentication"
      ];
    };
    hypervisor = {
      hostName = "yggdrasil";
      ipv4 = "192.168.0.44";
      authorizedRoles = [
        "logic"
        "yubikey-authentication"
      ];
    };
    workstation = {
      publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCYC83LScH9QkexkZFQQB834gCuEkFI7KIHUdJ7WJPceILeibOlB8d1CW9bFg4O8ijCxtm5LtSphGUA26XVMY+rv3T38JUfD1iIlOtHpUFLMBVT+Ox7wgJ4AuElY2wsvNcjI3FbhrjcqMOdQPrY2T6pw47aD7niegMPsR1L48H+hPqyA8/hyVOj5Cluc2MhQnLMXMWKxLiGidFV+SYrFGvEWmV2T9IzsCVqOdxyRgKJ9v1Lsx1s20ZfIwiGOEhp7EcAcbmS6tLWh862qZHgH3Yl2nwFtbmM2G/++IeSnALmSE0SjGMSIMrKHTn61HpqlZxtnkiQ8Ne2qeC+jwcHGejdBIAh59Oz8VDMWbZR/n6hdge27YgT2/s7VN4e2JorN6xi50ntRMw5BdN1P81bqBWGGV/USXiQv2+cks4R5cBtMti+pXOzhM5gIgZD/jYn+KliGj3y/e1IirYQ785CKg0/D7QDtxvzfloRXcUlp2wrrZMWcURz/waegv4eqqbeqzc=";
      hostName = "rime";
      ipv4 = "192.168.0.142";
    };
  };

  resolveKeys = map (role: roles.${role}.publicKey);
  rolesToKeys = conf: if conf ? authorizedRoles then resolveKeys conf.authorizedRoles else [ ];
  processedRoles = lib.mapAttrs (name: conf: conf // { authorizedKeys = rolesToKeys conf; }) roles;
in
processedRoles
