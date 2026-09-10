````markdown
# 🇹🇷 Linux Türkçeleştirme & Pentest Kurulum Aracı

Modern Kali Linux, Debian ve Ubuntu tabanlı sistemler için hazırlanmış, Bash tabanlı otomatik kurulum aracıdır.

Script; sistemi Türkçeleştirmek, Türkçe Q klavye yapılandırmasını yapmak, gerekli dil paketlerini kurmak ve yetkili güvenlik testleri için kullanılan araçları tek bir işlem akışında hazırlamak üzere tasarlanmıştır.

> **Kali Linux öncelikli kullanım hedeflenmiştir.**

---

## ✨ Özellikler

- 🇹🇷 Türkçe sistem locale yapılandırması
- ⌨️ Türkçe Q klavye
- 🖥️ GNOME / KDE Plasma / XFCE desteği
- 🔤 Türkçe karakter destekli fontlar
- 🌐 Firefox / Chromium / LibreOffice dil paketleri
- 📖 Türkçe man sayfaları
- 🛡️ Pentest ve güvenlik araçları
- 🧩 Reverse engineering araçları
- 📱 Android analiz araçları
- 🪟 Windows / Active Directory / SMB araçları
- 🌐 Web güvenliği ve reconnaissance araçları
- 🔍 Network ve trafik analiz araçları
- 🔐 Password / Hash araçları
- 📡 Wireless araçları
- 🖼️ Steganography / Forensics araçları
- 🟢 GVM / OpenVAS
- 🛠️ Yardımcı masaüstü ve terminal araçları
- 💾 Sistem ayarları için otomatik yedekleme
- 📝 Ayrıntılı loglama
- 📦 Paket bulunamazsa kurulumun tamamını durdurmayan yapı

---

# 🚀 Kurulum

## Tek komutla çalıştırma

GitHub üzerinden doğrudan:

```bash
curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash
````

## Manuel kullanım

Repository'yi klonla:

```bash
git clone https://github.com/vedattascier/kali_turkcelestirme.git
```

Dizine gir:

```bash
cd kali_turkcelestirme
```

Çalıştırılabilir yap:

```bash
chmod +x linux-turkce.sh
```

Scripti çalıştır:

```bash
sudo ./linux-turkce.sh
```

---

# 🧭 Çalışma Mantığı

Script başlatıldığında gereksiz menülerle uğraştırmaz.

İki temel soru sorar:

```text
Linux Türkçe yapılsın mı? [E/h]:
Pentest araçları kurulsun mu? [E/h]:
```

Seçimlere göre kurulum otomatik devam eder.

---

## 1. APT Hazırlığı

Paket kurulmadan önce APT paket listeleri güncellenir:

```bash
apt-get update
```

APT güncellemesi başarısız olursa paket kurulumu başlatılmaz.

Bu sayede eski paket indekslerinden kaynaklanan kurulum sorunları azaltılır.

---

# 🇹🇷 Türkçeleştirme

Türkçeleştirme seçildiğinde aşağıdaki işlemler otomatik yapılır.

### Locale

```text
tr_TR.UTF-8
```

yapılandırılır.

Oluşturulan temel dosyalar:

```text
/etc/locale.gen
/etc/default/locale
/etc/profile.d/turkish-locale.sh
```

### Klavye

Türkçe Q klavye:

```text
XKBMODEL="pc105"
XKBLAYOUT="tr"
```

şeklinde ayarlanır.

### Masaüstü

Algılanan masaüstüne göre:

* GNOME
* KDE Plasma
* XFCE

için uygun locale işlemleri uygulanır.

### Fontlar

Türkçe karakter desteği için uygun font paketleri kontrol edilir.

Örneğin:

```text
fonts-dejavu
fonts-liberation
fonts-noto-core
fonts-noto-cjk
fonts-noto-mono
```

### Uygulamalar

Depoda mevcut olması durumunda:

```text
Firefox Türkçe
Chromium Türkçe
LibreOffice Türkçe
```

dil paketleri kurulur.

### Man Sayfaları

Mevcutsa:

```text
manpages-tr
manpages-tr-dev
```

kurulur.

---

# 🛡️ Pentest Araçları

Pentest seçeneği etkinleştirildiğinde araçlar kategorilere göre kurulmaya çalışılır.

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

Özellikle:

* Binary analizi
* APK/DEX analizi
* Static analysis
* Debugging
* Reverse engineering

çalışmaları için tasarlanmıştır.

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

Windows ve Active Directory laboratuvarları için gerekli araçların kurulumu hedeflenir.

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

Dosya analizi, dijital adli bilişim ve steganografi çalışmaları için kullanılır.

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

Ağ analizi ve trafik inceleme çalışmalarında kullanılır.

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

Yetkili test ve laboratuvar ortamlarında parola/hash güvenliği analizleri için kullanılır.

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

Kablosuz ağ güvenliği ve analiz çalışmalarında kullanılır.

---

# 🟢 GVM / OpenVAS

Kali depolarında mevcut olduğu durumda:

```text
gvm
```

kurulur.

İlk yapılandırma için:

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

Kurulum sırasında aşağıdaki araçlar da kontrol edilir:

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
git
GitHub CLI
eza
bat
```

