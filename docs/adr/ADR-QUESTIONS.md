<!-- LAST EDITED: 2026-01-27 -->
<!-- markdownlint-disable MD013 -->

# ADR-Fragen

Fragen zur Erstellung von Architecture Decision Records (ADRs).
Schreib deine Antworten unter jede Frage - daraus machen wir dann richtige ADRs.

---

## Block 1: CI/CD Strategie

### Q1.1: Self-hosted Runner vs GitHub-hosted

**Warum hast du einen self-hosted Runner (`github-runner-prod-cz-01`) gewählt statt GitHubs kostenlose Standard-Runner?**

Welches konkrete Problem mit dem Zugriff auf dein Proxmox-Netzwerk löst das?

**Deine Antwort:**
GitHub-hosted Runner laufen in GitHubs Cloud und haben keinen Netzwerkzugang zu meiner Infrastruktur in der Colocation. Um Terraform und Ansible gegen meine Proxmox-Hosts auszuführen, brauche ich einen Runner der innerhalb meines Netzwerks läuft und die APIs erreichen kann. Der Self-hosted Runner ist damit die einzige Möglichkeit, CI/CD-Pipelines für meine private Infrastruktur über GitHub zu betreiben.

---

### Q1.2: Runner Sicherheits-Abwägung

**Ein Runner in deinem privaten Netzwerk ist ein Sicherheitsrisiko. Warum ist es akzeptabel, dass dieser LXC-Container direkten Zugriff auf deine Proxmox API hat?**

**Deine Antwort:**
Das Risiko war mir vor dieser Recherche nicht bewusst. Das Problem ist, dass jeder Code der durch Workflows ausgeführt wird auf dem Runner läuft, und bei einem kompromittierten PR oder einer malicious Dependency hätte ein Angreifer direkten Zugang zur Proxmox API. Aktuell habe ich keine Mitigations implementiert. Als TODO nehme ich mir vor, den Runner nach der VLAN-Migration in ein isoliertes Segment mit eingeschränktem Routing zu setzen, einen dedizierten API-Token mit minimalen Permissions statt Root zu nutzen, und Workflows nur auf protected Branches mit PR-Approval auszuführen. Zusätzlich werde ich auf einen Docker-basierten ephemeral Runner umsteigen, damit ein Angreifer zumindest keinen persistenten Zugang nach einem Job behält.

---

### Q1.3: Ansible für Runner Setup

**Warum nutzt du Ansible um den Runner zu bauen, statt ein fertiges Docker-Image?**

(Referenz: `ansible/roles/github-runner/tasks/main.yml`)

**Deine Antwort:**
Für einen einzelnen persistenten Runner auf einer dedizierten VM ist Ansible der pragmatischere Ansatz. Der Runner behält seinen State zwischen Jobs (Build-Caches, vorinstallierte Tools) und ich kann bei Problemen direkt per SSH debuggen. Ein Docker-basierter ephemeral Runner wäre sinnvoll wenn ich horizontale Skalierung oder garantiert sauberen State pro Job bräuchte, aber für mein aktuelles Setup mit einem Runner ist der Mehraufwand nicht gerechtfertigt. Die Ansible-Rolle ist bereits geschrieben und dokumentiert das Setup reproduzierbar.

---

## Block 2: Netzwerk & Migration

### Q2.1: VLAN-Entscheidung

**Im target-state planst du VLAN 10 (Management), 20 (Production) und 30 (Compute). Warum reicht das aktuelle Flat Network nicht mehr aus?**

Welchen konkreten Vorteil erhoffst du dir von der Trennung?

**Deine Antwort:**
Im aktuellen Flat Network gibt es keine Isolation zwischen VMs und LXCs, was laterale Bewegung bei einer Kompromittierung ermöglicht. Ein Angreifer der einen Container übernimmt, hat direkten Netzwerkzugang zu allen anderen Systemen inklusive Management-Interfaces. Die VLAN-Segmentierung erlaubt mir, Traffic zwischen den Segmenten über pfSense zu routen und dort Firewall-Regeln durchzusetzen. Management-Traffic ist dann komplett isoliert, Production-Services erreichen nur was sie brauchen, und Compute-Workloads haben keinen direkten Zugang zu kritischer Infrastruktur.

