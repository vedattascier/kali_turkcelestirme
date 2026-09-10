````markdown
# 🇹🇷 Linux Türkçeleştirme & Pentest Kurulum Aracı

Kali Linux, Debian ve Ubuntu tabanlı sistemler için geliştirilmiş Bash tabanlı otomatik kurulum aracıdır.

Sistemi Türkçeleştirir, Türkçe Q klavye yapılandırır ve isteğe bağlı olarak pentest, reverse engineering, web güvenliği, ağ analizi, forensics ve yardımcı araçları otomatik olarak kurar.

> **Kali Linux öncelikli kullanım için tasarlanmıştır.**

---

## ✨ Özellikler

- 🇹🇷 Türkçe sistem locale
- ⌨️ Türkçe Q klavye
- 🖥️ GNOME, KDE Plasma ve XFCE desteği
- 🔤 Türkçe karakter destekli fontlar
- 🌐 Firefox, Chromium ve LibreOffice Türkçe dil paketleri
- 📖 Türkçe man sayfaları
- 🛡️ Pentest araçları
- 🧩 Reverse engineering araçları
- 📱 Android analiz araçları
- 🪟 Windows / Active Directory / SMB araçları
- 🌐 Web / Recon araçları
- 🔍 Network / Traffic araçları
- 🔐 Password / Hash araçları
- 📡 Wireless araçları
- 🖼️ Steganography / Forensics araçları
- 🟢 GVM / OpenVAS
- 🛠️ Yardımcı terminal ve masaüstü araçları
- 💾 Otomatik sistem yedekleme
- 📝 Kurulum logları
- 📦 Bulunmayan paketleri atlayarak devam edebilme
- 🔄 Kurulum öncesinde otomatik APT güncellemesi

---

# 🚀 Kurulum

## Tek Komut

GitHub üzerinden doğrudan çalıştırabilirsiniz:

```bash
curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash
````

Script başladıktan sonra iki soru sorar:

```text
Linux Türkçe yapılsın mı? [E/h]:
Pentest araçları kurulsun mu? [E/h]:
```

Seçimlerinize göre kurulum otomatik olarak devam eder.

---

## Manuel Kurulum

Repository'yi klonlayın:

```bash
git clone https://github.com/vedattascier/kali_turkcelestirme.git
```

Dizine girin:

```bash
cd kali_turkcelestirme
```

Scripti çalıştırılabilir yapın:

```bash
chmod +x linux-turkce.sh
```

Çalıştırın:

```bash
sudo ./linux-turkce.sh
```

---

# 🧭 Çalışma Akışı

Script gereksiz menüler kullanmaz.

Kurulum sırası:

```text
Başlat
  ↓
Sistem / kullanıcı / masaüstü algılama
  ↓
APT güncelleme
  ↓
Türkçeleştirme seçimi
  ↓
Pentest araçları seçimi
  ↓
Seçilen paketlerin kurulumu
  ↓
Sistem son kontrolü
  ↓
Kurulum özeti
```

---

# 🔄 APT Güncellemesi

Paket kurulumu başlamadan önce APT paket listeleri otomatik olarak güncellenir:

```bash
apt-get update
```

APT güncellemesi başarısız olursa script paket kurulumuna devam etmez.

Bu sayede eski veya güncel olmayan paket indekslerinden kaynaklanan sorunların azaltılması amaçlanır.

---

# 🇹🇷 Türkçeleştirme

`Linux Türkçe yapılsın mı?` sorusuna `E` cevabı verilirse aşağıdaki işlemler gerçekleştirilir.

## Locale

Türkçe locale:

```text
tr_TR.UTF-8
```

olarak yapılandırılır.

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
XKBVARIANT=""
XKBOPTIONS=""
```

## Masaüstü

Algılanan masaüstü ortamına göre ayarlar uygulanır:

* GNOME
* KDE Plasma
* XFCE

## Fontlar

Türkçe karakter desteği için uygun fontlar kontrol edilir:

```text
fonts-dejavu
fonts-liberation
fonts-noto-core
fonts-noto-cjk
fonts-noto-mono
```

## Uygulamalar

Depoda mevcut olması durumunda Türkçe dil paketleri kurulabilir:

* Firefox
* Chromium
* LibreOffice

## Man Sayfaları

Depoda mevcut olması durumunda:

```text
manpages-tr
manpages-tr-dev
```

kurulur.

---

# 🛡️ Pentest Araçları

`Pentest araçları kurulsun mu?` sorusuna `E` verilirse güvenlik araçları kategorilere ayrılarak kurulur.

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

