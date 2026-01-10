# 03 - Migration Plan

## Migration Plan: HP 1910-24G Switch & Thor Proxmox Migration

**Target Date:** 31 January - 1 February 2026
**Location:** Colo Prague (On-Site)
**Estimated Downtime:** 2-4 hours
**Rollback Window:** Available (Dell Switch remains on-site)

* * *

## Executive Summary

This document describes the complete migration from the current infrastructure (Dell PowerConnect 2824, Thor bare-metal pfSense) to the target architecture (HP 1910-24G with LACP, Thor Proxmox with pfSense VM, Loki LACP bond).

**Critical Changes:**

* ✅ HP Switch installation (LACP-capable)
* ✅ Thor: Bare-Metal pfSense → Proxmox + pfSense VM
* ✅ Loki: Single Link → LACP Bond (4x 1 GbE)
* ✅ VLAN Segmentation (10/20/30)
* ✅ NIC Passthrough (Intel 82571EB eno0-1 → pfSense VM)
* ✅ WireGuard OOB gateway LXC

**Rollback Strategy:** Dell Switch remains on-site; complete rollback possible within 30 minutes.

* * *

## Pre-Migration Checklist

### One Week Before (24 January 2026)

- [ ] **Create backups:**
  - [ ] pfSense config.xml export (`Diagnostics → Backup & Restore`)
  - [ ] Proxmox VMs/LXCs backup (manual or PBS)
  - [ ] TrueNAS config export
  - [ ] Secure `/etc/network/interfaces` from Loki

- [ ] **Prepare hardware:**
  - [ ] Validate HP 1910-24G Switch Config (via Serial Console)
  - [ ] Label all cables (bring Label Maker on-site)
  - [ ] Prepare USB stick with ISOs:
    * Proxmox VE 8.4.14 ISO
    * pfSense 2.8.1 ISO (if the VM needs to be recreated)

- [ ] **Print documentation:**
  - [ ] This migration document (A4, double-sided)
  - [ ] Switch Port Mapping (Target State)
  - [ ] IP Address Table (VLAN 10/20/30)
  - [ ] Rollback Procedure (separate page, marked in red)

- [ ] **Test remote access:**
  - [ ] Colo VPN reachable (172.20.10.x)
  - [ ] iLO Thor/Loki functional (77.77.77.2-3)
  - [ ] Test Serial Console cable for HP Switch

### The Day Before (30 January 2026)

- [ ] **Announce maintenance window:**
  - [ ] Inform Pterodactyl Game Server users (4h downtime)
  - [ ] Inform Plex users (WhatsApp group)
  - [ ] Nextcloud downtime (if relevant)

- [ ] **Final backups:**
  - [ ] pfSense config.xml (fresh export)
  - [ ] Proxmox cluster config
  - [ ] Current VM list screenshot (`qm list`)

- [ ] **Pack toolbox:**
  - [ ] Laptop + Power Adapter
  - [ ] USB-to-Serial cable (HP Switch Console)
  - [ ] RJ45 Ethernet cables (min. 10x, various lengths)
  - [ ] Label Maker + Tape
  - [ ] Notepad + Pen (for MAC addresses, if necessary)
  - [ ] USB stick with ISOs

### On-Site Check (31 January, 09:00)

- [ ] **Physical Access:**
  - [ ] Rack accessible
  - [ ] Dell Switch visible/reachable
  - [ ] All servers physically present