---

### Q2.2: Hardware-Abhängigkeit

**Warum ist der HP 1910-24G Switch für LACP-Bonding und VLANs erforderlich? Könnte man das nicht auch mit dem alten Dell-Switch machen?**

**Deine Antwort:**
Der Dell PowerConnect 2824 in der Colo ist ein "Web-Smart" Switch mit eingeschränktem Funktionsumfang und unterstützt kein vollständiges LACP-Bonding. Zusätzlich ist er aktuell remote nicht erreichbar, da Port 24 für das Management-VLAN physisch belegt ist und ich mangels Funktionsumfang keinen Wert auf Remote-Zugang gelegt hatte. Der HP 1910-24G ist ein vollwertiger Managed Switch mit LACP und 802.1Q VLAN-Support, was für das geplante Netzwerk-Setup mit redundanten Uplinks und sauberer VLAN-Segmentierung erforderlich ist.

---

### Q2.3: Migrations-Taktik

**Warum zwei separate Terraform-Verzeichnisse (`current-state` vs `target-state`) statt Terraform Workspaces oder verschiedene Branch-Strukturen?**

**Deine Antwort:**
Workspaces sind für identischen Code in verschiedenen Environments gedacht, nicht für eine Migration von Ist- zu Soll-Zustand. Zwei separate Verzeichnisse erlauben mir, bestehende Ressourcen sicher in current-state zu importieren und zu dokumentieren, während ich target-state unabhängig davon aufbaue. So kann ich beide States vergleichen, die Migration schrittweise planen und habe kein Risiko versehentlich Produktiv-Infrastruktur zu zerstören. Nach Abschluss der Migration wird current-state archiviert und target-state wird zum einzigen aktiven Verzeichnis.

---

## Block 3: Secrets & Vault

### Q3.1: Vault vs Ansible Vault

**Warum soll Ansible Secrets direkt aus Vault holen, statt `ansible-vault` (verschlüsselte Dateien im Repo) zu nutzen?**

**Deine Antwort:**
Ansible Vault verschlüsselt Secrets statisch im Repo, was für kleine Projekte ausreicht aber keine Rotation, Audit-Trails oder zentrales Revoken ermöglicht. HashiCorp Vault als zentraler Secrets-Server erlaubt dynamische Secrets mit automatischem Ablauf, vollständige Audit-Logs wer wann was abgefragt hat, und sofortiges Sperren aller Credentials bei Kompromittierung. Da ich ohnehin Infrastruktur für Self-Hosting betreibe, ist der Mehraufwand für Vault überschaubar und demonstriert im Portfolio Enterprise-Patterns die bei Ansible Vault nicht möglich wären.

---

### Q3.2: Bootstrap-Problem

**Warum nur Vault-Credentials in GitHub Secrets speichern, statt alle Passwörter direkt in GitHub?**

**Deine Antwort:**
Das Bootstrap-Problem lässt sich nicht komplett eliminieren, da irgendetwas den initialen Zugang zu Vault herstellen muss. Der entscheidende Unterschied ist der Blast Radius: Wenn GitHub kompromittiert wird und dort nur Vault-Credentials liegen, hat der Angreifer Zugang zu einem System mit Audit-Logs, Lease-Zeiten und Revocation-Möglichkeiten. Liegen alle Secrets direkt in GitHub, gibt es keine zentrale Stelle zum Rotieren oder Sperren. Vault ermöglicht außerdem dynamische Secrets die nach Nutzung automatisch ablaufen, während GitHub Secrets statisch sind und manuell rotiert werden müssen. Das Bootstrap-Secret ist damit der einzige statische Einstiegspunkt, alles dahinter kann kurzlebig und auditierbar sein.

