````markdown
# 🇹🇷 Linux Türkçeleştirme + Pentest Kurulum Aracı

![Linux](https://img.shields.io/badge/Linux-Kali%20%7C%20Debian%20%7C%20Ubuntu-blue)
![Version](https://img.shields.io/badge/version-2026.8-green)
![Shell](https://img.shields.io/badge/Shell-Bash-orange)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

Kali Linux, Debian ve Ubuntu tabanlı sistemleri Türkçeleştirmek ve
yetkili güvenlik testleri, CTF ve laboratuvar çalışmaları için gerekli
pentest araçlarını tek bir Bash scripti ile kurmak için hazırlanmıştır.

---

## ✨ Özellikler

Script çalıştırıldığında yalnızca iki seçim sorar:

```text
Linux Türkçe yapılsın mı? [E/h]:

Pentest araçları kurulsun mu? [E/h]:
````

Seçimlerden sonra işlemler otomatik olarak gerçekleştirilir.

### 🇹🇷 Türkçeleştirme

* `tr_TR.UTF-8` locale
* Türkçe Q klavye
* GNOME desteği
* KDE desteği
* XFCE desteği
* Türkçe karakter destekli fontlar
* Firefox Türkçe dil paketi
* Chromium Türkçe dil paketi
* LibreOffice Türkçe dil paketi
* Türkçe man sayfaları
* Sistem `/etc/profile.d/` locale yapılandırması

### 🛡️ Pentest Araçları

#### 🌐 Web / Recon

* Nmap
* Ncat
* Ndif
* Nikto
* SQLMap
* Gobuster
* Dirsearch
* FFUF
* Feroxbuster
* Nuclei
* WhatWeb
* WAFW00F
* DNSenum
* DNSRecon
* Fierce
* Amass
* Burp Suite
* mitmproxy
* OWASP ZAP

#### 🧩 Reverse Engineering

* GHex
* Ghidra
* JADX
* Rizin
* Radare2
* Rizin Cutter
* rz-ghidra
* APKTool
* Dex2Jar
* Bytecode Viewer
* JD-GUI
* Ropper
* EDB Debugger
* Binwalk
* YARA
* GDB
* strace
* ltrace
* binutils

#### 🪟 Windows / Active Directory / SMB

* Evil-WinRM
* Samba
* SMBClient
* CIFS Utils
* LDAP Utils
* Enum4Linux
* Enum4Linux-ng
* Impacket
* NetExec
* Responder
* BloodyAD

#### 🖼️ Steganography / Forensics

* Steghide
* StegSnow
* OutGuess
* ExifTool
* Foremost
* Sleuth Kit
* Autopsy
* TestDisk
* DC3DD
* Scalpel

#### 🌐 Network / Traffic

* Wireshark
* TShark
* TCPDump
* Netcat
* Socat
* Bettercap
* Ettercap
* ARP-Scan
* Traceroute
* iPerf3
* Masscan

#### 🔐 Password / Hash

* Hashcat
* John the Ripper
* HashID
* Hydra
* Medusa
* Patator
* Crunch
* SecLists
* Wordlists

#### 📡 Wireless

* Aircrack-ng
* Reaver
* Bully
* Kismet
* hcxdumptool
* hcxpcapngtool
* Wifite
* rfkill
* iw

#### 🟢 Vulnerability Scanner

* GVM / OpenVAS

Kali üzerinde `gvm` paketi bulunuyorsa otomatik olarak kurulur.

Kurulumdan sonra:

```bash
sudo gvm-setup
sudo gvm-check-setup
sudo gvm-start
```

---

## 🛠️ Yardımcı Araçlar

Script ayrıca mevcutsa aşağıdaki yardımcı araçları da kurar:

* Gedit
* Plank
* Kazam
* Terminator
* Sonic Visualiser
* fzf
* ripgrep
* tmux
* btop
* jq
* curl
* wget
* unzip
* p7zip
* Git
* GitHub CLI
* eza
* bat

---

# 🚀 Kurulum

## 1. GitHub'dan doğrudan çalıştır

```bash
curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash
```

---

## 2. Dosyayı indirip çalıştır

```bash
git clone https://github.com/vedattascier/kali_turkcelestirme.git
cd kali_turkcelestirme
chmod +x linux-turkce.sh
sudo ./linux-turkce.sh
```

---

# 🔄 Kurulum Akışı

Script başlatıldığında önce sistem bilgilerini algılar.

Ardından:

```text
Linux Türkçeleştirme + Pentest Aracı
```

soruları gelir.

### Soru 1

```text
Linux Türkçe yapılsın mı? [E/h]:
```

`E` seçilirse:

```text
APT
 ↓
Locale
 ↓
Türkçe Q Klavye
 ↓
GNOME / KDE / XFCE
 ↓
Fontlar
 ↓
Firefox / Chromium / LibreOffice
 ↓
Türkçe Man Sayfaları
```

kurulur.

### Soru 2

```text
Pentest araçları kurulsun mu? [E/h]:
```

`E` seçilirse:

```text
Web / Recon
 ↓
Reverse Engineering
 ↓
Windows / AD / SMB
 ↓
Steganography / Forensics
 ↓
Network / Traffic
 ↓
Password / Hash
 ↓
Wireless
 ↓
GVM / OpenVAS
 ↓
Yardımcı Araçlar
```

kurulur.

---

# 🔄 APT Güncellemesi

Paket kurulumundan önce:

```bash
apt-get update
```

otomatik olarak çalıştırılır.

APT güncellemesi başarısız olursa script paket kurulumuna başlamaz.

---

# 💾 Otomatik Yedekleme

Türkçeleştirme seçildiğinde sistem ayarlarının yedeği alınır.

Yedek konumu:

```text
/root/linux-turkce-backup-TARIH_SAAT/
```

Yedeklenen dosyalar:

```text
/etc/locale.gen
/etc/default/locale
/etc/default/keyboard
/etc/hostname
/etc/hosts
```

---

# ✅ Paket Kontrol Sistemi

Script her paketi kurmadan önce kontrol eder.

Paket zaten kuruluysa:

```text
[VAR]
```

Depoda bulunamıyorsa:

```text
[YOK]
```

Kuruluyorsa:

```text
[KURULUYOR]
```

Başarılı olursa:

```text
[ OK ]
```

hata olursa:

```text
[HATA]
```

gösterilir.

Bir paketin bulunamaması bütün kurulumun durmasına neden olmaz.

---

# 📊 Kurulum Sonucu

Kurulum sonunda özet gösterilir:

```text
PAKET İSTATİSTİKLERİ

Kontrol edilen
Yeni kurulan
Zaten kurulu
Depoda olmayan
Kurulum hatası
```

Böylece hangi paketlerin kurulup hangilerinin sistem deposunda bulunmadığı görülebilir.

---

# 🖥️ Desteklenen Sistemler

Öncelikli olarak:

* Kali Linux
* Debian
* Ubuntu
* Debian/Ubuntu tabanlı sistemler

için tasarlanmıştır.

Kali Linux üzerinde en uyumlu kullanım hedeflenmektedir.

---

# ⚠️ Önemli

Bu script güvenlik araçlarını kurar.

Araçları yalnızca:

* Kendi sistemlerinizde
* İzinli güvenlik testlerinde
* CTF ortamlarında
* Eğitim/laboratuvar sistemlerinde

kullanın.

Yetkisiz sistemlere karşı tarama, parola saldırısı veya başka bir güvenlik testi gerçekleştirmeyin.

---

# 🧪 Script Kontrolü

Çalıştırmadan önce Bash sözdizimini kontrol etmek için:

```bash
bash -n linux-turkce.sh
```

Daha sonra:

```bash
sudo bash linux-turkce.sh
```

---

# 📄 Log

Script çalışma kayıtlarını:

```text
/var/log/linux-turkce.log
```

dosyasına yazar.

Kontrol etmek için:

```bash
sudo tail -f /var/log/linux-turkce.log
```

---

# 🔁 Yeniden Başlatma

Türkçeleştirme sonrasında en iyi sonuç için:

```bash
sudo reboot
```

komutu önerilir.

---

# 👤 Geliştirici

**Vedat Taşçıer**

GitHub:

https://github.com/vedattascier/kali_turkcelestirme

---

# 📜 Lisans

MIT License

Bu proje eğitim, kişisel kullanım, CTF ve yetkili güvenlik testleri
için geliştirilmektedir.

```
```
