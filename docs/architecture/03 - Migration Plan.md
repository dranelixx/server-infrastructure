# 03 - Migration Plan

## Migration Plan: HP 1910-24G Switch & Thor Proxmox Migration

**Target Date:** 31. Januar - 1. Februar 2026 **Location:** Colo Prague (On-Site) **Estimated Downtime:** 2-4 Stunden **Rollback Window:** Verfügbar (Dell Switch bleibt vor Ort)

* * *

## Executive Summary

Dieses Dokument beschreibt die vollständige Migration von der aktuellen Infrastruktur (Dell PowerConnect 2824, Thor bare metal pfSense) zur Zielarchitektur (HP 1910-24G mit LACP, Thor Proxmox mit pfSense VM, Loki LACP Bond).

**Kritische Änderungen:**

* ✅ HP Switch Installation (LACP-fähig)
* ✅ Thor: Bare Metal pfSense → Proxmox + pfSense VM
* ✅ Loki: Single Link → LACP Bond (4x 1 GbE)
* ✅ VLAN Segmentation (10/20/30)
* ✅ NIC Passthrough (Intel 82571EB eno0-1 → pfSense VM)
* ✅ WireGuard OOB Gateway LXC

**Rollback-Strategie:** Dell Switch bleibt vor Ort, komplette Rückmigration in 30 Minuten möglich.

* * *

## Pre-Migration Checklist

### Eine Woche vorher (24. Januar 2026)

- [ ] **Backups erstellen:**
  
  - [ ] pfSense config.xml exportieren (`Diagnostics → Backup & Restore`)
  - [ ] Proxmox VMs/LXCs backup (manuell oder PBS)
  - [ ] TrueNAS config export
  - [ ] `/etc/network/interfaces` von Loki sichern

- [ ] **Hardware vorbereiten:**
  
  - [ ] HP 1910-24G Switch Config validieren (via Serial Console)
  
  - [ ] Alle Kabel beschriften (vor Ort mitbringen: Label Maker)
  
  - [ ] USB-Stick mit ISOs vorbereiten:
    
    * Proxmox VE 8.4.14 ISO
    * pfSense 2.8.1 ISO (falls VM neu erstellt werden muss)

- [ ] **Dokumentation drucken:**
  
  - [ ] Dieses Migrationsdokument (A4, doppelseitig)
  - [ ] Switch Port Mapping (Target State)
  - [ ] IP-Adressen-Tabelle (VLAN 10/20/30)
  - [ ] Rollback-Prozedur (separate Seite, Rot markiert)

- [ ] **Remote Access testen:**
  
  - [ ] Colo VPN erreichbar (172.20.10.x)
  - [ ] iLO Thor/Loki funktionsfähig (77.77.77.2-3)
  - [ ] Serial Console Kabel HP Switch testen

### Am Vortag (30. Januar 2026)

- [ ] **Wartungsfenster ankündigen:**
  
  - [ ] Pterodactyl Game-Server-Nutzer informieren (4h Downtime)
  - [ ] Plex-Nutzer informieren (WhatsApp Gruppe)
  - [ ] Nextcloud-Downtime (falls relevant)

- [ ] **Finale Backups:**
  
  - [ ] pfSense config.xml (frisch exportieren)
  - [ ] Proxmox cluster config
  - [ ] Aktuelle VM-Liste screenshot (`qm list`)

- [ ] **Toolbox packen:**
  
  - [ ] Laptop + Netzteil
  - [ ] USB-Serial-Kabel (HP Switch Console)
  - [ ] RJ45 Ethernet-Kabel (min. 10x, verschiedene Längen)
  - [ ] Label Maker + Tape
  - [ ] Notizblock + Stift (für MAC-Adressen, falls nötig)
  - [ ] USB-Stick mit ISOs

### On-Site Check (31. Januar, 09:00)

- [ ] **Physischer Zugang:**
  
  - [ ] Rack zugänglich
  - [ ] Dell Switch sichtbar/erreichbar
  - [ ] Alle Server physisch vorhanden

