{
  skadi = {
    admins = [ "christoffer" ];
    ipv4 = "192.168.0.41";
    ipv6 = "fd42:36f4:199c::41";
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5h7nWVcRhCpsi8RfiqyCr5tUyWQj53/VfoP7dp2mgd skadi_host_key";
  };
  hoddmimir = {
    admins = [ "christoffer" ];
    ipv4 = "192.168.0.42";
    ipv6 = "fd42:36f4:199c::42";
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP4IiOlJ3msxiPyqfa8jRT0kKuNeIXC9GOx+wgo4UGSC hoddmimir_host_key";
    role = "storage";
  };
  gladsheim = {
    admins = [ "christoffer" ];
    ipv4 = "192.168.0.43";
    ipv6 = "fd42:36f4:199c::43";
    role = "gamehost";
  };
  yggdrasil = {
    admins = [ "christoffer" ];
    ipv4 = "192.168.0.44";
    ipv6 = "fd42:36f4:199c::44";
    role = "hypervisor";
  };
  rime = {
    admins = [ "christoffer" ];
    ipv4 = "192.168.0.51";
    ipv6 = "fd42:36f4:199c::51";
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEdKicm8ChoyAw50kgGOyYnGpRLKaGxCl2YVQ4B6mWbi rime_host_key";
    role = "workstation";
  };
}