Başlıca kullanım alanları:

* Binary analysis
* Static analysis
* Dynamic analysis
* Debugging
* Reverse engineering

---

## 📱 Android Analizi

```text
JADX
APKTool
Dex2Jar
Bytecode Viewer
Ghidra
Rizin
```

Android APK / DEX analizi ve reverse engineering çalışmalarında kullanılabilir.

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

Windows, Active Directory ve SMB laboratuvarlarında kullanılmak üzere hazırlanmıştır.

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

Kullanım alanları:

* Dijital adli bilişim
* Dosya analizi
* Metadata analizi
* Steganography
* Disk / veri inceleme

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

Ağ analizi ve trafik incelemelerinde kullanılabilir.

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

Yetkili güvenlik testleri ve laboratuvar ortamlarında parola/hash güvenliği analizinde kullanılabilir.

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

Kablosuz ağ analiz ve güvenlik çalışmalarında kullanılabilir.

---

# 🟢 GVM / OpenVAS

Kali APT deposunda `gvm` paketi mevcutsa kurulmaya çalışılır.

Kurulumdan sonra:

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

Script aşağıdaki yardımcı araçları da kontrol eder:

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
p7zip-full
Git
GitHub CLI
eza
bat
```

---

# 🐉 Kali Linux Metapaketleri

Kali Linux kullanılıyorsa ve paketler mevcutsa aşağıdaki metapaketler de kontrol edilir:

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

Amaç sistemi gereksiz şekilde yüzlerce paketle doldurmadan belirli güvenlik kategorilerini hazırlamaktır.

---

# 📦 Paket Kontrol Sistemi

Her paket kurulmadan önce kontrol edilir.

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

Bir paketin bulunamaması normalde diğer paketlerin kurulmasını engellemez.

Bu yapı farklı Kali, Debian ve Ubuntu sürümlerindeki paket farklılıklarının bütün kurulumu durdurmasını önlemeye yardımcı olur.

---

# 💾 Otomatik Yedekleme

Türkçeleştirme seçildiğinde önemli sistem yapılandırma dosyalarının yedeği alınır.

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

Kurulum kayıtları:

```text
/var/log/linux-turkce.log
```

dosyasına yazılır.

Canlı takip:

```bash
sudo tail -f /var/log/linux-turkce.log
```

---

# ✅ Kurulum Sonrası

Türkçe locale, masaüstü ve bazı uygulama ayarlarının tamamen uygulanması için oturumu kapatıp yeniden açmanız veya sistemi yeniden başlatmanız önerilir.

```bash
sudo reboot
```

---

# 🧪 Script Kontrolü

Çalıştırmadan önce Bash sözdizimini kontrol edin:

```bash
bash -n linux-turkce.sh
```

ShellCheck ile daha ayrıntılı kontrol:

```bash
shellcheck linux-turkce.sh
```

ShellCheck kurmak için:

```bash
sudo apt install shellcheck
```

---

# 🔧 Sorun Giderme

## APT Hatası

Önce:

```bash
sudo apt update
```

Ardından:

```bash
sudo apt --fix-broken install
```

Sonrasında scripti tekrar çalıştırın:

```bash
sudo bash linux-turkce.sh
```

## Paket Bulunamadı

Bir paketin depoda bulunup bulunmadığını kontrol edin:

```bash
apt-cache search paket-adi
```

Örneğin:

```bash
apt-cache search jadx
```

## Türkçe Hemen Uygulanmadı

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

# ⚠️ Güvenli ve Yetkili Kullanım

Bu proje güvenlik araçlarının kurulumunu kolaylaştırır.

Kurulan araçlar yalnızca:

* Kendi sistemlerinizde
* Yetkili güvenlik testlerinde
* CTF ortamlarında
* Eğitim laboratuvarlarında
* Sanal test ortamlarında

kullanılmalıdır.

Yetkisiz sistemlerde tarama, parola saldırısı veya başka güvenlik testleri gerçekleştirmeyin.

---

# 🤝 Katkı

Hata bildirimleri, yeni özellik önerileri ve geliştirmeler için GitHub Issues kullanılabilir.

Pull Request katkıları memnuniyetle değerlendirilir.

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

Projeyi faydalı bulduysanız GitHub repository'sine ⭐ bırakabilirsiniz.

https://github.com/vedattascier/kali_turkcelestirme

````

Bu sürümde özellikle mevcut dosyandaki bozuk ` ```bash `, ` ```text ` ve tek ters tırnak bloklarını temizledim; GitHub'ın şu anda gösterdiği yapıdaki sorunlar giderilmiş durumda.
````
