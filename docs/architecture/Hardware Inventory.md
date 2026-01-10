# Hardware Inventory

## Hardware Inventory

**Last Updated:** 2026-01-09 **Environment:** Colo Prague Production

* * *

## Physical Servers

* * *

### Thor - HP ProLiant DL320e Gen8 v2

**Role:** Firewall/Router (current: bare metal pfSense, future: Proxmox Hypervisor) **Serial:** CZ153100BN **Location:** Colo Prague Rack

#### Specifications

| Component | Details                                     |
| --------- | ------------------------------------------- |
| CPU       | Intel Xeon E3-1230L v3 @ 1.80GHz (4C/8T)    |
| RAM       | 16GB DDR3 ECC                               |
| Storage   | 2x Patriot P210 128GB SSD (ZFS Mirror)      |
| iLO       | iLO 4 - 77.77.77.2 (MAC: 50:65:f3:f0:d6:3e) |

#### Network Interfaces

| Interface | Type             | MAC | PCIe Address | Current Use               | Future Use                    |
| --------- | ---------------- | --- | ------------ | ------------------------- | ----------------------------- |
| bge0      | Broadcom BCM5720 | \-  | 0000:03:00.0 | WAN (87.236.199.191/23)   | Passthrough to pfSense VM     |
| bge1      | Broadcom BCM5720 | \-  | 0000:03:00.1 | Colo VPN (172.20.10.0/24) | Proxmox vmbr\_oob             |
| eno0      | Intel 82571EB    | \-  | 0000:09:00.0 | Unused                    | Passthrough to pfSense (LACP) |
| eno1      | Intel 82571EB    | \-  | 0000:09:00.1 | Unused                    | Passthrough to pfSense (LACP) |
| eno2      | Intel 82571EB    | \-  | 0000:10:00.0 | Unused                    | Proxmox Management (VLAN 10)  |
| eno3      | Intel 82571EB    | \-  | 0000:10:00.1 | Unused                    | Reserve/Reverse Proxy         |

#### Storage Details

| Disk | Model              | Capacity | Status | Power-On Hours | Remaining Life | Temp    |
| ---- | ------------------ | -------- | ------ | -------------- | -------------- | ------- |
| ada0 | Patriot P210 128GB | 128 GB   | PASSED | 17,989h (~2y)  | 98%            | 21-22°C |
| ada1 | Patriot P210 128GB | 128 GB   | PASSED | 17,779h (~2y)  | 98%            | 21-22°C |

**RAID Config:** ZFS Mirror (ada0 + ada1)
**Total Writes:** ~15 TB per disk
**Health:** Excellent (0 reallocated sectors, no errors)

**Notes:**

* Onboard NICs: 2x Broadcom BCM5720 (bge0, bge1)
* Add-on Card: Intel 4-Port GbE (HP NC364T equivalent) - eno0-3
* All Intel ports individually passthrough-capable (separate PCIe functions)

* * *

### Loki - HP ProLiant DL380 Gen9

**Role:** Proxmox Compute Hypervisor **Serial:** CZJ526089F **Location:** Colo Prague Rack

#### Specifications

| Component | Details                                                              |
| --------- | -------------------------------------------------------------------- |
| CPU       | 2x Intel Xeon E5-2640 v4 @ 2.40GHz (10C/20T each, 40 threads total)  |
| RAM       | 128GB DDR4 ECC (87% utilized)                                        |
| Storage   | 3.6TB usable (ZFS pools + local storage)                             |
| GPU       | NVIDIA Quadro P2200 (Plex Hardware Transcoding, max 5-6x 4K streams) |
| iLO       | iLO 4 - 77.77.77.3 (MAC: ec:b1:d7:78:57:a8)                          |

#### Network Interfaces

| Interface | MAC               | Status | Current Use         | Future Use        |
| --------- | ----------------- | ------ | ------------------- | ----------------- |
| eno1      | 3c:a8:2a:20:aa:1c | UP     | vmbr0 (single link) | LACP bond0 member |
| eno2      | \-                | DOWN   | Unused              | LACP bond0 member |
| eno3      | \-                | DOWN   | Unused              | LACP bond0 member |
| eno4      | \-                | DOWN   | Unused              | LACP bond0 member |

#### Storage Configuration

