````markdown
# 🇹🇷 Linux Türkçeleştirme & Pentest Kurulum Aracı

Kali Linux, Debian ve Ubuntu tabanlı sistemler için hazırlanmış Bash tabanlı otomatik kurulum aracıdır.

Sistem dilini Türkçeleştirir, Türkçe Q klavye yapılandırır ve isteğe bağlı olarak çeşitli güvenlik, pentest, reverse engineering, web, network, forensics ve yardımcı araçları otomatik olarak kurar.

> **Kali Linux öncelikli olarak geliştirilmiştir.**

---

## ✨ Özellikler

- 🇹🇷 Türkçe sistem dili
- ⌨️ Türkçe Q klavye
- 🖥️ GNOME, KDE Plasma ve XFCE desteği
- 🔤 Türkçe karakter destekli fontlar
- 🌐 Firefox / Chromium / LibreOffice Türkçe dil paketleri
- 📖 Türkçe man sayfaları
- 🛡️ Pentest araçları
- 🧩 Reverse engineering araçları
- 📱 Android analiz araçları
- 🪟 Windows / Active Directory / SMB araçları
- 🌐 Web güvenliği ve reconnaissance araçları
- 🔍 Network ve trafik analiz araçları
- 🔐 Password / Hash araçları
- 📡 Wireless araçları
- 🖼️ Steganography / Forensics araçları
- 🟢 GVM / OpenVAS
- 🛠️ Yardımcı terminal ve masaüstü araçları
- 💾 Sistem ayarları için otomatik yedekleme
- 📝 Loglama
- 📦 Bulunmayan paketleri atlayarak kuruluma devam etme

---

# 🚀 Kurulum

## Tek komut

GitHub üzerinden doğrudan çalıştır:

```bash
curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash
````

## Manuel kurulum

Repository'yi klonla:

```bash
git clone https://github.com/vedattascier/kali_turkcelestirme.git
```

Dizine gir:

```bash
cd kali_turkcelestirme
```

Scripti çalıştırılabilir yap:

```bash
chmod +x linux-turkce.sh
```

Çalıştır:

```bash
sudo ./linux-turkce.sh
```

---

# 🧭 Çalışma Mantığı

Script gereksiz menüler kullanmaz.

Çalıştırıldığında iki temel soru sorar:

```text
Linux Türkçe yapılsın mı? [E/h]:

Pentest araçları kurulsun mu? [E/h]:
```

Seçimlerin ardından kurulum otomatik olarak devam eder.

---

# 🇹🇷 Türkçeleştirme

Türkçeleştirme seçilirse aşağıdaki işlemler yapılır.

## Locale

```text
tr_TR.UTF-8
```

locale yapılandırılır.

Temel dosyalar:

```text
/etc/locale.gen
/etc/default/locale
/etc/profile.d/turkish-locale.sh
```

## Klavye

Türkçe Q klavye yapılandırılır:

```text
XKBMODEL="pc105"
XKBLAYOUT="tr"
```

## Masaüstü

Algılanan masaüstüne göre gerekli ayarlar uygulanır:

* GNOME
* KDE Plasma
* XFCE

## Fontlar

Türkçe karakter desteği için:

```text
fonts-dejavu
fonts-liberation
fonts-noto-core
fonts-noto-cjk
fonts-noto-mono
```

paketleri kontrol edilir.

## Uygulamalar

Depoda mevcut olması durumunda:

* Firefox Türkçe
* Chromium Türkçe
* LibreOffice Türkçe

dil paketleri kurulur.

## Man Sayfaları

Depoda bulunması halinde:

```text
manpages-tr
manpages-tr-dev
```

kurulur.

---

# 🛡️ Pentest Araçları

Pentest seçildiğinde güvenlik araçları kategorilere ayrılarak kurulmaya çalışılır.

## 🌐 Web / Recon

```text
Nmap
Ncat
Ndiff
Nikto
SQLMap
Gobuster
Dirsearch
FFUF
Feroxbuster
Nuclei
WhatWeb
WAFW00F
DNSenum
DNSRecon
Fierce
Amass
Burp Suite
mitmproxy
OWASP ZAP
```

---

## 🧩 Reverse Engineering

```text
GHex
Ghidra
JADX
Rizin
Radare2
Rizin Cutter
rz-ghidra
APKTool
Dex2Jar
Bytecode Viewer
JD-GUI
Ropper
EDB Debugger
Binwalk
YARA
GDB
strace
ltrace
binutils
```

Kullanım alanları:

* Binary analysis
* Static analysis
* Dynamic analysis
* Debugging
* APK / DEX analizi
* Reverse engineering

---

## 📱 Android

```text
JADX
APKTool
Dex2Jar
Bytecode Viewer
Ghidra
Rizin
```

Android uygulamalarının statik ve dinamik analiz çalışmalarında kullanılabilir.

---

## 🪟 Windows / Active Directory / SMB

```text
Evil-WinRM
Samba
SMBClient
CIFS Utils
LDAP Utils
Enum4Linux
Enum4Linux-ng
Impacket
NetExec
Responder
BloodyAD
```

Windows ve Active Directory laboratuvarlarında kullanılmak üzere hazırlanmıştır.

---

## 🖼️ Steganography / Forensics

```text
Steghide
StegSnow
OutGuess
ExifTool
Foremost
Sleuth Kit
Autopsy
TestDisk
DC3DD
Scalpel
```

Dosya analizi, metadata inceleme, steganografi ve dijital adli bilişim çalışmaları için kullanılır.

---

## 🌐 Network / Traffic

```text
Wireshark
TShark
TCPDump
Netcat
Socat
Bettercap
Ettercap
ARP-Scan
Traceroute
iPerf3
Masscan
```

Ağ analizi ve trafik inceleme çalışmalarında kullanılabilir.

---

## 🔐 Password / Hash

```text
Hashcat
John the Ripper
HashID
Hydra
Medusa
Patator
Crunch
SecLists
Wordlists
```

Yetkili güvenlik testleri ve laboratuvar ortamlarında parola/hash güvenliği analizinde kullanılır.

---

## 📡 Wireless

```text
Aircrack-ng
Reaver
Bully
Kismet
hcxdumptool
hcxpcapngtool
Wifite
rfkill
iw
```

Kablosuz ağ analizi ve güvenlik testlerinde kullanılabilir.

---

# 🟢 GVM / OpenVAS

Kali deposunda `gvm` paketi mevcutsa otomatik olarak kurulmaya çalışılır.

Kurulumdan sonra ilk yapılandırma:

```bash
sudo gvm-setup
```

Kontrol:

```bash
sudo gvm-check-setup
```

Başlatma:

```bash
sudo gvm-start
```

---

# 🛠️ Yardımcı Araçlar

Kurulumda mevcut olması halinde aşağıdaki araçlar da kontrol edilir:

```text
Gedit
Plank
Kazam
Terminator
Sonic Visualiser
fzf
ripgrep
tmux
btop
jq
curl
wget
unzip
p7zip
Git
GitHub CLI
eza
bat
```

---

# 🐉 Kali Metapaketleri

Kali Linux üzerinde mevcutsa aşağıdaki metapaketler de kontrol edilir:

```text
kali-tools-web
kali-tools-reverse-engineering
kali-tools-information-gathering
kali-tools-passwords
kali-tools-wireless
kali-tools-forensics
kali-tools-windows-resources
```

`kali-linux-everything` kullanılmaz.

Amaç sistemi gereksiz paketlerle doldurmak yerine belirli güvenlik kategorilerini hazırlamaktır.

---

# 🔄 APT Güncellemesi

Paket kurulumu başlamadan önce:

```bash
apt-get update
```

otomatik olarak çalıştırılır.

APT güncellemesi başarısız olursa kurulum güvenli şekilde durdurulur.

---

# 📦 Paket Kontrol Sistemi

Script her paketi kurmadan önce kontrol eder.

### Zaten kurulu

```text
[VAR]
```

### Depoda bulunamadı

```text
[YOK]
```

### Kuruluyor

```text
[KURULUYOR]
```

### Başarılı

```text
[ OK ]
```

### Hata

```text
[HATA]
```

Bir paketin depoda bulunmaması diğer paketlerin kurulmasını normalde engellemez.

Bu yapı farklı Kali/Debian sürümlerindeki paket farklılıklarının kurulumu tamamen durdurmasını önlemeye yardımcı olur.

---

# 💾 Otomatik Yedekleme

Türkçeleştirme seçildiğinde önemli sistem dosyalarının yedeği alınır.

Yedek konumu:

```text
/root/linux-turkce-backup-YYYYMMDD_HHMMSS/
```

Yedeklenebilen dosyalar:

```text
/etc/locale.gen
/etc/default/locale
/etc/default/keyboard
/etc/hostname
/etc/hosts
```

---

# 📝 Log

Script çalışma kayıtlarını:

```text
/var/log/linux-turkce.log
```

dosyasına yazar.

Canlı görüntülemek için:

```bash
sudo tail -f /var/log/linux-turkce.log
```

---

# ✅ Kurulum Sonrası

Türkçeleştirme işlemlerinin tamamen uygulanması için oturumu kapatıp tekrar açmanız veya sistemi yeniden başlatmanız önerilir.

```bash
sudo reboot
```

---

# 🧪 Script Kontrolü

Scripti çalıştırmadan önce Bash sözdizimini kontrol edebilirsiniz:

```bash
bash -n linux-turkce.sh
```

ShellCheck ile daha ayrıntılı kontrol:

```bash
shellcheck linux-turkce.sh
```

ShellCheck kurulu değilse:

```bash
sudo apt install shellcheck
```

---

# 🔧 Sorun Giderme

## APT hatası

Önce:

```bash
sudo apt update
```

Ardından:

```bash
sudo apt --fix-broken install
```

Sonra scripti yeniden çalıştırın:

```bash
sudo bash linux-turkce.sh
```

## Paket bulunamadı

Bir paket mevcut değilse kontrol edin:

```bash
apt-cache search paket-adi
```

Örneğin:

```bash
apt-cache search jadx
```

## Türkçe hemen uygulanmadı

Sistemi yeniden başlatın:

```bash
sudo reboot
```

---

# 📁 Proje Yapısı

```text
kali_turkcelestirme/
├── linux-turkce.sh
├── README.md
└── LICENSE
```

---

# ⚠️ Yasal ve Güvenli Kullanım

Bu proje güvenlik araçlarının kurulumunu kolaylaştırır.

Kurulan araçlar yalnızca:

* Kendi sistemlerinizde
* Yetkili güvenlik testlerinde
* CTF ortamlarında
* Eğitim laboratuvarlarında
* Sanal makine/test ortamlarında

kullanılmalıdır.

Yetkisiz sistemlerde tarama, parola saldırısı veya başka güvenlik testleri gerçekleştirmeyin.

---

# 🤝 Katkı

Hata bildirimleri ve geliştirme önerileri için GitHub Issues kullanılabilir.

Pull Request katkıları değerlendirilebilir.

---

# 👨‍💻 Geliştirici

**Vedat Taşçıer**

GitHub:

https://github.com/vedattascier/kali_turkcelestirme

---

# 📜 Lisans

MIT License

Bu proje eğitim, CTF, laboratuvar ve yetkili güvenlik testleri amacıyla geliştirilmiştir.

---

## ⭐ Destek

Projeyi faydalı bulduysanız repository'ye ⭐ bırakabilirsiniz.

https://github.com/vedattascier/kali_turkcelestirme

```
```
