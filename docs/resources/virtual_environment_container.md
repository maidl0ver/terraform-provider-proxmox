---
layout: page
title: proxmox_virtual_environment_container
parent: Resources
subcategory: Virtual Environment
---

# Resource: proxmox_virtual_environment_container

Manages a container.

## Example Usage

```hcl
resource "proxmox_virtual_environment_container" "ubuntu_container" {
  description = "Managed by Terraform"

  node_name = "first-node"
  vm_id     = 1234

  initialization {
    hostname = "terraform-provider-proxmox-ubuntu-container"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      keys = [
        trimspace(tls_private_key.ubuntu_container_key.public_key_openssh)
      ]
      password = random_password.ubuntu_container_password.result
    }
  }

  network_interface {
    name = "veth0"
  }

  disk {
    datastore_id = "local-lvm"
    size         = 4
  }
  
  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.latest_ubuntu_22_jammy_lxc_img.id
    # Or you can use a volume ID, as obtained from a "pvesm list <storage>"
    # template_file_id = "local:vztmpl/jammy-server-cloudimg-amd64.tar.gz"
    type             = "ubuntu"
  }

  mount_point {
    # bind mount, *requires* root@pam authentication
    volume = "/mnt/bindmounts/shared"
    path   = "/mnt/shared"
  }

  mount_point {
    # volume mount, a new volume will be created by PVE
    volume = "local-lvm"
    size   = "10G"
    path   = "/mnt/volume"
  }

  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }
}

resource "proxmox_virtual_environment_download_file" "latest_ubuntu_22_jammy_lxc_img" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "first-node"
  url          = "http://download.proxmox.com/images/system/ubuntu-20.04-standard_20.04-1_amd64.tar.gz"
}

resource "random_password" "ubuntu_container_password" {
  length           = 16
  override_special = "_%@"
  special          = true
}

resource "tls_private_key" "ubuntu_container_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

output "ubuntu_container_password" {
  value     = random_password.ubuntu_container_password.result
  sensitive = true
}

output "ubuntu_container_private_key" {
  value     = tls_private_key.ubuntu_container_key.private_key_pem
  sensitive = true
}

output "ubuntu_container_public_key" {
  value = tls_private_key.ubuntu_container_key.public_key_openssh
}
```

## Argument Reference

- `clone` - (Optional) The cloning configuration.
    - `datastore_id` - (Optional) The identifier for the target datastore.
    - `node_name` - (Optional) The name of the source node (leave blank, if
        equal to the `node_name` argument).
    - `vm_id` - (Required) The identifier for the source container.
- `console` - (Optional) The console configuration.
    - `enabled` - (Optional) Whether to enable the console device (defaults
        to `true`).
    - `type` - (Optional) The console mode (defaults to `tty`).
        - `console` - Console.
        - `shell` - Shell.
        - `tty` - TTY.
    - `tty_count` - (Optional) The number of available TTY (defaults to `2`).
- `cpu` - (Optional) The CPU configuration.
    - `architecture` - (Optional) The CPU architecture (defaults to `amd64`).
        - `amd64` - x86 (64 bit).
        - `arm64` - ARM (64-bit).
        - `armhf` - ARM (32 bit).
        - `i386` - x86 (32 bit).
    - `cores` - (Optional) The number of CPU cores (defaults to `1`).
    - `units` - (Optional) The CPU units (defaults to `1024`).
- `description` - (Optional) The description.
- `disk` - (Optional) The disk configuration.
    - `datastore_id` - (Optional) The identifier for the datastore to create the
        disk in (defaults to `local`).
    - `size` - (Optional) The size of the root filesystem in gigabytes (defaults
        to `4`). When set to 0 a directory or zfs/btrfs subvolume will be created.
        Requires `datastore_id` to be set.
    - `mount_options` (Optional) List of extra mount options.
- `initialization` - (Optional) The initialization configuration.
    - `dns` - (Optional) The DNS configuration.
        - `domain` - (Optional) The DNS search domain.
        - `server` - (Optional) The DNS server. The `server` attribute is
            deprecated and will be removed in a future release. Please use
            the `servers` attribute instead.
        - `servers` - (Optional) The list of DNS servers.
    - `hostname` - (Optional) The hostname.
    - `ip_config` - (Optional) The IP configuration (one block per network
        device).
        - `ipv4` - (Optional) The IPv4 configuration.
            - `address` - (Optional) The IPv4 address (use `dhcp` for auto-discovery).
            - `gateway` - (Optional) The IPv4 gateway (must be omitted
                when `dhcp` is used as the address).
        - `ipv6` - (Optional) The IPv4 configuration.
            - `address` - (Optional) The IPv6 address (use `dhcp` for auto-discovery).
            - `gateway` - (Optional) The IPv6 gateway (must be omitted
                when `dhcp` is used as the address).
    - `user_account` - (Optional) The user account configuration.
        - `keys` - (Optional) The SSH keys for the root account.
        - `password` - (Optional) The password for the root account.
- `memory` - (Optional) The memory configuration.
    - `dedicated` - (Optional) The dedicated memory in megabytes (defaults
        to `512`).
    - `swap` - (Optional) The swap size in megabytes (defaults to `0`).