| Storage      | Type      | Total   | Used    | Available | Usage | Content                |
| ------------ | --------- | ------- | ------- | --------- | ----- | ---------------------- |
| local-zfs    | ZFS Pool  | 190 GB  | 99 GB   | 91 GB     | 52%   | VM/LXC Disks           |
| local-ssd01  | ZFS Pool  | 431 GB  | 371 GB  | 60 GB     | 86%   | VM/LXC Disks           |
| local-hdd01  | ZFS Pool  | 2.16 TB | 1.62 TB | 539 GB    | 75%   | VM/LXC Disks           |
| local-backup | Directory | 141 GB  | 50 GB   | 91 GB     | 35%   | Backups                |
| local        | Directory | 121 GB  | 30 GB   | 91 GB     | 25%   | ISO/Templates/Snippets |

**Total Usable:** 3.04 TB | **Total Used:** 2.17 TB (71%)

#### Physical Disks

| Device  | Model                  | Type     | Capacity | Wearout | Usage             | Status |
| ------- | ---------------------- | -------- | -------- | ------- | ----------------- | ------ |
| nvme0n1 | Lexar NM620 1TB        | NVMe SSD | 1 TB     | 60%     | ZFS (local-ssd01) | PASSED |
| sdt     | SanDisk SSD PLUS 240GB | SATA SSD | 240 GB   | 100%    | ZFS (local-zfs)   | PASSED |
| sdu     | SanDisk SSD PLUS 240GB | SATA SSD | 240 GB   | 100%    | ZFS (local-zfs)   | PASSED |
| sdo     | HP EG0300FBLSE         | SAS HDD  | 300 GB   | N/A     | BIOS Boot         | OK     |
| sdp     | HP EG0300FBLSE         | SAS HDD  | 300 GB   | N/A     | BIOS Boot         | OK     |
| sdq     | HGST HCEP1200S5xnN010  | SAS HDD  | 1.2 TB   | N/A     | ZFS (local-hdd01) | OK     |
| sdr     | HGST HCEP1200S5xnN010  | SAS HDD  | 1.2 TB   | N/A     | ZFS (local-hdd01) | OK     |
| sds     | HGST HUC101812CSS200   | SAS HDD  | 1.2 TB   | N/A     | ZFS (local-hdd01) | OK     |

**Notes:**

- 2x SanDisk SSDs at 100% wearout - Plan replacement
- Lexar NVMe at 60% wearout - Monitor closely
- 3x SAS HDDs in local-hdd01 RAIDZ1 for cold storage

#### Current Workload

* **Running VMs:** 6/7
* **Running LXCs:** 9/13 (4 stopped)
* **Total RAM Allocated:** ~128GB (VMs + LXCs)
* **CPU Load Average:** 3.34, 2.80, 2.39 (last 1/5/15 min)

* * *

### NetApp DS4246 Disk Shelf

**Role:** External SAS Storage (passthrough to TrueNAS VM)
**Connection:** SAS HBA (LSI/Broadcom) → TrueNAS VM
**Location:** Colo Prague Rack

#### Configuration

| Component          | Details                               |
| ------------------ | ------------------------------------- |
| Chassis            | NetApp DS4246 24-Bay 4U Disk Shelf    |
| Connectivity       | Dual SAS paths (redundant)            |
| Disks Installed    | 16 disks (15 active + 1 failed)       |
| Total Raw Capacity | ~79 TB raw (59 TB usable after RAID)  |
| Passthrough Mode   | Direct PCIe passthrough to TrueNAS VM |

#### Disk Inventory

**Pool: tank (DEGRADED - 29.8 TB, 93% full)**

RAIDZ2 vdev (5 disks):

- 2x Seagate ST4000DM000-1F2168 4TB (5900 RPM) - Z307PGEA, Z307PAAS
- 2x Toshiba HDWD240 4TB (5400 RPM) - 11M1S18ES5HH, 11M1S17KS5HH
- 1x Toshiba MD04ACA400 4TB (7200 RPM) - 19KQKHXWFSAA

RAIDZ2 vdev (5 disks, 1 UNAVAILABLE):

- 2x Seagate ST2000NM0125 2TB (7200 RPM) - ZC200CFQ, ZC20071F
- 1x WD WD20EZRZ 2TB (5400 RPM) - WD-WCC4M0PKZ99S
- 1x WD WD20EARS 2TB - WD-WCAZA1811137
- 1x **UNAVAILABLE** (missing disk in RAIDZ2 array)

**Pool: tank1 (ONLINE - 29.3 TB, 84% full)**

RAIDZ1 vdev (3 disks):

