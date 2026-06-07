# lxc-configuration.nix
{ modulesPath, pkgs, lib, ... }: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  # Basic LXC container flags
  boot.isContainer = true;
  
  # Mandatory for future remote flake operations
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Suppress systemd units that fail inside unprivileged LXC environments
  systemd.suppressedSystemUnits = [
    "dev-mqueue.mount"
    "sys-kernel-debug.mount"
    "sys-fs-fuse-connections.mount"
  ];

  # Automatically hardlink identical files in the Nix store to save disk space
  nix.settings.auto-optimise-store = true;

  # Run garbage collection weekly to delete old generations
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Basic configuration
  networking.hostName = lib.mkDefault "nixos-based-template";
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "America/New_York";
  system.stateVersion = "25.05"; # Match your targets

  # Pre-install essential tooling
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    htop
    wget
    iproute2     # For 'ip a' and 'ip route'
    dnsutils     # For `dig` and `nslookup` (crucial for diagnosing bad DNS)
    tmux         # So you don't lose your session if you SSH in to fix something
    fd           # A much faster, user-friendly alternative to `find`
    ripgrep      # A much faster alternative to `grep`
  ];

  # Enable Tailscale
  services.tailscale = {
    enable = true;
    interfaceName = "userspace-networking"; # Bypasses the need for host TUN permissions
  };

  # Network Settings
  networking.firewall = {
    enable = true;
    checkReversePath = "loose";           # Prevents reverse path filters blocking Exit Node traffic
    trustedInterfaces = [ "tailscale0" ]; # Always allow traffic from Tailscale interface  
    allowedUDPPorts = [ 41641 ];          # Allow default Tailscale UDP port through firewall
  };

  # User Settings
  security.sudo.wheelNeedsPassword = false;
  users.users.anvilAdmin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Grants sudo access
    # Put your anvil_fleet_admin public key here:
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII5Z5l8JiaFfAEnlp8E/Ua7e5BWe8lZvodkXcRBmZahc"
    ];
  };

  # SSH Settings
  #  Disallow root login, as Anvil Admin user will perform actions via sudo/root as needed
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Allow Anvil Admins to push configs to the Nix store
  nix.settings.trusted-users = [ "root" "anvilAdmin" ];

}
