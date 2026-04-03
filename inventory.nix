{
  bifrost = {
    admins = [ "christoffer" ];
    ipv4 = "192.168.0.1";
    ipv6 = "fd42:36f4:199c::1";
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHZy39Wyk45pgwxRggpZ3v88OKbuSbpq3sLQFvc6Z9rO bifrost_host_key";
    role = "router";
    topology = "home";
  };
  skadi = {
    admins = [ "christoffer" ];
    ipv4 = "192.168.0.41";
    ipv6 = "fd42:36f4:199c::41";
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5h7nWVcRhCpsi8RfiqyCr5tUyWQj53/VfoP7dp2mgd skadi_host_key";
    role = "logic";
    topology = "home";
  };
  hoddmimir = {
    admins = [ "christoffer" ];
    ipv4 = "192.168.0.42";
    ipv6 = "fd42:36f4:199c::42";
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP4IiOlJ3msxiPyqfa8jRT0kKuNeIXC9GOx+wgo4UGSC hoddmimir_host_key";
    role = "storage";
    topology = "home";
  };
  gladsheim = {
    admins = [ "christoffer" ];
    ipv4 = "192.168.0.43";
    ipv6 = "fd42:36f4:199c::43";
    role = "gamehost";
    topology = "home";
  };
  yggdrasil = {
    admins = [ "christoffer" ];
    ipv4 = "192.168.0.44";
    ipv6 = "fd42:36f4:199c::44";
    role = "hypervisor";
    topology = "home";
  };
  rime = {
    admins = [ "christoffer" ];
    ipv4 = "192.168.0.51";
    ipv6 = "fd42:36f4:199c::51";
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEdKicm8ChoyAw50kgGOyYnGpRLKaGxCl2YVQ4B6mWbi rime_host_key";
    role = "workstation";
    topology = "home";
  };
}
