{
  description = "NixOS for my homelab and workstation";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

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
    streamserver = {
      url = "github:HoppenR/streamserver";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    streamshower = {
      url = "github:HoppenR/streamshower";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };
  outputs =
    { nixpkgs, ... }@inputs:
    let
      identities = import ./identities.nix;
      inventory = import ./inventory.nix;
      system = "x86_64-linux";
      topology = import ./topology.nix;
      specialArgs = {
        inherit
          identities
          inputs
          inventory
          system
          topology
          ;
      };
    in
    {
      nixosConfigurations = {
        bifrost = nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [ ./hosts/bifrost ];
        };

        hoddmimir = nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [ ./hosts/hoddmimir ];
        };

        rime = nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [ ./hosts/rime ];
        };

        skadi = nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          modules = [ ./hosts/skadi ];
        };
      };
    };
}