- `mount_point`
    - `acl` (Optional) Explicitly enable or disable ACL support.
    - `backup` (Optional) Whether to include the mount point in backups (only
        used for volume mount points, defaults to `false`).
    - `mount_options` (Optional) List of extra mount options.
    - `path` (Required) Path to the mount point as seen from inside the
        container.
    - `quota` (Optional) Enable user quotas inside the container (not supported
        with ZFS subvolumes).
    - `read_only` (Optional) Read-only mount point.
    - `replicate` (Optional) Will include this volume to a storage replica job.
    - `shared` (Optional) Mark this non-volume mount point as available on all
        nodes.
    - `size` (Optional) Volume size (only for volume mount points).
        Can be specified with a unit suffix (e.g. `10G`).
    - `volume` (Required) Volume, device or directory to mount into the
        container.
- `device_passthrough` - (Optional) Device to pass through to the container (multiple blocks supported).
    - `deny_write` - (Optional) Deny the container to write to the device (defaults to `false`).
    - `gid` - (Optional) Group ID to be assigned to the device node.
    - `mode` - (Optional) Access mode to be set on the device node. Must be a
        4-digit octal number.
    - `path` - (Required) Device to pass through to the container (e.g. `/dev/sda`).
    - `uid` - (Optional) User ID to be assigned to the device node.
- `network_interface` - (Optional) A network interface (multiple blocks
    supported).
    - `bridge` - (Optional) The name of the network bridge (defaults
        to `vmbr0`).
    - `enabled` - (Optional) Whether to enable the network device (defaults
        to `true`).
    - `firewall` - (Optional) Whether this interface's firewall rules should be
        used (defaults to `false`).
    - `mac_address` - (Optional) The MAC address.
    - `mtu` - (Optional) Maximum transfer unit of the interface. Cannot be
        larger than the bridge's MTU.
    - `name` - (Required) The network interface name.
    - `rate_limit` - (Optional) The rate limit in megabytes per second.
    - `vlan_id` - (Optional) The VLAN identifier.
- `node_name` - (Required) The name of the node to assign the container to.
- `operating_system` - (Required) The Operating System configuration.
    - `template_file_id` - (Required) The identifier for an OS template file.
       The ID format is `<datastore_id>:<content_type>/<file_name>`, for example `local:iso/jammy-server-cloudimg-amd64.tar.gz`.
       Can be also taken from `proxmox_virtual_environment_download_file` resource, or from the output of `pvesm list <storage>`.
    - `type` - (Optional) The type (defaults to `unmanaged`).
        - `alpine` - Alpine.
        - `archlinux` - Arch Linux.
        - `centos` - CentOS.
        - `debian` - Debian.
        - `devuan` - Devuan.
        - `fedora` - Fedora.
        - `gentoo` - Gentoo.
        - `nixos` - NixOS.
        - `opensuse` - openSUSE.
        - `ubuntu` - Ubuntu.
        - `unmanaged` - Unmanaged.
- `pool_id` - (Optional) The identifier for a pool to assign the container to.
- `protection` - (Optional) Whether to set the protection flag of the container (defaults to `false`). This will prevent the container itself and its disk for remove/update operations.
- `started` - (Optional) Whether to start the container (defaults to `true`).
- `startup` - (Optional) Defines startup and shutdown behavior of the container.
    - `order` - (Required) A non-negative number defining the general startup
        order.
    - `up_delay` - (Optional) A non-negative number defining the delay in
        seconds before the next container is started.
    - `down_delay` - (Optional) A non-negative number defining the delay in
        seconds before the next container is shut down.
- `start_on_boot` - (Optional) Automatically start container when the host
  system boots (defaults to `true`).
- `tags` - (Optional) A list of tags the container tags. This is only meta
  information (defaults to `[]`). Note: Proxmox always sorts the container tags and set them to lowercase.
  If tag contains capital letters, then Proxmox will always report a
  difference on the resource. You may use the `ignore_changes` lifecycle
  meta-argument to ignore changes to this attribute.
- `template` - (Optional) Whether to create a template (defaults to `false`).
- `timeout_create` - (Optional) Timeout for creating a container in seconds (defaults to 1800).
- `timeout_clone` - (Optional) Timeout for cloning a container in seconds (defaults to 1800).
- `timeout_delete` - (Optional) Timeout for deleting a container in seconds (defaults to 60).
- `timeout_update` - (Optional) Timeout for updating a container in seconds (defaults to 1800).
- `unprivileged` - (Optional) Whether the container runs as unprivileged on the host (defaults to `false`).
- `vm_id` - (Optional) The container identifier
- `features` - (Optional) The container feature flags. Changing flags (except nesting) is only allowed for `root@pam` authenticated user.
    - `nesting` - (Optional) Whether the container is nested (defaults to `false`)
    - `fuse` - (Optional) Whether the container supports FUSE mounts (defaults to `false`)
    - `keyctl` - (Optional) Whether the container supports `keyctl()` system call (defaults to `false`)
    - `mount` - (Optional) List of allowed mount types (`cifs` or `nfs`)
- `hook_script_file_id` - (Optional) The identifier for a file containing a hook script (needs to be executable, e.g. by using the `proxmox_virtual_environment_file.file_mode` attribute).

## Attribute Reference

- `ipv4` - The map of IPv4 addresses per network devices. Returns the first address for each network device, if multiple addresses are assigned.
- `ipv6` - The map of IPv6 addresses per network device. Returns the first address for each network device, if multiple addresses are assigned.

## Import

Instances can be imported using the `node_name` and the `vm_id`, e.g.,

```bash
terraform import proxmox_virtual_environment_container.ubuntu_container first-node/1234
```