- 2x HGST HUH721010ALN600 10TB (7200 RPM) - 7P01P3NG, 7P01JNRG
- 1x HGST HUH721010AL5205 10TB (7200 RPM, SCSI) - 4DH256XZ

**Pool: misc (ONLINE - 988 GB, 0.3% full)**

Single disk:

- 1x Seagate ST31000340NS 1TB (7200 RPM) - 9QJ4FJPD

**Failed/Spare Disks:**

- 1x WDC WD8002FRYZ 8TB (7200 RPM) - **DEAD** (R6GHM1WY) - needs replacement

#### Health Status

| Pool  | Status   | Health     | Last Scrub | Errors                            |
| ----- | -------- | ---------- | ---------- | --------------------------------- |
| tank  | DEGRADED | ⚠️ Warning | 2026-01-03 | 0 checksum errors, 1 unavail disk |
| tank1 | ONLINE   | ✅ Healthy  | 2025-12-27 | 0 errors                          |
| misc  | ONLINE   | ✅ Healthy  | 2025-12-27 | 0 errors                          |

**Notes:**

- tank pool DEGRADED due to 1 missing disk in RAIDZ2 vdev
- RAIDZ2 can tolerate 2 disk failures per vdev
- 1x 8TB WD RED (sdp) marked DEAD - remove and replace
- Regular scrubs show 0 checksum errors across all pools
- Total usable capacity: ~59 TB (after RAID overhead)

* * *

## Network Equipment

### Current: Dell PowerConnect 2824

**Role:** Interim L2 Switch (limited configuration capability) **Management:** Basic web interface **Location:** Colo Prague Rack **Limitations:** No LACP support, limited VLAN configuration

**Current Port Configuration:**

| Port(s) | Device           | Connection                | VLAN           | Notes                |
| ------- | ---------------- | ------------------------- | -------------- | -------------------- |
| 1-4     | DL380 Loki       | eno1 (only port 1 active) | Untagged       | No LACP possible     |
| 17      | Thor iLO         | Dedicated iLO Port        | VLAN 69        | Management           |
| 18      | Loki iLO         | Dedicated iLO Port        | VLAN 69        | Management           |
| 23      | DL320e Thor      | em0 (LAN)                 | Untagged       | Main production link |
| 24      | Laptop (on-site) | \-                        | VLAN 69 tagged | Physical access only |

**Reason for Replacement:** Cannot configure LACP, limited VLAN features needed for production.

* * *

### Planned: HP 1910-24G Switch (JE006A)

**Role:** Core L2 Switch (installation: End of January 2026) **Management IP:** TBD (VLAN 10) **Location:** Colo Prague Rack

#### Specifications

| Feature            | Details                       |
| ------------------ | ----------------------------- |
| Ports              | 24x GbE RJ-45 + 4x SFP        |
| Switching Capacity | 48 Gbps                       |
| VLAN Support       | 802.1Q (4096 VLANs)           |
| Link Aggregation   | 802.3ad LACP (up to 6 groups) |
| Management         | Web UI, CLI, SNMP             |

#### Planned Port Configuration

| Port(s) | Device      | Connection         | VLAN Mode      | LAG  | Description              |
| ------- | ----------- | ------------------ | -------------- | ---- | ------------------------ |
| 1-2     | DL320e Thor | eno0 + eno1        | Trunk          | LAG1 | pfSense LACP (All VLANs) |
| 3       | DL320e Thor | eno2               | Access VLAN 10 | \-   | Proxmox Management + OOB |
| 9-12    | DL380 Loki  | eno1-4             | Trunk          | LAG2 | Proxmox Compute LACP     |
| 17      | Thor iLO    | Dedicated iLO Port | Access VLAN 10 | \-   | Out-of-Band Management   |
| 18      | Loki iLO    | Dedicated iLO Port | Access VLAN 10 | \-   | Out-of-Band Management   |

#### Planned VLAN Configuration

| VLAN ID | Name       | Subnet       | Description                            |
| ------- | ---------- | ------------ | -------------------------------------- |
| 10      | Management | 10.0.10.0/24 | Proxmox hosts, iLOs, Switch management |
| 20      | Production | 10.0.20.0/24 | Production VMs/LXCs                    |
| 30      | Compute    | 10.0.30.0/24 | VM-to-VM internal traffic              |

**Internal Storage Bridge (vmbr_storage):**

- **Subnet:** 10.10.10.0/24
- **Description:** Dedicated storage network (TrueNAS ↔ Plex ↔ arr-stack)
- **IPs:**
  - 10.10.10.1: TrueNAS VM (storage interface)
  - 10.10.10.2: Plex VM (storage interface)
  - 10.10.10.3: arr-stack VM (storage interface)