- [ ] **Verbindungen prüfen:**
  
  - [ ] Laptop → Dell Switch Port 24 (VLAN 69)
  - [ ] Serial Console → HP Switch (COM Port erkannt)
  - [ ] iLO Zugriff: [https://77.77.77.2](https://77.77.77.2) (Thor), [https://77.77.77.3](https://77.77.77.3) (Loki)

- [ ] **GO/NO-GO Entscheidung:**
  
  - [ ] Alle Backups vorhanden?
  - [ ] Alle Hardware vor Ort?
  - [ ] Rollback-Strategie verstanden?

* * *

## Phase 1: HP Switch Installation (45 Minuten)

**Zeitfenster:** 10:00 - 10:45 **Risiko:** Mittel (Network Outage während Switch-Wechsel)

### 1.1 Dell Switch Port Mapping dokumentieren

```sh
# Vor dem Abklemmen: Aktuelle Verkabelung fotografieren
# Label an jedem Kabel anbringen:
# - "Thor em0 → Port 23"
# - "Loki eno1 → Port 1"
# - "Thor iLO → Port 17"
# - "Loki iLO → Port 18"
# - "Laptop → Port 24"
```

### 1.2 Controlled Shutdown

**Auf Loki Proxmox (via SSH 10.0.1.10):**

```sh
# Alle VMs/LXCs sauber herunterfahren
qm list  # Liste nochmal prüfen
for vmid in 1000 1100 2000 4000 8000; do
    echo "Shutdown VM $vmid..."
    qm shutdown $vmid --timeout 120
done

# LXCs herunterfahren
for ctid in 3000 3002 5000 5001 5050 6000 6100 9000; do
    echo "Shutdown CT $ctid..."
    pct shutdown $ctid --timeout 60
done

# Proxmox host herunterfahren (via iLO Virtual Power Button möglich)
shutdown -h now
```

**Auf Thor pfSense (via WebGUI [https://fw-prod-cz-thor.getinn.top:10443](https://fw-prod-cz-thor.getinn.top:10443)):**

```
Diagnostics → Halt System → Confirm
```

**Physische Verifikation (via iLO Remote Console):**

- [ ] Loki vollständig heruntergefahren (keine POST-Messages)
- [ ] Thor vollständig heruntergefahren

### 1.3 HP Switch physisch installieren

```sh
# Dell Switch Kabel entfernen (geordnet, eins nach dem anderen):
1. Laptop-Kabel (Port 24) entfernen
2. iLO-Kabel (Port 17, 18) entfernen
3. Thor em0 (Port 23) entfernen
4. Loki eno1 (Port 1) entfernen

# Dell Switch ausbauen, zur Seite legen (NICHT entfernen aus Rack)

# HP Switch installieren:
1. HP 1910-24G in Rack montieren
2. Power-Kabel anschließen (warten bis Boot abgeschlossen)
3. Serial Console anschließen (Laptop COM Port)
```

### 1.4 HP Switch Basis-Konfiguration validieren

**Via Serial Console (PuTTY: 38400 8N1):**

```sh
<HP> display current-configuration

# Erwartete Ausgabe prüfen:
# - VLAN 10/20/30 existieren
# - Bridge-Aggregation1 (Ports 1-2)
# - Bridge-Aggregation2 (Ports 9-12)
# - Vlan-interface10 IP: 10.0.10.2
```

**Falls Config fehlt oder falsch:**

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

# Management IP setzen
[HP] interface Vlan-interface10
[HP-Vlan-interface10] ip address 10.0.10.2 255.255.255.0
[HP-Vlan-interface10] quit

# Config speichern
[HP] save
The current configuration will be written to the device. Are you sure? [Y/N]:y
```

### 1.5 Initiale Verkabelung (Management Only)

```sh
# Nur kritische Links verbinden:
HP Port 17 → Thor iLO (untagged VLAN 10 - wird später migriert)
HP Port 18 → Loki iLO (untagged VLAN 10 - wird später migriert)
HP Port 24 → Laptop (Access VLAN 10 für Management)
```

**Port 24 konfigurieren:**

```sh
<HP> system-view
[HP] interface GigabitEthernet1/0/24
[HP-GigabitEthernet1/0/24] port access vlan 10
[HP-GigabitEthernet1/0/24] quit
[HP] quit
<HP> save
```

**Laptop IP setzen (statisch):**

```
IP: 10.0.10.99/24
Gateway: (leer lassen)
```

**HP Switch Management testen:**

```sh
# Vom Laptop:
ping 10.0.10.2
# Erwartete Antwort: < 1ms

# HTTP GUI:
http://10.0.10.2
# Login: admin / (standard PW)
```

**CHECKPOINT 1:** HP Switch erreichbar, Management funktioniert.

* * *

## Phase 2: Thor - Proxmox Installation (60 Minuten)

**Zeitfenster:** 10:45 - 11:45 **Risiko:** Hoch (Data Loss bei ZFS Pool, kompletter pfSense Neuaufbau)

### 2.1 Proxmox VE 8.4.14 Installation

**Via iLO Remote Console ([https://77.77.77.2](https://77.77.77.2)):**

```
1. iLO Virtual Media → ISO mounten (Proxmox VE 8.4.14)
2. Boot Order → CD/DVD First
3. Power On → Installation starten

Proxmox Installation:
- Agree to EULA
- Target Harddisk: /dev/sda (Patriot P210 128GB)
- Filesystem: ZFS (RAID1)
  - Select Disks: /dev/sda, /dev/sdb (BEIDE SSDs)
  - ashift: 12 (Standard)
  - compress: lz4
  - checksum: on
  - copies: 1

- Country: Germany
- Timezone: Europe/Berlin
- Keyboard: de

- Admin Password: [Sicheres Passwort verwenden]
- Email: [Admin-Email]

- Management Interface: eno2 (Broadcom BCM5720 - Onboard NIC)
  WICHTIG: NICHT bge0 oder bge1 wählen (werden für pfSense gebraucht)

- Hostname (FQDN): pve-prod-cz-thor.getinn.top
- IP: 10.0.10.5/24
- Gateway: 10.0.10.1 (wird pfSense VM sein)
- DNS: 1.1.1.1 (temporär)

Installation durchführen → Reboot
```

**Nach Installation:**

```sh
# Via iLO Virtual Console Login:
# Username: root
# Password: [wie oben gesetzt]

# Netzwerk prüfen:
ip addr show eno2
# Erwartete Ausgabe: 10.0.10.5/24

ping 10.0.10.2  # HP Switch Management
# Erwartete Antwort: < 1ms

# NOCH NICHT ERREICHBAR von außen (kein Gateway/Routing)
```

### 2.2 IOMMU (VT-d) aktivieren

**Ziel:** PCI Passthrough für Intel 82571EB NICs an pfSense VM.

**GRUB Konfiguration bearbeiten:**

```sh
nano /etc/default/grub

# Zeile finden:
GRUB_CMDLINE_LINUX_DEFAULT="quiet"

# Ändern zu:
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

**GRUB Update & Module laden:**

```sh
# GRUB neu generieren
update-grub

# VFIO Module aktivieren
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules
echo "vfio_virqfd" >> /etc/modules

# Module sofort laden (ohne Reboot)
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio_pci
modprobe vfio_virqfd

# IOMMU Interrupt Remapping prüfen
dmesg | grep -e IOMMU -e DMAR
# Erwartete Ausgabe: "DMAR: Intel(R) Virtualization Technology for Directed I/O"
```

**System neustarten:**

```sh
reboot
```

**Nach Reboot - IOMMU verifizieren:**

```sh
# IOMMU Groups anzeigen
pvesh get /nodes/pve-prod-cz-thor/hardware/pci --pci-class-blacklist ""

# Alternative: Manuell prüfen
dmesg | grep -i iommu
# Erwartete Ausgabe: "IOMMU enabled"

find /sys/kernel/iommu_groups/ -type l
# Sollte IOMMU Groups anzeigen
```

### 2.3 Intel 82571EB NICs identifizieren

```sh
# Alle PCI Devices anzeigen
lspci -nn | grep -i ethernet

# Erwartete Ausgabe (ähnlich):
# 09:00.0 Ethernet controller [0200]: Intel Corporation 82571EB Gigabit Ethernet Controller [8086:105e] (rev 06)
# 09:00.1 Ethernet controller [0200]: Intel Corporation 82571EB Gigabit Ethernet Controller [8086:105e] (rev 06)
# 0a:00.0 Ethernet controller [0200]: Intel Corporation 82571EB Gigabit Ethernet Controller [8086:105e] (rev 06)
# 0a:00.1 Ethernet controller [0200]: Intel Corporation 82571EB Gigabit Ethernet Controller [8086:105e] (rev 06)

# PCIe Adressen notieren:
# eno0: 0000:09:00.0 (WAN)
# eno1: 0000:09:00.1 (LACP Member für Proxmox - RESERVED)
# eno2: 0000:0a:00.0 (LACP Member für Proxmox - RESERVED)
# eno3: 0000:0a:00.1 (LACP Member für Proxmox - RESERVED)
```

**WICHTIG:** Nur `eno0` (0000:09:00.0) wird an pfSense VM durchgereicht. eno1-3 bleiben für Proxmox LACP.

### 2.4 PCI Device für Passthrough vorbereiten

```sh
# Vendor/Device ID ermitteln
lspci -n -s 09:00.0
# Ausgabe: 09:00.0 0200: 8086:105e (rev 06)
# → Vendor ID: 8086, Device ID: 105e

# VFIO Binding für dieses Device
echo "options vfio-pci ids=8086:105e" > /etc/modprobe.d/vfio.conf

# Module Blacklist (verhindert Linux-Treiber Binding)
echo "blacklist e1000e" >> /etc/modprobe.d/blacklist.conf

# initramfs neu generieren
update-initramfs -u -k all

# System neustarten (kritisch!)
reboot
```

**Nach Reboot - Passthrough verifizieren:**

```sh
# Device sollte jetzt VFIO-Treiber nutzen:
lspci -k -s 09:00.0

# Erwartete Ausgabe:
# 09:00.0 Ethernet controller: Intel Corporation 82571EB
#     Kernel driver in use: vfio-pci
#     Kernel modules: e1000e

# Falls "e1000e" unter "Kernel driver in use" steht → Fehler!
```

**CHECKPOINT 2:** Proxmox läuft, IOMMU aktiv, NIC bereit für Passthrough.

* * *

## Phase 3: Netzwerk-Bridges konfigurieren (15 Minuten)

**Zeitfenster:** 11:45 - 12:00

### 3.1 `/etc/network/interfaces` bearbeiten

**Aktuellen Zustand sichern:**

```sh
cp /etc/network/interfaces /root/interfaces.backup.$(date +%s)
```

**Neue Konfiguration schreiben:**

```sh
nano /etc/network/interfaces
```

**Komplette Konfiguration:**

```sh
# Loopback
auto lo
iface lo inet loopback

# WAN NIC (für pfSense VM - wird via Passthrough genutzt)
# KEIN "auto eno0" - wird nicht vom Host genutzt

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
    #Management Bridge - VLAN 10 only

# Colo VPN NIC (isoliert für WireGuard OOB Gateway LXC)
auto bge1
iface bge1 inet manual

auto vmbr_oob
iface vmbr_oob inet static
    address 172.20.10.10/24
    bridge-ports bge1
    bridge-stp off
    bridge-fd 0
    #Colo VPN - Isolated for WireGuard OOB Gateway

# VLAN-Aware Bridge (für LXCs ohne dedizierte NICs)
auto vmbr0
iface vmbr0 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 10 20 30
    #VLAN Bridge for LXCs - VLANs 10/20/30
```

**Netzwerk neu starten:**

```sh
# ACHTUNG: iLO Remote Console MUSS offen bleiben!
# Risiko: Netzwerk-Verbindung verloren

systemctl restart networking

# Alternativer sicherer Weg:
ifreload -a
```

**Verifikation:**

```sh
ip addr show vmbr_mgmt
# Erwartete Ausgabe: 10.0.10.5/24

ip addr show vmbr_oob
# Erwartete Ausgabe: 172.20.10.10/24

brctl show
# Erwartete Ausgabe: vmbr_mgmt (eno2), vmbr_oob (bge1), vmbr0 (none)

ping 10.0.10.2  # HP Switch
# NOCH KEIN Gateway: Ping wird fehlschlagen (normal)
```

**CHECKPOINT 3:** Alle Bridges konfiguriert.

* * *

## Phase 4: pfSense VM erstellen (45 Minuten)

**Zeitfenster:** 12:00 - 12:45

### 4.1 VM via Proxmox WebGUI erstellen

**Proxmox WebGUI öffnen:**

Da noch kein Routing aktiv ist, muss die WebGUI via **Laptop** erreicht werden (direkt am Switch Port 24):

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
- ISO image: [pfSense-CE-2.8.1-RELEASE-amd64.iso hochladen via iLO oder USB]
- Type: Other
- Guest OS: FreeBSD
- Version: 14.x (oder latest)

System:
- BIOS: OVMF (UEFI)
- Machine: q35
- SCSI Controller: VirtIO SCSI single
- Qemu Agent: ✅ (aktivieren)
- Add EFI Disk: ✅ (Storage: local-zfs, Pre-Enroll keys: NO)

Disks:
- Bus/Device: VirtIO Block (0)
- Storage: local-zfs
- Disk size: 32 GB (ausreichend für pfSense)
- Cache: Write back
- Discard: ✅
- SSD emulation: ✅

CPU:
- Sockets: 1
- Cores: 4 (E3-1230L hat 4C/8T, 4 Cores reichen)
- Type: host (wichtig für Performance)

Memory:
- Memory (MiB): 4096 (4 GB - ausreichend für pfSense mit Paketen)
- Ballooning: ❌ (deaktivieren)

Network:
- Bridge: vmbr_mgmt
- Model: VirtIO (paravirt)
- VLAN Tag: (leer)
- Firewall: ❌ (deaktivieren)
- NOTE: Dies wird die LAN-Schnittstelle (später em0 in pfSense)

Confirm: ✅ Create VM (aber NICHT starten!)
```

### 4.2 PCI Passthrough hinzufügen (Intel eno0 für WAN)

**Via WebGUI:**

```
VM 100 (fw-prod-cz-thor) → Hardware → Add → PCI Device:
- Raw Device: 0000:09:00.0 (Intel 82571EB - eno0)
- All Functions: ❌ (nur diese eine Funktion)
- Primary GPU: ❌
- ROM-Bar: ✅
- PCI-Express: ✅ (wenn verfügbar)

→ Add
```

**Alternative: Via CLI (falls GUI nicht funktioniert):**

```sh
qm set 100 -hostpci0 0000:09:00.0,pcie=1
```

**VM Config prüfen:**

```sh
cat /etc/pve/qemu-server/100.conf

# Erwartete Ausgabe (ähnlich):
# hostpci0: 0000:09:00.0,pcie=1
# net0: virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr_mgmt
```

### 4.3 pfSense Installation

**VM starten:**

```sh
qm start 100
```

**Via Proxmox Console (NoVNC):**

```
VM 100 → Console (NoVNC)

pfSense Installer:
1. Welcome: [Enter] (Accept)
2. Install pfSense: [Enter]
3. Keymap: German / de.kbd → Continue
4. Partitioning: Auto (ZFS) → [Enter]
5. ZFS Configuration:
   - Install: stripe (single disk)
   - Select: ada0 (32 GB VirtIO Disk)
   - Continue: [Enter]
6. Installation läuft... (~3 Minuten)
7. Manual Configuration: No → Reboot
```

**Nach Reboot - Interface Assignment:**

```
pfSense Console Menu:

Available interfaces:
  vtnet0 (VirtIO - vmbr_mgmt)
  igb0   (Intel 82571EB Passthrough - WAN)

VLANs setup now? → n (no)

WAN interface name: igb0 [Enter]
LAN interface name: vtnet0 [Enter]
Optional 1 interface: [Enter] (leer - später konfigurieren)

Proceed? → y

Interfaces assigned:
  WAN  → igb0  (Passthrough NIC → wird zu bge0 on real HW)
  LAN  → vtnet0 (VirtIO Bridge)
```

### 4.4 WAN Interface konfigurieren (temporär DHCP)

```
pfSense Console:
2) Set interface(s) IP address

Enter interface (wan): [Enter]

Configure IPv4 address WAN interface via DHCP? → n (no)
Enter new WAN IPv4 address: 87.236.199.191
Enter WAN IPv4 subnet bit count: 23
Enter new WAN IPv4 upstream gateway address: [Colo Gateway - dokumentiert in pfSense Backup]

Configure IPv6 via DHCP6? → n (no)

Revert to HTTP as webConfigurator protocol? → n (no - HTTPS beibehalten)
```

**WICHTIG:** Nach WAN-Config sollte pfSense WebGUI erreichbar sein.

### 4.5 pfSense Config Restore

**Via Laptop (direkt am LAN Interface):**

```
Temporärer Laptop-IP:
IP: 10.0.10.99/24
Gateway: 10.0.10.1 (pfSense LAN)

Browser öffnen:
https://10.0.10.1

Login:
- Username: admin
- Password: pfsense (default)

Diagnostics → Backup & Restore → Restore Backup:
- Configuration file: [config-fw-prod-cz-thor-20260109.xml hochladen]
- Restore Configuration: ✅
- Reboot: ✅

→ System rebootet (~2 Minuten)
```

**Nach Reboot - Verifikation:**

```
pfSense Console:

Interfaces sollten jetzt sein:
  WAN   → igb0  (87.236.199.191/23)
  LAN   → vtnet0 (10.0.10.1/24)
  MGT   → vtnet0.69 (77.77.77.1/29) - VLAN 69
  VPN   → [muss neu konfiguriert werden - siehe nächster Schritt]
  WG_VPN → tun_wg0 (182.22.16.1/29)
```

**CHECKPOINT 4:** pfSense VM läuft, WAN aktiv, Config restored.

* * *

## Phase 5: Thor Verkabelung (20 Minuten)

**Zeitfenster:** 12:45 - 13:05

### 5.1 WAN-Kabel anschließen

```
HP Switch Port 3 → Thor eno0 (Passthrough NIC - WAN via HP Switch)
```

**ALTERNATIVE (falls direkter WAN Access bevorzugt):**

```
Colo Uplink direkt → Thor eno0 (Bypass Switch)
```

**WICHTIG:** eno0 ist jetzt exklusiv der pfSense VM zugeordnet. Proxmox Host sieht diese NIC NICHT.

### 5.2 Management Link (eno2)

```
HP Switch Port 1 → Thor eno2 (Proxmox Management - vmbr_mgmt)
```

**HP Port 1 als Access Port (VLAN 10) konfigurieren:**

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
# Auf Thor (via iLO Console):
ping 10.0.10.2  # HP Switch
# Erwartete Antwort: < 1ms

ping 10.0.10.1  # pfSense LAN Gateway
# Erwartete Antwort: < 1ms

# Internet-Test (via pfSense Routing):
ping 1.1.1.1
# Erwartete Antwort: ~15ms (sollte jetzt funktionieren!)
```

**CHECKPOINT 5:** Thor vollständig verkabelt, Routing funktioniert.

* * *

## Phase 6: Loki LACP Migration (30 Minuten)

**Zeitfenster:** 13:05 - 13:35

### 6.1 Loki hochfahren (temporär mit Single Link)

**Via iLO ([https://77.77.77.3](https://77.77.77.3)):**

```
Power On Server
```

**Nach Boot - Proxmox Host Login (via SSH 10.0.1.10):**

```sh
# Netzwerk Status:
ip addr show eno1
# Sollte 10.0.1.10/24 haben (alter Zustand)

# VMs/LXCs Status:
qm list
pct list

# NOCH NICHT starten - erst LACP konfigurieren
```

### 6.2 `/etc/network/interfaces` für LACP anpassen

**Backup erstellen:**

```sh
cp /etc/network/interfaces /root/interfaces.backup.$(date +%s)
```

**Neue Konfiguration:**

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

# LACP Bond Interface
auto bond0
iface bond0 inet manual
    bond-slaves eno1 eno2 eno3 eno4
    bond-mode 802.3ad
    bond-miimon 100
    bond-xmit-hash-policy layer3+4
    bond-lacp-rate fast

# VLAN-Aware Bridge (Production Workloads)
auto vmbr0
iface vmbr0 inet static
    address 10.0.30.10/24
    gateway 10.0.30.1
    bridge-ports bond0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 10 20 30
    #LACP Aggregated Bridge - All VLANs

# Internal Storage Bridge (TrueNAS ↔ Plex ↔ arr-stack)
auto vmbr_storage
iface vmbr_storage inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    #Internal Storage - Unlimited Bandwidth (VM-to-VM only, no host IP needed)
```

**WICHTIG:** Gateway ändert sich von `10.0.1.1` (alte LAN) zu `10.0.30.1` (neue VLAN 30 Compute Gateway).

### 6.3 Loki Kabel umstecken

**VORHER:** Nur Port 1 aktiv (eno1 → Dell Switch Port 1)

**NACHHER:**

```
HP Switch Port 9  → Loki eno1
HP Switch Port 10 → Loki eno2
HP Switch Port 11 → Loki eno3
HP Switch Port 12 → Loki eno4
```

**ALLE VIER KABEL gleichzeitig anschließen, dann:**

### 6.4 HP Switch LACP aktivieren

```sh
<HP> system-view

# Bridge-Aggregation2 für Loki (Ports 9-12)
[HP] interface Bridge-Aggregation2
[HP-Bridge-Aggregation2] description Loki-LACP-Bond
[HP-Bridge-Aggregation2] port link-type trunk
[HP-Bridge-Aggregation2] port trunk permit vlan 1 10 20 30
[HP-Bridge-Aggregation2] link-aggregation mode dynamic
[HP-Bridge-Aggregation2] quit

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

### 6.5 Loki Netzwerk neu starten

```sh
# Via iLO Remote Console (sicher):
systemctl restart networking

# Verifikation:
ip addr show bond0
# Sollte "master" zeigen, KEIN IP (wird von vmbr0 genutzt)

ip addr show vmbr0
# Sollte 10.0.30.10/24 zeigen

cat /proc/net/bonding/bond0
# Erwartete Ausgabe:
# Bonding Mode: IEEE 802.3ad Dynamic link aggregation
# MII Status: up
# Aggregator ID: 1
# Number of ports: 4
# Slave Interface: eno1
# Slave Interface: eno2
# Slave Interface: eno3
# Slave Interface: eno4
```

**HP Switch LACP Status prüfen:**

```sh
<HP> display link-aggregation summary

# Erwartete Ausgabe:
# Bridge-Aggregation2: UP
# Selected ports: GE1/0/9, GE1/0/10, GE1/0/11, GE1/0/12
```

**CHECKPOINT 6:** Loki LACP aktiv, 4 Gbps aggregiert.

* * *

## Phase 7: pfSense VLAN & Firewall Config (45 Minuten)

**Zeitfenster:** 13:35 - 14:20

### 7.1 pfSense VM - zusätzliche VirtIO NICs hinzufügen

**Problem:** Config Restore hat die alten physischen Interfaces importiert. Neue VM braucht separate VirtIO NICs für VLANs.

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

**VM Config prüfen:**

```sh
cat /etc/pve/qemu-server/100.conf

# Erwartete Ausgabe:
# net0: virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr_mgmt (LAN - VLAN 10 untagged)
# net1: virtio=YY:YY:YY:YY:YY:YY,bridge=vmbr_mgmt,tag=20 (Production - VLAN 20)
# net2: virtio=ZZ:ZZ:ZZ:ZZ:ZZ:ZZ,bridge=vmbr_mgmt,tag=30 (Compute - VLAN 30)
```

**pfSense VM rebooten:**

```sh
qm reboot 100
```

### 7.2 pfSense Interface Assignment

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

### 7.3 DHCP Server aktivieren (VLANs)

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

### 7.4 Firewall Rules (Basic Allow All - für Testing)

**WARNUNG:** Diese Rules erlauben ALLES. Später einschränken!

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

**CHECKPOINT 7:** pfSense VLANs konfiguriert, Routing aktiv.

* * *

## Phase 8: VM/LXC Migration (60 Minuten)

**Zeitfenster:** 14:20 - 15:20

### 8.1 IP-Adressen-Mapping planen

**Alte IPs (10.0.1.x) → Neue IPs (VLAN 20/30):**

| VMID | Name           | Alt IP    | Neu IP        | VLAN |
| ---- | -------------- | --------- | ------------- | ---- |
| 4000 | truenas        | 10.0.1.20 | 10.0.30.20/24 | 30   |
| 1000 | pms-prod-cz-01 | 10.0.1.30 | 10.0.20.30/24 | 20   |
| 2000 | docker-prod    | 10.0.1.40 | 10.0.30.40/24 | 30   |
| 8000 | nextcloud      | 10.0.1.70 | 10.0.20.70/24 | 20   |
| 1100 | the-arr-stack  | 10.0.1.90 | 10.0.30.90/24 | 30   |

### 8.2 TrueNAS VM migrieren (VMID 4000)

**Proxmox WebGUI:**

```
VM 4000 (truenas) → Hardware:

net0 → Edit:
- Bridge: vmbr0
- VLAN Tag: 30
- Model: VirtIO (unverändert)
- Save

Add → Network Device (net1 - Storage):
- Bridge: vmbr_storage
- VLAN Tag: (leer)
- Model: VirtIO
- Save
```

**VM starten:**

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

**Verifikation (nach Reboot):**

```
Browser: https://10.0.30.20

TrueNAS Login testen
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
# VM starten
qm start 1000

# Console Login
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
ping 10.0.20.1  # Gateway
ping 10.10.10.1  # TrueNAS Storage
```

**Plex Testen:**

```
Browser: http://10.0.20.30:32400/web
```

### 8.4 Weitere VMs analog migrieren

**Shortcuts (für alle verbleibenden VMs):**

```sh
# docker-prod (VMID 2000) → VLAN 30
qm set 2000 -net0 virtio,bridge=vmbr0,tag=30
# Interne IP: 10.0.30.40/24 (via Netplan)

# nextcloud (VMID 8000) → VLAN 20
qm set 8000 -net0 virtio,bridge=vmbr0,tag=20
# Interne IP: 10.0.20.70/24

# the-arr-stack (VMID 1100) → VLAN 30 + vmbr_storage
qm set 1100 -net0 virtio,bridge=vmbr0,tag=30
qm set 1100 -net1 virtio,bridge=vmbr_storage
# ens18: 10.0.30.90/24
# ens19: 10.10.10.3/24
```

**Jede VM einzeln starten, IP konfigurieren, testen.**

### 8.5 LXCs migrieren (schneller)

**LXC Network Config ist einfacher (via Proxmox GUI):**

```
LXC 3000 (prometheus) → Network:
- net0: name=eth0, bridge=vmbr0, tag=30, ip=10.0.30.80/24, gw=10.0.30.1

LXC 3002 (influxdb):
- net0: bridge=vmbr0, tag=30, ip=10.0.30.82/24, gw=10.0.30.1

LXC 5000 (ptero-panel-prod):
- net0: bridge=vmbr0, tag=30, ip=10.0.30.100/24, gw=10.0.30.1

# etc. für alle LXCs
```

**Batch-Start:**

```sh
for ctid in 3000 3002 5000 5001 5050 6000 6100; do
    pct start $ctid
done
```

**CHECKPOINT 8:** Alle VMs/LXCs laufen in neuen VLANs.

* * *

## Phase 9: WireGuard OOB Gateway LXC (30 Minuten)

**Zeitfenster:** 15:20 - 15:50

### 9.1 LXC erstellen

**Proxmox WebGUI:**

```
Create CT:
- Node: pve-prod-cz-thor
- CT ID: 9100
- Hostname: wg-oob-gateway
- Password: [sicheres PW]
- Template: debian-12-standard
- Disk: 4 GB
- CPU: 1 Core
- Memory: 256 MB
- Network:
  - net0: name=eth0, bridge=vmbr_mgmt, tag=10, ip=10.0.10.100/24, gw=10.0.10.1
  - net1: name=eth1, bridge=vmbr_oob, ip=172.20.10.100/24, gw=(leer)

Options:
- Start at boot: ✅
- Unprivileged: ✅

Create
```

### 9.2 WireGuard installieren & konfigurieren

**LXC starten & Console:**

```sh
pct start 9100
pct enter 9100

# Updates
apt update && apt upgrade -y

# WireGuard installieren
apt install -y wireguard iptables

# Kernel Module (im Host laden - einmalig)
# Auf Thor Proxmox Host:
modprobe wireguard
echo "wireguard" >> /etc/modules

# Im LXC:
cd /etc/wireguard

# Keys generieren
wg genkey | tee privatekey | wg pubkey > publickey

# WireGuard Config
nano wg0.conf
```

**wg0.conf Inhalt:**

```toml
[Interface]
PrivateKey = <Inhalt von privatekey>
Address = 172.20.10.100/24
ListenPort = 51820

# IP Forwarding aktivieren
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp = iptables -A FORWARD -o wg0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth1 -j MASQUERADE

# Client-Peers (Beispiel - User Laptop):
[Peer]
PublicKey = <Laptop Public Key>
AllowedIPs = 172.20.10.200/32
```

**IP Forwarding permanent aktivieren:**

```sh
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

**WireGuard starten:**

```sh
wg-quick up wg0
systemctl enable wg-quick@wg0
```

**Test:**

```sh
# Im LXC:
ping 172.20.10.1  # Colo VPN Gateway (via bge1)

# Von User Laptop (nach WireGuard Client Config):
ping 172.20.10.100  # LXC
ping 77.77.77.2  # Thor iLO (via OOB Gateway!)
```

**CHECKPOINT 9:** WireGuard OOB Gateway aktiv, iLO-Zugriff gesichert.

* * *

## Phase 10: Final Validation (30 Minuten)

**Zeitfenster:** 15:50 - 16:20

### 10.1 Connectivity Tests

**Von Loki Proxmox Host:**

```sh
# VLAN 10 (Management)
ping 10.0.10.1   # pfSense Gateway ✅
ping 10.0.10.2   # HP Switch ✅
ping 10.0.10.5   # Thor Proxmox ✅
ping 10.0.10.100 # WireGuard OOB LXC ✅

# VLAN 30 (Compute - eigenes Netz)
ping 10.0.30.1   # pfSense Gateway ✅
ping 10.0.30.20  # TrueNAS ✅

# Internet
ping 1.1.1.1     # Cloudflare ✅
curl -I https://google.com  # HTTP Test ✅
```

**Von TrueNAS VM:**

```sh
ping 10.0.30.1         # Gateway ✅
ping 10.10.10.2        # Plex Storage NIC ✅
ping 10.10.10.3        # arr-stack Storage NIC ✅
ping 1.1.1.1           # Internet ✅
```

**Von Plex VM:**

```sh
ping 10.0.20.1         # Production Gateway ✅
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
| WireGuard VPN  | `ping 182.22.16.1` (von User Laptop)                         | Reply ✅              |
| OOB Gateway    | `ping 77.77.77.2` (via WireGuard OOB)                        | Thor iLO reachable ✅ |

### 10.3 Performance Tests

**LACP Bandwidth:**

```sh
# Auf Loki Host:
iperf3 -s

# Auf Thor Host:
iperf3 -c 10.0.30.10 -t 30 -P 4

# Erwartete Ergebnis: ~3.7 Gbps aggregiert (4x 1 GbE mit Overhead)
```

**Storage Performance (vmbr_storage):**

```sh
# Auf Plex VM:
dd if=/dev/zero of=/mnt/truenas/testfile bs=1G count=5 oflag=direct

# Erwartete Geschwindigkeit: > 500 MB/s (virtueller Bridge, kein NIC Limit)
```

### 10.4 Switch Status

```sh
<HP> display link-aggregation summary

# Erwartete Ausgabe:
# BAGG2: UP (Loki - 4 ports selected)

<HP> display interface brief

# Alle Ports UP:
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
- Traffic: RX/TX aktiv ✅

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

**CHECKPOINT 10:** Alle Services funktional, Performance validiert.

* * *

## Rollback-Prozedur (Bei kritischem Fehler)

**Trigger:** Kritischer Service-Ausfall > 30 Minuten ungelöst.

### Rollback Schritt 1: VMs/LXCs stoppen

```sh
# Auf Loki:
for vmid in $(qm list | awk '{print $1}' | grep -v VMID); do
    qm shutdown $vmid --timeout 60 --forceStop 1
done

for ctid in $(pct list | awk '{print $1}' | grep -v VMID); do
    pct shutdown $ctid
done
```

### Rollback Schritt 2: Thor herunterfahren

```sh
# Thor pfSense VM:
qm shutdown 100 --timeout 60

# Thor Proxmox Host:
shutdown -h now
```

### Rollback Schritt 3: Dell Switch reinstallieren

```
1. HP Switch stromlos
2. Dell Switch anschließen
3. Alte Verkabelung wiederherstellen:
   - Port 1: Loki eno1
   - Port 17-18: iLOs
   - Port 23: Thor em0 (LAN)
   - Port 24: Laptop

4. Thor hochfahren (bare metal pfSense bootet automatisch)
5. Loki hochfahren (alte /etc/network/interfaces via Backup)
```

### Rollback Schritt 4: Verifikation

```sh
# Thor pfSense:
# Sollte automatisch booten mit alter Config

# Loki:
# Falls neue Config aktiv:
cp /root/interfaces.backup.XXXXX /etc/network/interfaces
systemctl restart networking

# VMs starten:
qm start 4000  # TrueNAS
qm start 1000  # Plex
# etc.
```

**Rollback-Zeit:** ~30 Minuten **Datenverlust:** Keiner (nur Config-Änderungen zurückgesetzt)

* * *

## Post-Migration Tasks

### Innerhalb 24 Stunden:

- [ ] **Dell Switch sicher aufbewahren** (als Backup-Hardware)

- [ ] **Monitoring Dashboards aktualisieren** (neue IPs)

- [ ] **DNS Records prüfen** (falls statische IPs genutzt)

- [ ] **Backup-Jobs testen** (neue Netzwerk-Pfade)

- [ ] **Dokumentation aktualisieren:**
  
  - [ ] 01-current-state.md → archivieren
  - [ ] 02-target-state.md → in "01-current-state.md" umbenennen

### Innerhalb 1 Woche:

- [ ] **Firewall-Rules härten** (aktuelle "Allow All" entfernen)
- [ ] **VLAN Segmentation testen** (Inter-VLAN Isolation)
- [ ] **OOB Gateway für produktiven Einsatz freigeben**
- [ ] **Performance-Monitoring einrichten** (LACP Bandwidth Grafana Dashboard)
- [ ] **Hetzner Storage Box Backup konfigurieren**

### Innerhalb 1 Monat:

- [ ] **Reverse Proxy LXC erstellen** (Traefik/Caddy für SSL Termination)
- [ ] **Let's Encrypt Wildcard Cert automatisieren**
- [ ] **Pterodactyl auf neue IPs migrieren** (wenn stabil)
- [ ] **Load Testing** (Plex simultane Streams + arr-stack Downloads)

* * *

## Troubleshooting Guide

### Problem: Proxmox Host kein Internet

**Symptom:** `ping 1.1.1.1` failed

**Diagnose:**

```sh
ip route show
# Gateway fehlt?

ping 10.0.10.1
# pfSense erreichbar?
```

**Fix:**

```sh
ip route add default via 10.0.10.1 dev vmbr_mgmt
# Permanent in /etc/network/interfaces eintragen
```

* * *

### Problem: LACP nicht aktiv

**Symptom:** Nur 1 Port aktiv, andere DOWN

**Diagnose:**

```sh
# Auf Loki:
cat /proc/net/bonding/bond0
# "Aggregator ID" sollte identisch für alle Slaves sein

# Auf HP Switch:
<HP> display link-aggregation verbose Bridge-Aggregation2
# "Selected" sollte alle 4 Ports zeigen
```

**Fix:**

```sh
# LACP Mode prüfen:
[HP] interface Bridge-Aggregation2
[HP-Bridge-Aggregation2] display this
# "link-aggregation mode dynamic" muss vorhanden sein

# Falls "static":
[HP-Bridge-Aggregation2] undo link-aggregation mode
[HP-Bridge-Aggregation2] link-aggregation mode dynamic
[HP-Bridge-Aggregation2] quit
[HP] save
```

* * *

### Problem: pfSense VM bootet nicht

**Symptom:** VM stuck at "Booting..."

**Diagnose:**

```sh
# Via Proxmox Console:
qm terminal 100

# UEFI Boot Order prüfen:
# Boot Menu sollte "virtio0" (Disk) zeigen

# Falls CD/DVD Boot:
qm set 100 -boot order=virtio0
qm reboot 100
```

**Fix (Worst Case - Config manuell importieren):**

```sh
# pfSense neu installieren (siehe Phase 4.3)
# Nach Installation: Config Restore via WebGUI
```

* * *

### Problem: NIC Passthrough failed

**Symptom:** `vfio-pci` nicht gebunden, `e1000e` aktiv

**Diagnose:**

```sh
lspci -k -s 09:00.0
# "Kernel driver in use: e1000e" → Fehler!
```

**Fix:**

```sh
# Module Blacklist:
echo "blacklist e1000e" >> /etc/modprobe.d/blacklist.conf

# VFIO neu binden:
echo "8086 105e" > /sys/bus/pci/drivers/vfio-pci/new_id

# initramfs neu generieren:
update-initramfs -u -k all
reboot
```

* * *

### Problem: VMs haben kein Internet

**Symptom:** `ping 1.1.1.1` failed in VM

**Diagnose:**

```sh
# In VM:
ip route show
# Gateway korrekt (10.0.20.1 / 10.0.30.1)?

# Auf pfSense:
pfSense WebGUI → Firewall → Rules
# "Default deny all" aktiv?

# NAT prüfen:
Firewall → NAT → Outbound
# Auto-NAT für neue VLANs?
```

**Fix:**

```sh
# pfSense Firewall Rules:
Firewall → Rules → PROD/COMPUTE
# "Allow all" Regel temporär hinzufügen (siehe Phase 7.4)

# Outbound NAT:
Firewall → NAT → Outbound
# Mode: Automatic (sollte auto-NAT für 10.0.20.0/24 und 10.0.30.0/24 erstellen)
```

* * *

## Contact & Escalation

**On-Site Support:** Keine verfügbar (Colo Prague) **Remote Support:** iLO + WireGuard OOB Gateway **Backup Contact:** \[Telefonnummer Colo Betreiber\]

**Eskalation:**

1. **Kritischer Fehler:** Rollback innerhalb 30 Min starten (siehe Rollback-Prozedur)
2. **Nicht-kritisch:** Issue dokumentieren, nach Migration fixen
3. **Unbekanntes Problem:** Screenshot + Logs sammeln, remote analysieren

* * *

## Checkliste: Migration abgeschlossen

- [ ] **Alle VMs laufen** (qm list → 5/5 running)
- [ ] **Alle LXCs laufen** (pct list → 9/9 running)
- [ ] **LACP aktiv** (4 Gbps Aggregation validiert)
- [ ] **pfSense Routing** (alle VLANs haben Internet)
- [ ] **Services erreichbar** (Plex, Nextcloud, Pterodactyl getestet)
- [ ] **iLO via OOB Gateway** (WireGuard funktional)
- [ ] **Performance validiert** (iperf3 Tests erfolgreich)
- [ ] **Backups gesichert** (pfSense config.xml, VM backups vorhanden)
- [ ] **Dokumentation aktualisiert** (neue IPs, Port Mapping)
- [ ] **Dell Switch gesichert** (als Rollback-Hardware aufbewahrt)

* * *

**Dokument Version:** 1.0 **Erstellt:** 2026-01-09 **Zuletzt geprüft:** \[Datum nach Pre-Flight Check\] **Status:** READY FOR EXECUTION

* * *

**Hinweis:** Dieses Dokument vor Ort ausdrucken und während der Migration Schritt für Schritt abhaken. Bei Abweichungen sofort dokumentieren.