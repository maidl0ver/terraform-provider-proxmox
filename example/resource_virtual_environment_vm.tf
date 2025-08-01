locals {
  datastore_id = var.virtual_environment_storage
}

resource "proxmox_virtual_environment_vm" "example_template" {
  agent {
    enabled = true
  }

  bios        = "ovmf"
  description = "Managed by Terraform"

  cpu {
    cores = 2
    numa  = true
    limit = 64
    # affinity = "0-1"
  }

  smbios {
    manufacturer = "Terraform"
    product      = "Terraform Provider Proxmox"
    version      = "0.0.1"
  }

  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }

  efi_disk {
    datastore_id = local.datastore_id
    type         = "4m"
  }

  tpm_state {
    datastore_id = local.datastore_id
    version      = "v2.0"
  }

  disk {
    datastore_id = local.datastore_id
    interface    = "ide0"
    size         = 8
  }

  disk {
    datastore_id = local.datastore_id
    file_id      = proxmox_virtual_environment_download_file.latest_debian_12_bookworm_qcow2_img.id
    interface    = "scsi0"
    discard      = "on"
    cache        = "writeback"
    serial       = "dead_beef"
    ssd          = true
  }

  #  disk {
  #    datastore_id = "nfs"
  #    interface    = "scsi1"
  #    discard      = "ignore"
  #  }

  initialization {
    datastore_id = local.datastore_id
    interface    = "scsi4"

    dns {
      servers = ["1.1.1.1", "8.8.8.8"]
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
      # ipv6 {
      #    address = "dhcp"
      #}
    }

    user_data_file_id   = proxmox_virtual_environment_file.user_config.id
    vendor_data_file_id = proxmox_virtual_environment_file.vendor_config.id
    meta_data_file_id   = proxmox_virtual_environment_file.meta_config.id
  }

  machine = "q35"
  name    = "terraform-provider-proxmox-example-template"

  cdrom {
    file_id = "none"
  }

  network_device {
    mtu    = 1450
    queues = 2
  }

  network_device {
    vlan_id = 1024
  }

  node_name = data.proxmox_virtual_environment_nodes.example.names[0]

  operating_system {
    type = "l26"
  }

  pool_id = proxmox_virtual_environment_pool.example.id

  serial_device {}

  vga {
    type = "qxl"
  }

  template = true

  // use auto-generated vm_id
}

resource "proxmox_virtual_environment_vm" "example" {
  name      = "terraform-provider-proxmox-example"
  node_name = data.proxmox_virtual_environment_nodes.example.names[0]
  migrate   = true // migrate the VM on node change
  pool_id   = proxmox_virtual_environment_pool.example.id
  vm_id     = 2041
  tags      = ["terraform", "ubuntu"]

  clone {
    vm_id = proxmox_virtual_environment_vm.example_template.id
  }

  machine = "q35"

  memory {
    dedicated = 768
    # hugepages = "2"
  }

  # numa {
  #   device = "numa0"
  #   cpus   = "0-1"
  #   memory = 768
  # }

  connection {
    type        = "ssh"
    agent       = false
    host        = element(element(self.ipv4_addresses, index(self.network_interface_names, "eth0")), 0)
    private_key = tls_private_key.example.private_key_pem
    user        = "ubuntu"
  }

  provisioner "remote-exec" {
    inline = [
      "echo Welcome to $(hostname)!",
    ]
  }

  smbios {
    serial = "my-custom-serial"
  }

  efi_disk {
    datastore_id = local.datastore_id
    type         = "4m"
  }

  initialization {
    datastore_id = local.datastore_id
    // if unspecified:
    //   - autodetected if there is a cloud-init device on the template
    //   - otherwise defaults to ide2
    interface = "scsi4"

    dns {
      servers = ["1.1.1.1"]
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  #hostpci {
  #  device = "hostpci0"
  #  id = "0000:00:1f.0"
  #  pcie = true
  #}

  #hostpci {
  #  device = "hostpci1"
  #  mapping = "gpu"
  #  pcie = true
  #}

  #usb {
  #  host = "0000:1234"
  #  mapping = "usbdevice1"
  #  usb3 = false
  #}

  #usb {
  #  host = "0000:5678"
  #  mapping = "usbdevice2"
  #  usb3 = false
  #}

  # attached disks from data_vm
  dynamic "disk" {
    for_each = { for idx, val in proxmox_virtual_environment_vm.data_vm.disk : idx => val }
    iterator = data_disk
    content {
      datastore_id      = data_disk.value["datastore_id"]
      path_in_datastore = data_disk.value["path_in_datastore"]
      file_format       = data_disk.value["file_format"]
      size              = data_disk.value["size"]
      # assign from scsi1 and up
      interface = "scsi${data_disk.key + 1}"
    }
  }
}

resource "proxmox_virtual_environment_vm" "data_vm" {
  name      = "terraform-provider-proxmox-data-vm"
  node_name = data.proxmox_virtual_environment_nodes.example.names[0]
  started   = false
  on_boot   = false

  disk {
    datastore_id = local.datastore_id
    interface    = "scsi0"
    size         = 8
    import_from  = proxmox_virtual_environment_download_file.latest_debian_12_bookworm_qcow2_img.id
  }

  disk {
    datastore_id = local.datastore_id
    interface    = "scsi1"
    size         = 1
  }
  disk {
    datastore_id = local.datastore_id
    interface    = "scsi2"
    size         = 4
  }
}

resource "proxmox_virtual_environment_hardware_mapping_dir" "dir_mapping" {
  name = "terraform-provider-proxmox-dir-mapping"

  map = [{
    node = data.proxmox_virtual_environment_nodes.example.names[0]
    path = "/mnt"
  }]
}

output "resource_proxmox_virtual_environment_vm_example_id" {
  value = proxmox_virtual_environment_vm.example.id
}

output "resource_proxmox_virtual_environment_vm_example_ipv4_addresses" {
  value = proxmox_virtual_environment_vm.example.ipv4_addresses
}

output "resource_proxmox_virtual_environment_vm_example_ipv6_addresses" {
  value = proxmox_virtual_environment_vm.example.ipv6_addresses
}

output "resource_proxmox_virtual_environment_vm_example_mac_addresses" {
  value = proxmox_virtual_environment_vm.example.mac_addresses
}

output "resource_proxmox_virtual_environment_vm_example_network_interface_names" {
  value = proxmox_virtual_environment_vm.example.network_interface_names
}
