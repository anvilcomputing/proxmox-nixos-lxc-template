# flake.nix
{
  description = "A NixOS-based builder for Proxmox VE LXC containers";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs = { self, nixpkgs, deploy-rs, ... }: let
    system = "x86_64-linux";
  in {
    # Define the NixOS Configuration
    nixosConfigurations.container = nixpkgs.lib.nixosSystem {
      modules = [
        # Explicitly set the host platform to silence the 'system' stdenv warning
        { nixpkgs.hostPlatform = system; }
        ./lxc-configuration.nix
      ];
    };

    # Run `nix build .#lxc-template` to output a .tar.xz Proxmox container template
    packages.${system}.lxc-template = self.nixosConfigurations.container.config.system.build.tarball;


    # Added section so deploy-rs can target the right host
    deploy.nodes.container = {
      hostname = "192.168.101.204";  # Target for "container", but note this is a DHCP address 
      sshUser = "anvilAdmin";        # Point directly to identity, instead of relying on ssh-agent
      sshOpts = [ 
        "-i" "/home/joel/.ssh/id_ed25519_anvil_fleet_admin"
        "-o" "IdentitiesOnly=yes"
      ];
      
      profiles.system = {
        sshUser = "anvilAdmin";      # deploy-rs uses for SSH as the admin user
        user = "root";               # deploy-rs execute the activation script as root
        
        # Link the activation profile to your nixosConfiguration above
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.container;
      };
    };

    # Development shell with handy tools
    devShells.${system}.default = let
      pkgs = nixpkgs.legacyPackages.${system};
    in pkgs.mkShell {
      buildInputs = with pkgs; [
        git
        nix-prefetch-git
      ];
    };
  };
}
