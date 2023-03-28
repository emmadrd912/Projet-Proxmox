provider "proxmox" {
  pm_tls_insecure = true
  /*
    // Credentials here or environment
    pm_api_url = "https://192.168.1.34:8006/api2/json"
    pm_password = "password"
    pm_user = "root@pam"
    //Optional
    pm_otp = "otpcode"
  */
}

resource "proxmox_vm_qemu" "cloudinit-test" {
  name = "terraform-cloud-init"
  desc = "test de terraform avec cloud-init"
  target_node = "pve"

  clone = "Template-Centos"

  # The destination resource pool for the new VM

  storage = "local-lvm"
  cores = 2
  sockets = 1
  memory = 1024
  nic = "virtio"
  bridge = "vmbr0"

  ssh_user = "root"
  ssh_private_key = <<EOF
-----BEGIN RSA PRIVATE KEY-----
private ssh key root
-----END RSA PRIVATE KEY-----
EOF

  os_type = "cloud-init"
  os_network_config = <<EOF
auto eth0
iface eth0 inet dhcp
EOF

  sshkeys = <<EOF
EOF

  provisioner "remote-exec" {
   inline = [
     "ip a"
   ]
 }

}

resource "proxmox_vm_qemu" "cloudinit-test2" {
  name = "terraform-cloud-init2"
  desc = "test de terraform avec cloud-init avec 2 vm"
  target_node = "pve"

  clone = "Template-Centos"

  # The destination resource pool for the new VM

  storage = "local-lvm"
  cores = 2
  sockets = 1
  memory = 1024
  nic = "virtio"
  bridge = "vmbr0"

  ssh_user = "root"
  ssh_private_key = <<EOF
-----BEGIN RSA PRIVATE KEY-----
private ssh key root
-----END RSA PRIVATE KEY-----
EOF

  os_type = "cloud-init"
  os_network_config = <<EOF
auto eth0
iface eth0 inet dhcp
EOF

  sshkeys = <<EOF
EOF

  provisioner "remote-exec" {
   inline = [
     "ip a"
   ]
 }

}