- [ ] **Check connections:**
  - [ ] Laptop → Dell Switch Port 24 (VLAN 69)
  - [ ] Serial Console → HP Switch (COM Port detected)
  - [ ] iLO Access: [https://77.77.77.2](https://77.77.77.2) (Thor), [https://77.77.77.3](https://77.77.77.3) (Loki)

- [ ] **GO/NO-GO Decision:**
  - [ ] All backups available?
  - [ ] All hardware on-site?
  - [ ] Rollback strategy understood?

* * *

## Phase 1: HP Switch Installation (45 minutes)

**Time window:** 10:00 - 10:45
**Risk:** Medium (Network Outage during Switch swap)

### 1.1 Document Dell Switch Port Mapping

```sh
# Before disconnecting: Photograph current cabling
# Attach labels to each cable:
# - "Thor em0 → Port 23"
# - "Loki eno1 → Port 1"
# - "Thor iLO → Port 17"
# - "Loki iLO → Port 18"
# - "Laptop → Port 24"
```

### 1.2 Controlled Shutdown

**On Loki Proxmox (via SSH 10.0.1.10):**

```sh
# Shut down all VMs/LXCs cleanly
qm list  # Check list once more
for vmid in 1000 1100 2000 4000 8000; do
    echo "Shutting down VM $vmid..."
    qm shutdown $vmid --timeout 120
done

# Shut down LXCs
for ctid in 3000 3002 5000 5001 5050 6000 6100 9000; do
    echo "Shutting down CT $ctid..."
    pct shutdown $ctid --timeout 60
done

# Shut down Proxmox host (possible via iLO Virtual Power Button)
shutdown -h now
```

**On Thor pfSense (via WebGUI):**

```
Diagnostics → Halt System → Confirm
```

**Physical verification (via iLO Remote Console):**

- [ ] Loki completely shut down (no POST messages)
- [ ] Thor completely shut down

### 1.3 Physically install HP Switch

```sh
# Remove Dell Switch cables (ordered, one after another):
1. Remove Laptop cable (Port 24)
2. Remove iLO cables (Port 17, 18)
3. Remove Thor em0 (Port 23)
4. Remove Loki eno1 (Port 1)

# Remove Dell Switch, set aside (do NOT remove from rack)

# Install HP Switch:
1. Mount HP 1910-24G in Rack
2. Connect power cable (wait until Boot is completed)
3. Connect Serial Console (Laptop COM Port)
```

### 1.4 Validate HP Switch Base Configuration

**Via Serial Console (PuTTY: 38400 8N1):**

```sh
<HP> display current-configuration

# Check expected output:
# - VLAN 10/20/30 exist
# - bridge-Aggregation1 (Ports 1-2)
# - bridge-Aggregation2 (Ports 9-12)
# - Vlan-interface10 IP: 10.0.10.2
```

**If Config is missing or incorrect:**

```sh
<HP> system-view
[HP] vlan 10
[HP-vlan10] description Management
[HP-vlan10] quit
[HP] vlan 20
[HP-vlan20] description Production
[HP-vlan20] quit
[HP] vlan 30
[HP-vlan30] description Compute
[HP-vlan30] quit

# Set Management IP
[HP] interface Vlan-interface10
[HP-Vlan-interface10] ip address 10.0.10.2 255.255.255.0
[HP-Vlan-interface10] quit

# Save Config
[HP] save
The current configuration will be written to the device. Are you sure? [Y/N]:y
```

### 1.5 Initial Cabling (Management Only)

```sh
# Connect only critical links:
HP Port 17 → Thor iLO (untagged VLAN 10 - will be migrated later)
HP Port 18 → Loki iLO (untagged VLAN 10 - will be migrated later)
HP Port 24 → Laptop (Access VLAN 10 for Management)
```

**Configure Port 24:**

```sh
<HP> system-view
[HP] interface GigabitEthernet1/0/24
[HP-GigabitEthernet1/0/24] port access vlan 10
[HP-GigabitEthernet1/0/24] quit
[HP] quit
<HP> save
```

**Set Laptop IP (static):**

```
IP: 10.0.10.99/24
Gateway: (leave empty)
```

**Test HP Switch Management:**

```sh
# From laptop:
ping 10.0.10.2
# Expected response: < 1ms

# HTTP GUI:
http://10.0.10.2
# Login: admin / (default PW)
```

**CHECKPOINT 1:** HP Switch reachable, Management works.

* * *

## Phase 2: Thor - Proxmox Installation (60 minutes)

**Time window:** 10:45 - 11:45
**Risk:** High (Data Loss on ZFS Pool, complete pfSense rebuild)

### 2.1 Proxmox VE 8.4.14 Installation

**Via iLO Remote Console ([https://77.77.77.2](https://77.77.77.2)):**

```
1. iLO Virtual Media → Mount ISO (Proxmox VE 8.4.14)
2. Boot Order → CD/DVD First
3. Power On → Start installation

Proxmox Installation:
- Agree to EULA
- Target Harddisk: /dev/sda (Patriot P210 128GB)
- Filesystem: ZFS (RAID1)
  - Select Disks: /dev/sda, /dev/sdb (BOTH SSDs)
  - ashift: 12 (Default)
  - compress: lz4
  - checksum: on
  - copies: 1

- Country: Germany
- Timezone: Europe/Berlin
- Keyboard: de

- Admin password: [Use secure password]
- Email: [Admin-Email]

- Management interface: eno2 (Broadcom BCM5720 - Onboard NIC)
  IMPORTANT: Do NOT choose bge0 or bge1 (they will be used for pfSense)

- Hostname (FQDN): pve-prod-cz-thor.getinn.top
- IP: 10.0.10.5/24
- Gateway: 10.0.10.1 (will be the pfSense VM)
- DNS: 1.1.1.1 (temporary)

Perform installation → Reboot
```

**After installation:**

```sh
# Login via iLO Virtual Console:
# Username: root
# Password: [as set above]

# Check network:
ip addr show eno2
# Expected output: 10.0.10.5/24

ping 10.0.10.2  # HP Switch Management
# Expected response: < 1ms

# STILL NOT REACHABLE from outside (no gateway/routing)
```

### 2.2 Activate IOMMU (VT-d)

**Goal:** PCI Passthrough for Intel 82571EB NICs to pfSense VM.

**Edit GRUB Configuration:**

```sh
nano /etc/default/grub

# Find line:
GRUB_CMDLINE_LINUX_DEFAULT="quiet"

# Change to:
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

**Update GRUB & Load Modules:**

```sh
# Generate new GRUB
update-grub

# Activate VFIO modules
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules
echo "vfio_virqfd" >> /etc/modules

# Load modules immediately (without reboot)
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio_pci
modprobe vfio_virqfd

# Check IOMMU Interrupt Remapping
dmesg | grep -e IOMMU -e DMAR
# Expected output: "DMAR: Intel(R) Virtualization Technology for Directed I/O"
```

**System Restart:**

```sh
reboot
```

**After reboot - Verify IOMMU:**

```sh
# Display IOMMU Groups
pvesh get /nodes/pve-prod-cz-thor/hardware/pci --pci-class-blacklist ""

# Alternative: Manual check
dmesg | grep -i iommu
# Expected output: "IOMMU enabled"

find /sys/kernel/iommu_groups/ -type l
# Should display IOMMU Groups
```

### 2.3 Identify Intel 82571EB NICs

```sh
# Display all PCI Devices
lspci -nn | grep -i ethernet

# Expected output (similar):
# 09:00.0 Ethernet controller [0200]: Intel Corporation 82571EB Gigabit Ethernet Controller [8086:105e] (rev 06)
# 09:00.1 Ethernet controller [0200]: Intel Corporation 82571EB Gigabit Ethernet Controller [8086:105e] (rev 06)
# 0a:00.0 Ethernet controller [0200]: Intel Corporation 82571EB Gigabit Ethernet Controller [8086:105e] (rev 06)
# 0a:00.1 Ethernet controller [0200]: Intel Corporation 82571EB Gigabit Ethernet Controller [8086:105e] (rev 06)

# Note PCIe Addresses:
# eno0: 0000:09:00.0 (WAN)
# eno1: 0000:09:00.1 (LACP Member for Proxmox - RESERVED)
# eno2: 0000:0a:00.0 (LACP Member for Proxmox - RESERVED)
# eno3: 0000:0a:00.1 (LACP Member for Proxmox - RESERVED)
```

**IMPORTANT:** Only `eno0` (0000:09:00.0) will be passed through to the pfSense VM. eno1-3 remain for Proxmox LACP.

### 2.4 Prepare PCI Device for Passthrough

```sh
# Determine Vendor/Device ID
lspci -n -s 09:00.0
# Output: 09:00.0 0200: 8086:105e (rev 06)
# → Vendor ID: 8086, Device ID: 105e

# VFIO binding for this device
echo "options vfio-pci ids=8086:105e" > /etc/modprobe.d/vfio.conf

# Module Blacklist (prevents Linux driver binding)
echo "blacklist e1000e" >> /etc/modprobe.d/blacklist.conf

# Generate new initramfs
update-initramfs -u -k all

# System Restart (critical!)
reboot
```

**After reboot - Verify Passthrough:**

```sh
# Device should now use the VFIO driver:
lspci -k -s 09:00.0

# Expected output:
# 09:00.0 Ethernet controller: Intel Corporation 82571EB
#     Kernel driver in use: vfio-pci
#     Kernel modules: e1000e

# If "e1000e" is under "Kernel driver in use" → Error!
```

**CHECKPOINT 2:** Proxmox runs, IOMMU active, NIC ready for Passthrough.

* * *

## Phase 3: Network Bridge Configuration (15 minutes)

**Time window:** 11:45 - 12:00

### 3.1 Edit `/etc/network/interfaces`

**Secure current state:**

```sh
cp /etc/network/interfaces /root/interfaces.backup.$(date +%s)
```

**Write new configuration:**

```sh
nano /etc/network/interfaces
```

**Complete Configuration:**

```sh
# Loopback
auto lo
iface lo inet loopback

# WAN NIC (for pfSense VM - will be used via Passthrough)
# NO "auto eno0" - will not be used by the Host

# Management NIC (Proxmox Host)
auto eno2
iface eno2 inet manual

auto vmbr_mgmt
iface vmbr_mgmt inet static
    address 10.0.10.5/24
    gateway 10.0.10.1
    bridge-ports eno2
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 10
    # Management bridge - VLAN 10 only

# Colo VPN NIC (isolated for WireGuard OOB gateway LXC)
auto bge1
iface bge1 inet manual

auto vmbr_oob
iface vmbr_oob inet static
    address 172.20.10.10/24
    bridge-ports bge1
    bridge-stp off
    bridge-fd 0
    # Colo VPN - Isolated for WireGuard OOB gateway

# VLAN-Aware bridge (for LXCs without dedicated NICs)
auto vmbr0
iface vmbr0 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 10 20 30
    # VLAN bridge for LXCs - VLANs 10/20/30
```

**Restart network:**

```sh
# ATTENTION: iLO Remote Console MUST stay open!
# Risk: Lost network connection

systemctl restart networking

# Alternative safer way:
ifreload -a
```

**Verification:**

```sh
ip addr show vmbr_mgmt
# Expected output: 10.0.10.5/24

ip addr show vmbr_oob
# Expected output: 172.20.10.10/24

brctl show
# Expected output: vmbr_mgmt (eno2), vmbr_oob (bge1), vmbr0 (none)

ping 10.0.10.2  # HP Switch
# STILL NO gateway: Ping will fail (normal)
```

**CHECKPOINT 3:** All bridges configured.

* * *

## Phase 4: pfSense VM Creation (45 minutes)

**Time window:** 12:00 - 12:45

### 4.1 Create VM via Proxmox WebGUI

**Open Proxmox WebGUI:**

Since no routing is active yet, the WebGUI must be accessed via **Laptop** (directly on Switch Port 24):

```
URL: https://10.0.10.5:8006
Login: root / [Proxmox PW]
```

**VM Creation Wizard:**

```
General:
- Node: pve-prod-cz-thor
- VM ID: 100
- Name: fw-prod-cz-thor

OS:
- ISO image: [pfSense-CE-2.8.1-RELEASE-amd64.iso upload via iLO or USB]
- Type: Other
- Guest OS: FreeBSD
- Version: 14.x (or latest)

System:
- BIOS: OVMF (UEFI)
- Machine: q35
- SCSI Controller: VirtIO SCSI single
- Qemu Agent: ✅ (activate)
- Add EFI Disk: ✅ (Storage: local-zfs, Pre-Enroll keys: NO)

Disks:
- Bus/Device: VirtIO Block (0)
- Storage: local-zfs
- Disk size: 32 GB (sufficient for pfSense)
- Cache: Write back
- Discard: ✅
- SSD emulation: ✅

CPU:
- Sockets: 1
- Cores: 4 (E3-1230L has 4C/8T, 4 Cores are sufficient)
- Type: host (important for Performance)

Memory:
- Memory (MiB): 4096 (4 GB - sufficient for pfSense with packages)
- Ballooning: ❌ (deactivate)

Network:
- Bridge: vmbr_mgmt
- Model: VirtIO (paravirt)
- VLAN Tag: (empty)
- Firewall: ❌ (deactivate)
- Note: This will be the LAN interface (later em0 in pfSense)

Confirm: ✅ Create VM (but NOT start!)
```

### 4.2 Add PCI Passthrough (Intel eno0 for WAN)

**Via WebGUI:**

```
VM 100 (fw-prod-cz-thor) → Hardware → Add → PCI Device:
- Raw Device: 0000:09:00.0 (Intel 82571EB - eno0)
- All Functions: ❌ (only this function)
- Primary GPU: ❌
- ROM-Bar: ✅
- PCI-Express: ✅ (if available)

→ Add
```

**Alternative: Via CLI (if GUI not working):**

```sh
qm set 100 -hostpci0 0000:09:00.0,pcie=1
```

**Check VM Config:**

```sh
cat /etc/pve/qemu-server/100.conf

# Expected output (similar):
# hostpci0: 0000:09:00.0,pcie=1
# net0: virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr_mgmt
```

### 4.3 pfSense Installation

**Start VM:**

```sh
qm start 100
```

**Via Proxmox Console (NoVNC):**

```
VM 100 → Console (NoVNC)

pfSense Installer:
1. Welcome: [Enter] (accept)
2. Install pfSense: [Enter]
3. Keymap: German / de.kbd → Continue
4. Partitioning: Auto (ZFS) → [Enter]
5. ZFS Configuration:
   - Install: stripe (single disk)
   - Select: ada0 (32 GB VirtIO Disk)
   - Continue: [Enter]
6. Installation runs... (~3 minutes)
7. Manual Configuration: No → Reboot
```

**After reboot - Interface assignment:**

```
pfSense Console Menu:

Available interfaces:
  vtnet0 (VirtIO - vmbr_mgmt)
  igb0   (Intel 82571EB Passthrough - WAN)

Setup VLANs now? → n (no)

WAN interface name: igb0 [Enter]
LAN interface name: vtnet0 [Enter]
Optional 1 interface: [Enter] (empty - configure later)

Proceed? → y

Interfaces assigned:
  WAN  → igb0  (Passthrough NIC → will become bge0 on real HW)
  LAN  → vtnet0 (VirtIO bridge)
```

### 4.4 Configure WAN Interface (temporary DHCP)

```
pfSense Console:
2) Set interface(s) IP address

Enter interface (wan): [Enter]

Configure IPv4 address WAN interface via DHCP? → n (no)
Enter new WAN IPv4 address: 87.236.199.191
Enter WAN IPv4 subnet bit count: 23
Enter new WAN IPv4 upstream gateway address: [Colo gateway - documented in pfSense backup]

Configure IPv6 via DHCP6? → n (no)

Revert to HTTP as webConfigurator protocol? → n (no - keep HTTPS)
```

**IMPORTANT:** After WAN Config, the pfSense WebGUI should be reachable.

### 4.5 pfSense Config Restore

**Via Laptop (directly on LAN interface):**

```
Temporary Laptop IP:
IP: 10.0.10.99/24
Gateway: 10.0.10.1 (pfSense LAN)

Open browser:
https://10.0.10.1

Login:
- Username: admin
- Password: pfsense (default)

Diagnostics → Backup & Restore → Restore Backup:
- Configuration file: [upload config-fw-prod-cz-thor-20260109.xml]
- Restore Configuration: ✅
- Reboot: ✅

→ System reboots (~2 minutes)
```

**After reboot - verification:**

```
pfSense Console:

Interfaces should now be:
  WAN   → igb0  (87.236.199.191/23)
  LAN   → vtnet0 (10.0.10.1/24)
  MGT   → vtnet0.69 (77.77.77.1/29) - VLAN 69
  VPN   → [needs to be reconfigured - see next step]
  WG_VPN → tun_wg0 (182.22.16.1/29)
```

**CHECKPOINT 4:** pfSense VM runs, WAN active, Config restored.

* * *

## Phase 5: Thor Cabling (20 minutes)

**Time window:** 12:45 - 13:05

### 5.1 Connect WAN cable

```
HP Switch Port 3 → Thor eno0 (Passthrough NIC - WAN via HP Switch)
```

**ALTERNATIVE (if direct WAN access preferred):**

```
Colo Uplink direct → Thor eno0 (Bypass Switch)
```

**IMPORTANT:** eno0 is now exclusively assigned to the pfSense VM. The Proxmox Host does NOT see this NIC.

### 5.2 Management Link (eno2)

```
HP Switch Port 1 → Thor eno2 (Proxmox Management - vmbr_mgmt)
```

**Configure HP Port 1 as Access Port (VLAN 10):**

```sh
<HP> system-view
[HP] interface GigabitEthernet1/0/1
[HP-GigabitEthernet1/0/1] port access vlan 10
[HP-GigabitEthernet1/0/1] description Thor-Mgmt-eno2
[HP-GigabitEthernet1/0/1] quit
[HP] save
```

**Proxmox Host Test:**

```sh
# On Thor (via iLO Console):
ping 10.0.10.2  # HP Switch
# Expected response: < 1ms

ping 10.0.10.1  # pfSense LAN gateway
# Expected response: < 1ms

# Internet Test (via pfSense routing):
ping 1.1.1.1
# Expected response: ~15ms (should now work!)
```

**CHECKPOINT 5:** Thor completely cabled, routing works.

* * *

## Phase 6: Loki LACP Migration (30 minutes)

**Time window:** 13:05 - 13:35

### 6.1 Boot up Loki (temporary with Single Link)

**Via iLO ([https://77.77.77.3](https://77.77.77.3)):**

```
Power On Server
```

**After boot - Login to Proxmox Host (via SSH 10.0.1.10):**

```sh
# Network status:
ip addr show eno1
# Should have 10.0.1.10/24 (old state)

# VMs/LXCs status:
qm list
pct list

# DO NOT start yet - configure LACP first
```

### 6.2 Adjust `/etc/network/interfaces` for LACP

**Create backup:**

```sh
cp /etc/network/interfaces /root/interfaces.backup.$(date +%s)
```

**New configuration:**

```sh
nano /etc/network/interfaces
```

**LACP Bond Config:**

```sh
# Loopback
auto lo
iface lo inet loopback

# LACP Bond Member NICs
auto eno1
iface eno1 inet manual
    bond-master bond0

auto eno2
iface eno2 inet manual
    bond-master bond0

auto eno3
iface eno3 inet manual
    bond-master bond0

auto eno4
iface eno4 inet manual
    bond-master bond0

# LACP Bond interface
auto bond0
iface bond0 inet manual
    bond-slaves eno1 eno2 eno3 eno4
    bond-mode 802.3ad
    bond-miimon 100
    bond-xmit-hash-policy layer3+4
    bond-lacp-rate fast

# VLAN-Aware bridge (Production Workloads)
auto vmbr0
iface vmbr0 inet static
    address 10.0.30.10/24
    gateway 10.0.30.1
    bridge-ports bond0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 10 20 30
    # LACP Aggregated bridge - All VLANs

# Internal Storage bridge (TrueNAS ↔ Plex ↔ arr-stack)
auto vmbr_storage
iface vmbr_storage inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # Internal Storage - Unlimited Bandwidth (VM-to-VM only, no host IP needed)
```

**IMPORTANT:** Gateway changes from `10.0.1.1` (old LAN) to `10.0.30.1` (new VLAN 30 Compute gateway).

### 6.3 Reconnect Loki cables

**BEFORE:** Only Port 1 active (eno1 → Dell Switch Port 1)

**AFTER:**

```
HP Switch Port 9  → Loki eno1
HP Switch Port 10 → Loki eno2
HP Switch Port 11 → Loki eno3
HP Switch Port 12 → Loki eno4
```

**Connect ALL FOUR cables simultaneously, then:**

### 6.4 Activate LACP on HP Switch

```sh
<HP> system-view

# bridge-Aggregation2 for Loki (Ports 9-12)
[HP] interface bridge-Aggregation2
[HP-bridge-Aggregation2] description Loki-LACP-Bond
[HP-bridge-Aggregation2] port link-type trunk
[HP-bridge-Aggregation2] port trunk permit vlan 1 10 20 30
[HP-bridge-Aggregation2] link-aggregation mode dynamic
[HP-bridge-Aggregation2] quit

# Port 9 (eno1)
[HP] interface GigabitEthernet1/0/9
[HP-GigabitEthernet1/0/9] port link-type trunk
[HP-GigabitEthernet1/0/9] port trunk permit vlan 1 10 20 30
[HP-GigabitEthernet1/0/9] port link-aggregation group 2
[HP-GigabitEthernet1/0/9] quit

# Port 10 (eno2)
[HP] interface GigabitEthernet1/0/10
[HP-GigabitEthernet1/0/10] port link-type trunk
[HP-GigabitEthernet1/0/10] port trunk permit vlan 1 10 20 30
[HP-GigabitEthernet1/0/10] port link-aggregation group 2
[HP-GigabitEthernet1/0/10] quit

# Port 11 (eno3)
[HP] interface GigabitEthernet1/0/11
[HP-GigabitEthernet1/0/11] port link-type trunk
[HP-GigabitEthernet1/0/11] port trunk permit vlan 1 10 20 30
[HP-GigabitEthernet1/0/11] port link-aggregation group 2
[HP-GigabitEthernet1/0/11] quit

# Port 12 (eno4)
[HP] interface GigabitEthernet1/0/12
[HP-GigabitEthernet1/0/12] port link-type trunk
[HP-GigabitEthernet1/0/12] port trunk permit vlan 1 10 20 30
[HP-GigabitEthernet1/0/12] port link-aggregation group 2
[HP-GigabitEthernet1/0/12] quit

[HP] quit
<HP> save
```

### 6.5 Restart Loki Network

```sh
# Via iLO Remote Console (safer):
systemctl restart networking

# Verification:
ip addr show bond0
# Should show "master", NO IP (will be used by vmbr0)

ip addr show vmbr0
# Should show 10.0.30.10/24

cat /proc/net/bonding/bond0
# Expected output:
# Bonding Mode: IEEE 802.3ad Dynamic link aggregation
# MII status: up
# Aggregator ID: 1
# Number of ports: 4
# Slave interface: eno1
# Slave interface: eno2
# Slave interface: eno3
# Slave interface: eno4
```

**Check HP Switch LACP status:**

```sh
<HP> display link-aggregation summary

# Expected output:
# bridge-Aggregation2: UP
# Selected ports: GE1/0/9, GE1/0/10, GE1/0/11, GE1/0/12
```

**CHECKPOINT 6:** Loki LACP active, 4 Gbps aggregated.

* * *

## Phase 7: pfSense VLAN & Firewall Config (45 minutes)

**Time window:** 13:35 - 14:20

### 7.1 pfSense VM - Add additional VirtIO NICs

**Problem:** Config Restore imported the old physical interfaces. New VM needs separate VirtIO NICs for VLANs.

**Via Proxmox WebGUI ([https://10.0.10.5:8006](https://10.0.10.5:8006)):**

```
VM 100 (fw-prod-cz-thor) → Hardware → Add → Network Device:

Network Device 2:
- Bridge: vmbr_mgmt
- Model: VirtIO
- VLAN Tag: 20
- Firewall: ❌
→ Add

Network Device 3:
- Bridge: vmbr_mgmt
- Model: VirtIO
- VLAN Tag: 30
- Firewall: ❌
→ Add
```

**Check VM Config:**

```sh
cat /etc/pve/qemu-server/100.conf

# Expected output:
# net0: virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr_mgmt (LAN - VLAN 10 untagged)
# net1: virtio=YY:YY:YY:YY:YY:YY,bridge=vmbr_mgmt,tag=20 (Production - VLAN 20)
# net2: virtio=ZZ:ZZ:ZZ:ZZ:ZZ:ZZ,bridge=vmbr_mgmt,tag=30 (Compute - VLAN 30)
```

**Reboot pfSense VM:**

```sh
qm reboot 100
```

### 7.2 pfSense interface assignment

**Via pfSense WebGUI ([https://10.0.10.1](https://10.0.10.1)):**

```
Interfaces → Assignments:

Available interfaces:
- vtnet0 (existing - LAN 10.0.10.1/24)
- vtnet1 (new)
- vtnet2 (new)

Add:
- vtnet1 → OPT1 (rename to "PROD")
- vtnet2 → OPT2 (rename to "COMPUTE")

Save → Apply Changes
```

**Interface Configuration:**

```
Interfaces → PROD (OPT1):
- Enable: ✅
- Description: Production
- IPv4 Configuration Type: Static IPv4
- IPv4 Address: 10.0.20.1 / 24
- Save → Apply Changes

Interfaces → COMPUTE (OPT2):
- Enable: ✅
- Description: Compute
- IPv4 Configuration Type: Static IPv4
- IPv4 Address: 10.0.30.1 / 24
- Save → Apply Changes
```

### 7.3 Activate DHCP Server (VLANs)

```
Services → DHCP Server:

PROD Tab:
- Enable: ✅
- Range: 10.0.20.100 - 10.0.20.250
- DNS: 1.1.1.1, 1.0.0.1
- Gateway: 10.0.20.1
- Save

COMPUTE Tab:
- Enable: ✅
- Range: 10.0.30.100 - 10.0.30.250
- DNS: 1.1.1.1, 1.0.0.1
- Gateway: 10.0.30.1
- Save
```

### 7.4 Firewall Rules (Basic Allow All - for Testing)

**WARNING:** These rules allow EVERYTHING. Restrict later!

```
Firewall → Rules:

PROD Tab → Add (Top):
- Action: Pass
- Interface: PROD
- Protocol: Any
- Source: PROD net
- Destination: Any
- Description: Temporary - Allow All Outbound
- Save

COMPUTE Tab → Add (Top):
- Action: Pass
- Interface: COMPUTE
- Protocol: Any
- Source: COMPUTE net
- Destination: Any
- Description: Temporary - Allow All Outbound
- Save

Apply Changes
```

**CHECKPOINT 7:** pfSense VLANs configured, routing active.

* * *

## Phase 8: VM/LXC Migration (60 minutes)

**Time window:** 14:20 - 15:20

### 8.1 Plan IP Address Mapping

**Old IPs (10.0.1.x) → New IPs (VLAN 20/30):**

| VMID | Name           | Old IP    | New IP        | VLAN |
| ---- | -------------- | --------- | ------------- | ---- |
| 4000 | truenas        | 10.0.1.20 | 10.0.30.20/24 | 30   |
| 1000 | pms-prod-cz-01 | 10.0.1.30 | 10.0.20.30/24 | 20   |
| 2000 | docker-prod    | 10.0.1.40 | 10.0.30.40/24 | 30   |
| 8000 | nextcloud      | 10.0.1.70 | 10.0.20.70/24 | 20   |
| 1100 | the-arr-stack  | 10.0.1.90 | 10.0.30.90/24 | 30   |

### 8.2 Migrate TrueNAS VM (VMID 4000)

**Proxmox WebGUI:**

```
VM 4000 (truenas) → Hardware:

net0 → Edit:
- Bridge: vmbr0
- VLAN Tag: 30
- Model: VirtIO (unchanged)
- Save

Add → Network Device (net1 - Storage):
- Bridge: vmbr_storage
- VLAN Tag: (empty)
- Model: VirtIO
- Save
```

**Start VM:**

```sh
qm start 4000
```

**Via TrueNAS Console (Proxmox NoVNC):**

```
TrueNAS Console Menu:
1) Configure Network Interfaces

Select interface: vtnet0

Remove current settings? → yes

Configure IPv4? → yes
Configure via DHCP? → no
IPv4 Address: 10.0.30.20
IPv4 Netmask: 24

Configure IPv6? → no

Configure additional interfaces? → yes

Select interface: vtnet1

Configure IPv4? → yes
IPv4 Address: 10.10.10.1
IPv4 Netmask: 24

Configure IPv6? → no

Save changes? → yes

Configure default route? → yes
Default gateway: 10.0.30.1

Reboot? → yes
```

**Verification (after reboot):**

```
Browser: https://10.0.30.20

Test TrueNAS login
```

### 8.3 Plex VM (VMID 1000) - Multi-Homed

```
VM 1000 → Hardware:

net0 → Edit:
- Bridge: vmbr0
- VLAN Tag: 20 (Production - External Access)
- Save

Add → Network Device (net1):
- Bridge: vmbr_storage (Internal Storage)
- Save
```

**Ubuntu VM Network Config (via Console):**

```sh
# Start VM
qm start 1000

# Console login
nano /etc/netplan/00-installer-config.yaml

network:
  version: 2
  renderer: networkd
  ethernets:
    ens18:  # External (vmbr0.20)
      dhcp4: no
      addresses:
        - 10.0.20.30/24
      routes:
        - to: default
          via: 10.0.20.1
      nameservers:
        addresses: [1.1.1.1, 1.0.0.1]

    ens19:  # Storage (vmbr_storage)
      dhcp4: no
      addresses:
        - 10.10.10.2/24

# Apply
netplan apply

# Test
ping 10.0.20.1  # gateway
ping 10.10.10.1  # TrueNAS Storage
```

**Test Plex:**

```
Browser: http://10.0.20.30:32400/web
```

### 8.4 Migrate other VMs analogously

**Shortcuts (for all remaining VMs):**

```sh
# docker-prod (VMID 2000) → VLAN 30
qm set 2000 -net0 virtio,bridge=vmbr0,tag=30
# Internal IP: 10.0.30.40/24 (via Netplan)

# nextcloud (VMID 8000) → VLAN 20
qm set 8000 -net0 virtio,bridge=vmbr0,tag=20
# Internal IP: 10.0.20.70/24

# the-arr-stack (VMID 1100) → VLAN 30 + vmbr_storage
qm set 1100 -net0 virtio,bridge=vmbr0,tag=30
qm set 1100 -net1 virtio,bridge=vmbr_storage
# ens18: 10.0.30.90/24
# ens19: 10.10.10.3/24
```

**Start each VM individually, configure IP, and test.**

### 8.5 Migrate LXCs (Faster)

**LXC Network Config is easier (via Proxmox GUI):**

```
LXC 3000 (prometheus) → Network:
- net0: name=eth0, bridge=vmbr0, tag=30, ip=10.0.30.80/24, gw=10.0.30.1

LXC 3002 (influxdb):
- net0: bridge=vmbr0, tag=30, ip=10.0.30.82/24, gw=10.0.30.1

LXC 5000 (ptero-panel-prod):
- net0: bridge=vmbr0, tag=30, ip=10.0.30.100/24, gw=10.0.30.1

# etc. for all LXCs
```

**Batch Start:**

```sh
for ctid in 3000 3002 5000 5001 5050 6000 6100; do
    pct start $ctid
done
```

**CHECKPOINT 8:** All VMs/LXCs running in new VLANs.

* * *

## Phase 9: WireGuard OOB Gateway LXC (30 minutes)

**Time window:** 15:20 - 15:50

### 9.1 Create LXC

**Proxmox WebGUI:**

```
Create CT:
- Node: pve-prod-cz-thor
- CT ID: 9100
- Hostname: wg-oob-gateway
- Password: [secure PW]
- Template: debian-12-standard
- Disk: 4 GB
- CPU: 1 Core
- Memory: 256 MB
- Network:
  - net0: name=eth0, bridge=vmbr_mgmt, tag=10, ip=10.0.10.100/24, gw=10.0.10.1
  - net1: name=eth1, bridge=vmbr_oob, ip=172.20.10.100/24, gw=(empty)

Options:
- Start at boot: ✅
- Unprivileged: ✅

Create
```

### 9.2 Install & Configure WireGuard

**Start LXC & Console:**

```sh
pct start 9100
pct enter 9100

# Updates
apt update && apt upgrade -y

# Install WireGuard
apt install -y wireguard iptables

# Load Kernel Module (on the Host - one-time)
# On Thor Proxmox Host:
modprobe wireguard
echo "wireguard" >> /etc/modules

# In LXC:
cd /etc/wireguard

# Generate Keys
wg genkey | tee privatekey | wg pubkey > publickey

# WireGuard Config
nano wg0.conf
```

**wg0.conf content:**

```toml
[Interface]
PrivateKey = <content from privatekey>
Address = 172.20.10.100/24
ListenPort = 51820

# Activate IP Forwarding
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -A FORWARD -o wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth1 -j MASQUERADE

# Client Peers (example - User Laptop):
[Peer]
PublicKey = <Laptop Public Key>
AllowedIPs = 172.20.10.200/32
```

**Permanently activate IP Forwarding:**

```sh
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

**Start WireGuard:**

```sh
wg-quick up wg0
systemctl enable wg-quick@wg0
```

**Test:**

```sh
# In LXC:
ping 172.20.10.1  # Colo VPN gateway (via bge1)

# From user Laptop (after WireGuard Client Config):
ping 172.20.10.100  # LXC
ping 77.77.77.2  # Thor iLO (via OOB gateway!)
```

**CHECKPOINT 9:** WireGuard OOB gateway active, iLO access secured.

* * *

## Phase 10: Final Validation (30 minutes)

**Time window:** 15:50 - 16:20

### 10.1 Connectivity Tests

**From Loki Proxmox Host:**

```sh
# VLAN 10 (Management)
ping 10.0.10.1   # pfSense gateway ✅
ping 10.0.10.2   # HP Switch ✅
ping 10.0.10.5   # Thor Proxmox ✅
ping 10.0.10.100 # WireGuard OOB LXC ✅

# VLAN 30 (Compute - own network)
ping 10.0.30.1   # pfSense gateway ✅
ping 10.0.30.20  # TrueNAS ✅

# Internet
ping 1.1.1.1     # Cloudflare ✅
curl -I https://google.com  # HTTP Test ✅
```

**From TrueNAS VM:**

```sh
ping 10.0.30.1         # gateway ✅
ping 10.10.10.2        # Plex Storage NIC ✅
ping 10.10.10.3        # arr-stack Storage NIC ✅
ping 1.1.1.1           # Internet ✅
```

**From Plex VM:**

```sh
ping 10.0.20.1         # Production gateway ✅
ping 10.10.10.1        # TrueNAS Storage ✅
curl http://10.0.20.30:32400/web  # Plex Web ✅
```

### 10.2 Service Tests

| Service        | URL/Command                                                  | Expected Result      |
| -------------- | ------------------------------------------------------------ | -------------------- |
| pfSense WebGUI | [https://10.0.10.1](https://10.0.10.1)                       | Login Page ✅         |
| Proxmox Thor   | [https://10.0.10.5:8006](https://10.0.10.5:8006)             | Login Page ✅         |
| Proxmox Loki   | [https://10.0.30.10:8006](https://10.0.30.10:8006)           | Login Page ✅         |
| TrueNAS        | [https://10.0.30.20](https://10.0.30.20)                     | Dashboard ✅          |
| Plex           | [http://10.0.20.30:32400/web](http://10.0.20.30:32400/web)   | Media Library ✅      |
| Nextcloud      | [https://nextcloud.getinn.top](https://nextcloud.getinn.top) | Files ✅              |
| Pterodactyl    | [https://panel.getinn.top](https://panel.getinn.top)         | Server List ✅        |
| WireGuard VPN  | `ping 182.22.16.1` (from User Laptop)                         | Reply ✅              |
| OOB gateway    | `ping 77.77.77.2` (via WireGuard OOB)                        | Thor iLO reachable ✅ |

### 10.3 Performance Tests

**LACP Bandwidth:**

```sh
# On Loki Host:
iperf3 -s

# On Thor Host:
iperf3 -c 10.0.30.10 -t 30 -P 4

# Expected Result: ~3.7 Gbps aggregated (4x 1 GbE with Overhead)
```

**Storage Performance (vmbr_storage):**

```sh
# On Plex VM:
dd if=/dev/zero of=/mnt/truenas/testfile bs=1G count=5 oflag=direct

# Expected speed: > 500 MB/s (virtual bridge, no NIC limit)
```

### 10.4 Switch status

```sh
<HP> display link-aggregation summary

# Expected output:
# BAGG2: UP (Loki - 4 ports selected)

<HP> display interface brief

# All Ports UP:
# GE1/0/1: UP (Thor eno2 - Management)
# GE1/0/9-12: UP (Loki eno1-4 - LACP)
# GE1/0/17-18: UP (iLOs)
```

### 10.5 pfSense Health Check

```sh
pfSense WebGUI → Status → Interfaces:

WAN (igb0):
- Status: up
- IPv4: 87.236.199.191/23
- Traffic: RX/TX active ✅

LAN (vtnet0):
- Status: up
- IPv4: 10.0.10.1/24 ✅

PROD (vtnet1):
- Status: up
- IPv4: 10.0.20.1/24 ✅

COMPUTE (vtnet2):
- Status: up
- IPv4: 10.0.30.1/24 ✅

WG_VPN (tun_wg0):
- Status: up
- IPv4: 182.22.16.1/29 ✅
```

**CHECKPOINT 10:** All Services functional, Performance validated.

* * *

## Rollback Procedure (In case of critical error)

**Trigger:** Critical Service failure > 30 minutes unresolved.

### Rollback Step 1: Stop VMs/LXCs

```sh
# On Loki:
for vmid in $(qm list | awk '{print $1}' | grep -v VMID); do
    qm shutdown $vmid --timeout 60 --forceStop 1
done

for ctid in $(pct list | awk '{print $1}' | grep -v VMID); do
    pct shutdown $ctid
done
```

### Rollback Step 2: Shut down Thor

```sh
# Thor pfSense VM:
qm shutdown 100 --timeout 60

# Thor Proxmox Host:
shutdown -h now
```

### Rollback Step 3: Reinstall Dell Switch

```
1. Power off HP Switch
2. Connect Dell Switch
3. Re-create old cabling:
   - Port 1: Loki eno1
   - Port 17-18: iLOs
   - Port 23: Thor em0 (LAN)
   - Port 24: Laptop

4. Boot up Thor (bare-metal pfSense boots automatically)
5. Boot up Loki (old /etc/network/interfaces via backup)
```

### Rollback Step 4: Verification

```sh
# Thor pfSense:
# Should automatically boot with old Config

# Loki:
# If new Config active:
cp /root/interfaces.backup.XXXXX /etc/network/interfaces
systemctl restart networking

# Start VMs:
qm start 4000  # TrueNAS
qm start 1000  # Plex
# etc.
```

**Rollback Time:** ~30 minutes
**Data Loss:** None (only config changes are reverted)

* * *

## Post-Migration Tasks

### Within 24 hours:

- [ ] **Securely store Dell Switch** (as backup hardware)
- [ ] **Update Monitoring Dashboards** (new IPs)
- [ ] **Check DNS Records** (if static IPs used)
- [ ] **Test backup jobs** (new network paths)
- [ ] **Update documentation:**
  - [ ] 01-current-state.md → archive
  - [ ] 02-target-state.md → rename to "01-current-state.md"

### Within 1 week:

- [ ] **Harden firewall rules** (remove current "Allow All")
- [ ] **Test VLAN Segmentation** (Inter-VLAN Isolation)
- [ ] **Release OOB gateway for production use**
- [ ] **Set up Performance Monitoring** (LACP Bandwidth Grafana Dashboard)
- [ ] **Configure Hetzner Storage Box backup**

### Within 1 month:

- [ ] **Create Reverse Proxy LXC** (Traefik/Caddy for SSL Termination)
- [ ] **Automate Let's Encrypt Wildcard Cert**
- [ ] **Migrate Pterodactyl to new IPs** (if stable)
- [ ] **Load Testing** (Plex simultaneous streams + arr-stack downloads)

* * *

## Troubleshooting Guide

### Problem: Proxmox Host has no Internet

**Symptom:** `ping 1.1.1.1` failed

**Diagnosis:**

```sh
ip route show
# Gateway missing?

ping 10.0.10.1
# pfSense reachable?
```

**Fix:**

```sh
ip route add default via 10.0.10.1 dev vmbr_mgmt
# Permanently enter in /etc/network/interfaces
```

* * *

### Problem: LACP not active

**Symptom:** Only 1 Port active, others DOWN

**Diagnosis:**

```sh
# On Loki:
cat /proc/net/bonding/bond0
# "Aggregator ID" should be identical for all slaves

# On HP Switch:
<HP> display link-aggregation verbose bridge-Aggregation2
# "selected" should show all 4 ports
```

**Fix:**

```sh
# Check LACP Mode:
[HP] interface bridge-Aggregation2
[HP-bridge-Aggregation2] display this
# "link-aggregation mode dynamic" must be present

# If "static":
[HP-bridge-Aggregation2] undo link-aggregation mode
[HP-bridge-Aggregation2] link-aggregation mode dynamic
[HP-bridge-Aggregation2] quit
[HP] save
```

* * *

### Problem: pfSense VM does not boot

**Symptom:** VM stuck at "Booting..."

**Diagnosis:**

```sh
# Via Proxmox Console:
qm terminal 100

# Check UEFI Boot Order:
# Boot Menu should show "virtio0" (Disk)

# If CD/DVD Boot:
qm set 100 -boot order=virtio0
qm reboot 100
```

**Fix (worst case - manually import Config):**

```sh
# Reinstall pfSense (see Phase 4.3)
# After installation: Restore Config via WebGUI
```

* * *

### Problem: NIC Passthrough failed

**Symptom:** `vfio-pci` not bound, `e1000e` active

**Diagnosis:**

```sh
lspci -k -s 09:00.0
# "Kernel driver in use: e1000e" → Error!
```

**Fix:**

```sh
# Module Blacklist:
echo "blacklist e1000e" >> /etc/modprobe.d/blacklist.conf

# Re-bind VFIO:
echo "8086 105e" > /sys/bus/pci/drivers/vfio-pci/new_id

# Generate new initramfs:
update-initramfs -u -k all
reboot
```

* * *

### Problem: VMs have no Internet

**Symptom:** `ping 1.1.1.1` failed in VM

**Diagnosis:**

```sh
# In VM:
ip route show
# Gateway correct (10.0.20.1 / 10.0.30.1)?

# On pfSense:
pfSense WebGUI → Firewall → Rules
# "Default deny all" active?

# Check NAT:
Firewall → NAT → Outbound
# auto-NAT for new VLANs?
```

**Fix:**

```sh
# pfSense firewall Rules:
Firewall → Rules → PROD/COMPUTE
# Add "Allow all" rule temporarily (see Phase 7.4)

# Outbound NAT:
Firewall → NAT → Outbound
# Mode: Automatic (should create auto-NAT for 10.0.20.0/24 and 10.0.30.0/24)
```

* * *

## Contact & Escalation

**On-Site Support:** Not available (Colo Prague)
**Remote Support:** iLO + WireGuard OOB gateway
**Backup Contact:** \[phone number Colo operator\]

**Escalation:**

1. **Critical error:** Start Rollback within 30 min (see Rollback Procedure)
2. **Non-critical:** Document issue, fix after migration
3. **Unknown problem:** Collect screenshots + logs, analyze remotely

* * *

## Checklist: Migration Completed

- [ ] **All VMs running** (qm list → 5/5 running)
- [ ] **All LXCs running** (pct list → 9/9 running)
- [ ] **LACP active** (4 Gbps Aggregation validated)
- [ ] **pfSense routing** (all VLANs have Internet)
- [ ] **Services reachable** (Plex, Nextcloud, Pterodactyl tested)
- [ ] **iLO via OOB gateway** (WireGuard functional)
- [ ] **Performance validated** (iperf3 tests successful)
- [ ] **Backups secured** (pfSense config.xml, VM backups available)
- [ ] **Documentation updated** (new IPs, Port Mapping)
- [ ] **Dell Switch secured** (kept as rollback hardware)

* * *

**Document Version:** 1.0
**Created:** 2026-01-09
**Last Checked:** \[date after Pre-Flight Check\]
**Status:** READY FOR EXECUTION

* * *

**Note:** Print this document on-site and check off each step during the migration. Immediately document any deviations.