- **Current Name:** vmbr1 (will be renamed to vmbr_storage during migration)
- **Bandwidth:** Unlimited (virtual bridge, RAM/CPU limited only)

**Notes:**

* VLAN 69 (77.77.77.0/29) will be migrated to VLAN 10
* LAG1 (Thor): LACP 802.3ad, hash: layer3+4
* LAG2 (Loki): LACP 802.3ad, hash: layer3+4
* vmbr_storage provides multi-Gbps bandwidth without physical NIC bottleneck

* * *

## External Services

### Netcup VPS - Mailcow

**Hostname:** mail **Public IP:** 89.58.12.131/22 **Platform:** Mailcow Dockerized

**Services:**

* 19x Docker Containers (Postfix, Dovecot, Rspamd, SOGo, MariaDB, Redis, Nginx, ClamAV, etc.)
* Email hosting for getinn.top domain

* * *

### Hetzner VPS - Debian

**Hostname:** debian-prod-fsn1-dc14-01 **Public IP:** 46.224.135.0/32 | 2a01:4f8:c17:f666::/64

**Services:**

* none

* * *

### Hetzner Storage Box

**Capacity:** 1TB **Protocol:** SFTP, CIFS, Rsync, BorgBackup **Purpose:** Proxmox VM/LXC Backup Target (planned)

**Notes:**

* Currently underutilized
* Will be configured as Proxmox Backup Storage
* Retention policy: TBD

* * *

## Hardware Summary

| Component        | Quantity | Location              | Role                                   |
| ---------------- | -------- | --------------------- | -------------------------------------- |
| Physical Servers | 2        | Colo Prague           | 1x Firewall (future HV), 1x Compute HV |
| Virtual Machines | 7        | Loki Proxmox          | Production workloads                   |
| LXC Containers   | 13       | Loki Proxmox          | Lightweight services                   |
| Network Switches | 1        | Colo Prague (planned) | Core L2 switching                      |
| External VPS     | 2        | Netcup, Hetzner       | Mail, Automation                       |
| Storage Boxes    | 1        | Hetzner               | Backup target                          |

**Total Compute Resources:**

* **CPUs:** 48 threads (8 on Thor, 40 on Loki)
* **RAM:** 144GB (16GB Thor, 128GB Loki)
* **Network:** 8x GbE ports physical, 2x LACP planned

* * *

## Colo Network Information

**WAN Block:** 87.236.199.191-194/23 (4 public IPv4 addresses) **Primary WAN Gateway:** WANGW (provided by Colo) **IPv6 Block:** 2a01:5f0:c001:108:1d::/96

**Colo VPN:**

* Network: 172.20.10.0/24
* Gateway: 172.20.10.1
* Purpose: Out-of-band management access
* Physical Connection: Dedicated cable from Colo provider to bge1

**Notes:**

* Colo provides WAN uplink + management VPN
* Management VPN password: 18 characters (no special chars) - cannot be changed
* Security concern: Direct connection not ideal, requires firewall layer

* * *

## Power & Environmental

**Power Consumption (estimated):**

* DL320e Gen8 v2: ~150W idle, ~250W load
* DL380 Gen9: ~200W idle, ~400W load
* Total: ~350W idle, ~650W under full load

**Cooling:** Colo-provided rack cooling **UPS:** Colo-provided power redundancy

* * *

## Planned Upgrades

**Q1 2026 (End of January):**

- [ ] HP 1910-24G Switch installation
- [ ] LACP configuration on Thor (eno0+eno1)
- [ ] LACP configuration on Loki (eno1-4)
- [ ] VLAN implementation (10, 20, 30)
- [ ] VLAN 69 → VLAN 10 migration

**Q1 2026 (February):**

- [ ] DL320e: pfSense bare metal → Proxmox + pfSense VM
- [ ] Rename vmbr1 → vmbr_storage on Loki
- [ ] WireGuard Gateway LXC for secure OOB access
- [ ] Reverse Proxy LXC (Traefik/Caddy)

**Future:**

- [ ] Dokploy LXC setup (4GB RAM)
- [ ] Migrate docker-prod-cz-01 VM → Dokploy
- [ ] NetBox + Trilium → Docker in Dokploy
- [ ] Free up ~5GB RAM on Loki

* * *

**Document Status:** Draft **Next Review:** After switch installation (Feb 2026)
