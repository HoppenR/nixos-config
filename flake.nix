{
  description = "NixOS for my homelab and workstation";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # run0-sudo-shim = {
    #   url = "github:lordgrimmauld/run0-sudo-shim";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };
  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      topology = import ./topology.nix;
      specialArgs = { inherit inputs system topology; };
    in
    {
      nixosConfigurations = {
        skadi = nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [ ./hosts/skadi ];
        };

        hoddmimir = nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [ ./hosts/hoddmimir ];
        };

        rime = nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [ ./hosts/rime ];
        };
      };
    };
}