---

# 🐉 Kali Metapaketleri

Kali Linux kullanılıyorsa uygun metapaketler ayrıca kontrol edilir.

```text
kali-tools-web
kali-tools-reverse-engineering
kali-tools-information-gathering
kali-tools-passwords
kali-tools-wireless
kali-tools-forensics
kali-tools-windows-resources
```

> `kali-linux-everything` bilinçli olarak kullanılmaz. Sistem gereksiz yere yüzlerce ekstra paketle doldurulmadan, odaklanmış araç grupları tercih edilir.

---

# 📦 Paket Yönetimi

Script her paket için önce mevcut durumu kontrol eder.

### Zaten kuruluysa

```text
[VAR]
```

### Depoda yoksa

```text
[YOK]
```

### Kuruluyorsa

```text
[KURULUYOR]
```

### Başarılıysa

```text
[ OK ]
```

### Kurulum başarısızsa

```text
[HATA]
```

Bir paketin bulunamaması normalde diğer paketlerin kurulumunu durdurmaz.

Bu özellikle Kali sürümleri arasındaki paket adı farklılıklarında faydalıdır.

---

# 💾 Otomatik Yedekleme

Türkçeleştirme seçildiğinde sistem yapılandırma dosyalarının yedeği alınır.

Yedek dizini:

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

dosyasında tutulur.

Canlı görüntülemek için:

```bash
sudo tail -f /var/log/linux-turkce.log
```

---

# ✅ Kurulum Sonrası

Türkçeleştirme tamamlandıktan sonra en iyi sonuç için oturumu kapatıp tekrar açmanız veya sistemi yeniden başlatmanız önerilir:

```bash
sudo reboot
```

---

# 🧪 Scripti Çalıştırmadan Önce Kontrol

Bash sözdizimini kontrol etmek için:

```bash
bash -n linux-turkce.sh
```

Daha ayrıntılı kontrol için:

```bash
shellcheck linux-turkce.sh
```

`ShellCheck` yüklü değilse:

```bash
sudo apt install shellcheck
```

---

# ⚠️ Güvenlik ve Yasal Kullanım

Bu repository güvenlik araçlarını otomatik olarak kurabilir.

Kurulan araçlar yalnızca:

* Kendi sistemleriniz
* Yetkili güvenlik testleri
* CTF yarışmaları
* Eğitim laboratuvarları
* Test/sanal makine ortamları

üzerinde kullanılmalıdır.

Başkasına ait sistemlerde izinsiz tarama, parola saldırısı veya güvenlik testi gerçekleştirmeyin.

---

# 🔧 Sorun Giderme

## APT güncelleme hatası

Önce:

```bash
sudo apt update
```

ardından:

```bash
sudo apt --fix-broken install
```

çalıştırılabilir.

Sonrasında script tekrar çalıştırılabilir:

```bash
sudo bash linux-turkce.sh
```

---

## Türkçe dil hemen görünmüyor

Locale değişikliklerinin uygulanması için:

```bash
sudo reboot
```

veya oturumu kapatıp tekrar açın.

---

## Bir paket bulunamadı

Bu durum her zaman script hatası değildir.

Paketin mevcut olup olmadığını kontrol etmek için:

```bash
apt-cache search paket-adi
```

kullanabilirsiniz.

Örneğin:

```bash
apt-cache search jadx
```

---

# 📁 Proje Yapısı

```text
kali_turkcelestirme/
│
├── linux-turkce.sh
├── README.md
└── LICENSE
```

---

# 🤝 Katkı

Hata bildirimleri, iyileştirmeler ve yeni paket önerileri için GitHub Issues kullanılabilir.

Pull Request katkıları memnuniyetle değerlendirilir.

---

# 👨‍💻 Geliştirici

**Vedat Taşçıer**

GitHub:

https://github.com/vedattascier/kali_turkcelestirme

---

# 📜 Lisans

MIT License

Bu proje eğitim, laboratuvar, CTF ve yetkili güvenlik testleri amacıyla geliştirilmiştir.

---

## ⭐ Destek

Projeyi faydalı bulduysanız GitHub repository'sine ⭐ bırakabilirsiniz.

```text
https://github.com/vedattascier/kali_turkcelestirme
```

```

Bu sürüm doğrudan `README.md` içine konulabilecek şekilde düzenlendi.
```
