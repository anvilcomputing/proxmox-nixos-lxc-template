`# 🚀 Proxmox NixOS LXC Template & Fleet Builder`

`A declarative, highly secure, and reproducible NixOS template specifically tailored for unprivileged Proxmox VE LXC containers.` 

``This repository leverages Nix Flakes and `deploy-rs` to manage container configurations remotely. It is built with a strict "no direct root login" security model and integrates Tailscale for seamless fleet networking.``

`## ✨ Core Features & Architecture`

``* **Unprivileged LXC Optimized:** Specifically suppresses systemd units that typically fail in unprivileged Proxmox LXC environments (e.g., `dev-mqueue.mount`, `sys-kernel-debug.mount`).``  
``* **Sudoless Remote Deployment:** Utilizes `deploy-rs` to push configurations over SSH as a standard user (`anvilAdmin`), and automatically elevates via passwordless sudo to activate the system profile. Direct `root` SSH access is completely disabled.``  
`* **Tailscale Userspace Networking:** Bypasses the need for complex kernel-level TUN device passthrough on the Proxmox host by routing Tailscale traffic through userspace. Firewall rules are pre-configured to prevent reverse-path filtering from blocking exit nodes.`  
``* **Self-Maintaining:** Pre-configured with `auto-optimise-store` to hardlink identical files and a weekly automated garbage collection timer to keep container disk usage minimal.``  
`* **Essential Tooling:** Batteries included (git, vim, curl, htop, tmux, fd, ripgrep, dnsutils, iproute2).`

`---`

`## 🛠️ Prerequisites`

`Before deploying, ensure you have the following on your local deployment machine:`  
``* Nix installed with `flakes` and `nix-command` enabled.``  
``* An SSH keypair generated for your admin user (e.g., `~/.ssh/id_ed25519_anvil_fleet_admin`).``  
`* A running Proxmox LXC container booted from a base NixOS rootfs tarball.`

`---`

`## 🚀 Bootstrap & Initial Deployment`

``*Note: NixOS has a strict security model. To allow our non-root user (`anvilAdmin`) to push configurations to the Nix store, we must first tell the Nix daemon to trust them. This requires a one-time "Bootstrap" deployment as `root`.*``

`### Step 1: The Root Bootstrap`  
``1. In `flake.nix`, temporarily set the SSH users to `root`:``  
   ```` ```nix ````  
   `deploy.nodes.container = {`  
     `sshUser = "root"; # Temporarily root`  
     `profiles.system = {`  
       `sshUser = "root"; # Temporarily root`  
       `user = "root";`  
       `# ...`  
     `};`  
   `};`

2. Run the deployment:  
   `nix run github:serokell/deploy-rs -- .#container`

3. This initial run applies lxc-configuration.nix, which disables root SSH logins, creates the anvilAdmin user, sets up passwordless sudo, and adds anvilAdmin to nix.settings.trusted-users.

### **Step 2: Switch to Standard Deployment**

1. Revert flake.nix back to the secure deployment model:  
   `deploy.nodes.container = {`  
     `sshUser = "anvilAdmin";`  
     `profiles.system = {`  
       `sshUser = "anvilAdmin";`  
       `user = "root"; # deploy-rs will use sudo to elevate`  
       `# ...`  
     `};`  
   `};`

2. Future deployments can now be run safely without ever logging in directly as root\!

## ---

**🏗️ Building a New Proxmox Template Tarball**

If you want to generate a fresh .tar.xz template to upload to your Proxmox ISO datastore for spinning up new GUI containers:  
`nix build .#lxc-template`

The resulting tarball will be dropped into a result/ symlink in this directory. Upload this to Proxmox and use it to create new containers.

## ---

**🌐 Tailscale Configuration Notes**

Tailscale is enabled out of the box using userspace-networking.  
**Firewall Allowances Included:**

* UDP Port 41641 allowed.  
* tailscale0 added to trustedInterfaces.  
* networking.firewall.checkReversePath \= "loose"; to allow exit nodes to route properly.

*(Stub: Add documentation here later on how to auto-auth Tailscale using an ephemeral auth-key or sops-nix secrets).*

## ---

**🔍 Diagnostics & Cheatsheet**

### **Checking NixOS Garbage Collection Stats**

If you want to see what is consuming space or what *would* be deleted during a GC run:  
`# Dry run to see what is dead and how much space would be freed`  
`nix-store --gc --print-dead`

`# Check the status of the automated weekly GC timer`  
`systemctl status nix-gc.timer`  
`journalctl -u nix-gc.service`

### **Checking Store Optimization**

To verify that auto-optimise-store is actively configured:  
`nix config show auto-optimise-store`  
`# or`  
`nixos-option nix.settings.auto-optimise-store`

## ---

**📝 Future Road Map (Stubs)**

* **Secrets Management:** Integrate sops-nix or agenix to handle Tailscale auth keys, passwords, and API tokens securely.  
* **Multi-Node Fleet:** Refactor flake.nix to iterate over a list of hostnames/IPs to deploy to multiple LXC containers simultaneously.  
* **Modularization:** Break lxc-configuration.nix into smaller, reusable modules (e.g., modules/tailscale.nix, modules/users.nix).  
* **CI/CD:** Setup GitHub Actions to automatically run nix flake check on pull requests.

---

*Maintained by [Joel](mailto:joel@anvilcomputing.com) @ Anvil Computing*