---

## Block 4: Terraform & Provider-Wahl

### Q4.1: bpg/proxmox vs telmate/proxmox

**Warum hast du den `bpg/proxmox` Provider (v0.91.0) gewählt statt den älteren `telmate/proxmox`?**

**Deine Antwort:**
Der `bpg/proxmox` Provider bietet deutlich aktivere Entwicklung mit 163 stabilen Releases gegenüber 48 bei Telmate, dessen aktuelle Version seit Monaten im RC-Status verharrt. Während beide Provider Proxmox 8.x unterstützen, zeigt Telmate mehrere dokumentierte Panic-Issues (nil map bei LXC clone, interface conversion errors), die auf grundlegende Stabilitätsprobleme hindeuten. Der bpg-Provider nutzt zudem das moderne Terraform Plugin Framework und unterstützt explizit OpenTofu als Alternative. Auch das Issue-Management ist bei bpg professioneller strukturiert mit klaren Labels und Priorisierung über Reactions.

---

### Q4.2: Terraform Cloud vs Self-hosted Backend

**Warum Terraform Cloud statt S3-Backend oder selbst gehosteter State?**

Was sind die Trade-offs (Kosten, Sicherheit, Vendor Lock-in)?

**Deine Antwort:**
Aktuell nutze ich noch HCP Terraform Cloud, werde aber zeitnah auf einen Hybrid-Ansatz migrieren: S3 in Frankfurt als Primary Backend und MinIO auf meinem TrueNAS als DR und lokale Dev-Umgebung. Der Free Tier wird zum 31. März 2026 eingestellt und das neue RUM-Pricing (ca. 0,10 USD pro Ressource/Monat) skaliert bei 200+ Ressourcen schnell auf 20-50 USD monatlich, während S3 unter 0,20 EUR/Monat kostet. Seit Terraform 1.10 ist DynamoDB für Locking deprecated und native S3-Locks über use_lockfile = true vereinfachen den Setup erheblich. MinIO als Backup zeigt zusätzlich Self-Hosting-Skills und S3-Kompatibilität on-prem, während die Kombination aus EU-Datenresidenz, keinem Vendor Lock-in und OpenTofu-Kompatibilität den Hybrid-Ansatz zur besten Lösung für mein Portfolio macht.

---

### Q4.3: TLS Insecure Mode

**Warum ist `proxmox_tls_insecure = true` der Standard? Ist das Proxmox-Zertifikat selbstsigniert?**

Könntest/solltest du richtige CA-signierte Zertifikate nutzen?

**Deine Antwort:**
Der Terraform Provider verbindet sich aktuell direkt zur Proxmox-IP mit dem selbstsignierten Zertifikat. Über HAProxy habe ich bereits ein valides Let's Encrypt Wildcard-Zertifikat eingerichtet und DNS löst intern korrekt auf die pfSense auf. Als TODO nehme ich mir vor, den API-Endpoint in Vault von der direkten IP auf die Domain umzustellen und dann insecure = false zu setzen.

---

## Block 5: Infrastruktur-Design

### Q5.1: Lifecycle Ignore Changes

**Warum ignorierst du `network_device`, `disk`, `efi_disk`, `boot_order` im VM-Modul Lifecycle?**

(Referenz: `terraform/modules/proxmox-vm/main.tf`)

**Deine Antwort:**
Diese ignore_changes habe ich beim initialen Modul-Setup übernommen um bekannte Provider-Quirks zu umgehen. Proxmox-Provider zeigen oft Drift bei Attributen die sich zwischen API-Response und Terraform-State unterscheiden, selbst wenn sich real nichts geändert hat. Als TODO nehme ich mir vor, diese Workarounds im Rahmen eines Tech Debt Cleanups zu revisiten und so viele Attribute wie möglich wieder unter Terraform-Verwaltung zu bringen.

---

### Q5.2: LXC vs VM Entscheidung

**Wann nutzt du LXC-Container vs vollwertige VMs? Was sind die Entscheidungskriterien?**

(z.B. GitHub Runner ist LXC, TrueNAS ist VM mit PCI Passthrough)

**Deine Antwort:**
VMs nutze ich wenn PCI/GPU Passthrough nötig ist (Plex für Hardware-Transcoding, TrueNAS für HBA-Durchleitung), wenn eigene Kernel-Features gebraucht werden (Docker, ZFS), oder bei I/O-intensiven Workloads die von Raw Performance profitieren. Alles andere läuft als LXC weil sie weniger Overhead haben, schneller starten und Ressourcen mit dem Host teilen. Nach weiterer Recherche gibt es zusätzliche Kriterien die ich bisher nicht konsequent angewendet habe: LXCs teilen den Host-Kernel und bieten damit schwächere Isolation als VMs mit Hypervisor-Grenze, was besonders für sicherheitskritische Workloads relevant ist. Aktuell läuft beispielsweise Vault als LXC, obwohl Secrets-Management maximale Isolation verdient. Als TODO nehme ich mir vor, alle sicherheitsrelevanten Workloads zu revisiten und gegebenenfalls auf VMs umzubauen, privileged vs unprivileged LXC-Konfigurationen zu prüfen, und Pterodactyl Wings für bessere Gameserver-Performance auf eine VM zu migrieren.

---

### Q5.3: PCI Passthrough Strategie

**Warum PCI Passthrough für HBA-Controller (TrueNAS) statt virtueller Disks?**

**Deine Antwort:**
ZFS braucht direkten Zugriff auf die physischen Platten um korrekt zu funktionieren. Der HBA-Controller ist an ein NetApp DS4246 Disk Shelf angeschlossen und wird komplett an die TrueNAS VM durchgereicht. Das ermöglicht SMART-Monitoring für Disk-Health-Warnungen, lässt ZFS sein eigenes Caching und Write-Policies kontrollieren ohne Virtualisierungs-Overhead, und macht Disk-Austausch bei Plattenausfall eindeutig identifizierbar. Mit virtuellen Disks würde ZFS blind gegenüber der Hardware laufen und könnte bei Stromausfall Daten verlieren.

---

## Block 6: CI/CD Details

### Q6.1: Concurrency-Strategien

**Warum unterschiedliche Concurrency-Strategien für verschiedene Workflows?**

- Drift: `cancel-in-progress: false` (Queue)
- Plan: `cancel-in-progress: true` (alte abbrechen)
- Apply: `cancel-in-progress: false` (Queue)

**Meine bisherige Antwort:**
Bei Drift-Checks und Apply wird gequeued statt abgebrochen weil jeder Check durchlaufen soll und ein abgebrochener Apply Infrastruktur inkonsistent hinterlassen könnte. Bei Plan wird abgebrochen weil ein neuer Commit den alten Plan ohnehin obsolet macht und es keinen Sinn ergibt, veralteten Code zu validieren.

---

### Q6.2: Drift-Erkennung via GitHub Issues

**Warum automatische GitHub Issues für Drift statt Slack/Email/PagerDuty Alerts?**

**Deine Antwort:**
GitHub Issues sind kostenlos, direkt im Repository wo auch der Code liegt, und erzeugen einen nachvollziehbaren Record der assigned, gelabelt und bei Fix geschlossen werden kann. Slack würde zusätzliche Kosten und ein weiteres Tool bedeuten, Email geht in der Masse unter. Für ein Solo-Portfolio-Projekt ist die Integration in GitHub der pragmatischste Ansatz.

---

### Q6.3: Pre-commit Hooks vs nur CI

**Warum umfangreiche lokale Pre-commit Hooks statt nur CI/CD Checks?**

Warum ist `terraform_docs` deaktiviert?

**Deine Antwort:**
Pre-commit Hooks geben schnelleres Feedback vor dem Push statt erst im CI, sparen CI-Runs und halten die Git-History sauber weil Fehler gar nicht erst committed werden. terraform_docs ist deaktiviert weil es automatisch READMEs modifiziert, was während pre-commit zu unerwarteten Änderungen nach dem Staging führt. Als TODO nehme ich mir vor zu evaluieren ob terraform_docs besser in CI läuft statt lokal.

---

## Block 7: Backup & Monitoring

### Q7.1: Borgmatic vs Proxmox vzdump

**Warum Borgmatic für Anwendungs-Backups statt nur auf Proxmox's natives vzdump zu setzen?**

**Deine Antwort:**
Ich plane beides zu nutzen weil sie unterschiedliche Ebenen abdecken. vzdump mit PBS macht VM-Level Snapshots für schnelle Wiederherstellung ganzer Maschinen, während Borgmatic Anwendungs-Level Backups mit Deduplication und Verschlüsselung bietet für granulare Restores einzelner Dateien oder Datenbanken. Aktuell fehlt mir ein PBS, als TODO plane ich einen günstigen Tower-Server in der gleichen Colo unterzubringen und bei Coolhousing anzufragen ob dieser ins selbe interne Netz wie mein bestehendes Rack kann damit der Backup-Traffic intern bleibt.

---

### Q7.2: Prometheus vs InfluxDB

**Warum Prometheus für Metriken statt InfluxDB oder andere Alternativen?**

**Deine Antwort:**
Ich nutze beide weil sie unterschiedliche Zwecke erfüllen. Prometheus ist pull-based und eignet sich für Infrastruktur-Metriken mit Node Exporter und Alertmanager-Integration. InfluxDB ist push-based und läuft bei mir primär für Varken um Plex und den Arr-Stack zu monitoren. Die Kombination deckt sowohl System-Monitoring als auch spezifische Anwendungs-Metriken ab.

---

### Q7.3: ntfy für Benachrichtigungen

**Warum ntfy für Backup-Benachrichtigungen statt Email/Slack/Pushover?**

**Deine Antwort:**
ntfy war was ich initial eingerichtet hatte, aber ich finde es mittlerweile limitiert. Als TODO nehme ich mir vor auf Apprise umzusteigen, das über 80 Notification-Services unterstützt (Telegram, Discord, Email, Pushover, ntfy) und direkt mit Borgmatic integrierbar ist. Mit einer Konfiguration kann ich dann multiple Outputs bespielen und habe Fallbacks wenn ein Service ausfällt.

---

## Block 8: Modul- & Code-Struktur

### Q8.1: Separate Module vs Inline

**Warum separate `proxmox-vm` und `proxmox-lxc` Module statt Inline-Konfigurationen?**

Könnten diese in einer Terraform Registry veröffentlicht werden?

**Deine Antwort:**
Separate Module vermeiden Wiederholung bei aktuell 5 VMs und 15 LXCs. Änderungen am Modul wirken sofort auf alle Instanzen, ein Fix muss nur einmal gemacht werden statt an 20 Stellen. Die Module könnten theoretisch in der Terraform Registry veröffentlicht werden, allerdings sind sie aktuell sehr spezifisch auf mein Setup zugeschnitten. Als TODO könnte ich die Module generischer gestalten und veröffentlichen falls andere Proxmox-Nutzer davon profitieren würden.

---

### Q8.2: Modul-Versionierung

**Wie gehst du mit Breaking Changes in Modulen um, wenn beide Environments sie nutzen?**

**Deine Antwort:**
Aktuell nutzen beide Environments dieselben Module via relative Pfade ohne Versionierung, was bedeutet dass Änderungen sofort beide betreffen. Als TODO nehme ich mir vor, Semantic Versioning mit Git Tags einzuführen bevor ich die Module weiter ausbaue. PATCH für Bug Fixes, MINOR für neue optionale Features, MAJOR für Breaking Changes. So kann ich Environments auf stabile Versionen pinnen und unabhängig voneinander migrieren statt dass ein Fix versehentlich beide bricht.

---
