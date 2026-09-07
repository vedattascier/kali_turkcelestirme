# 🇹🇷 Kali Türkçeleştirme

Kali Linux'u Türkçe kullanıma hazırlamak için geliştirilmiş, tek dosyalık Bash aracıdır.

## 🚀 Tek Komutla Çalıştır

Scripti GitHub üzerinden doğrudan çalıştırabilirsiniz:

```bash
curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash
```

## ✨ Özellikler

* 🇹🇷 Türkçe sistem dili ve locale
* ⌨️ Türkçe Q klavye
* 🖥️ GNOME desteği
* 🖥️ KDE Plasma desteği
* 🌐 Chromium Türkçe dil desteği
* 🦊 Firefox / Firefox ESR Türkçe dil desteği
* 📄 LibreOffice Türkçe dil desteği
* 📚 Türkçe man sayfaları
* 🔤 Türkçe karakter destekli font kurulumu
* 👤 Kullanıcı oluşturma
* 🔑 Kullanıcı şifresi değiştirme
* 🛡️ Kullanıcıya sudo yetkisi verme
* 🚫 Sudo yetkisini kaldırma
* ✏️ Kullanıcı adı değiştirme
* 🗑️ Kullanıcı silme
* 🖥️ Hostname değiştirme
* 📊 Sistem bilgilerini görüntüleme
* 📦 Paket arama
* 🔄 APT paket listelerini güncelleme
* 💾 Değişikliklerden önce otomatik yedekleme
* 📝 Log kaydı
* 🔄 Sistemi yeniden başlatma
* 📋 Etkileşimli yönetim menüsü

## 🖥️ Desteklenen Sistemler

Öncelikli olarak:

* Kali Linux
* Debian
* Debian tabanlı sistemler

> Paket isimleri ve masaüstü ortamlarına göre bazı özelliklerin kullanılabilirliği değişebilir.

## 📥 Kurulum

Scripti indirmek için:

```bash
curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh -o linux-turkce.sh
```

Çalıştırmak için:

```bash
sudo bash linux-turkce.sh
```

Alternatif olarak tek komut:

```bash
curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash
```

## 🔐 Güvenli Kullanım

Root yetkisiyle çalışan scriptleri internetten doğrudan çalıştırmadan önce kodu incelemeniz önerilir.

Scripti görüntülemek:

```bash
curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh
```

Dosyaya indirerek incelemek:

```bash
curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh -o linux-turkce.sh
```

```bash
less linux-turkce.sh
```

Daha sonra:

```bash
sudo bash linux-turkce.sh
```

## 👤 Kullanıcı Yönetimi

Araç üzerinden kullanıcı yönetimi yapılabilir:

* Yeni kullanıcı oluşturma
* Kullanıcı şifresi değiştirme
* Sudo yetkisi verme
* Sudo yetkisini kaldırma
* Kullanıcı adı değiştirme
* Kullanıcı silme

> Aktif olarak kullanılan hesabın adını değiştirmek sistemde sorun oluşturabileceğinden dikkatli kullanılmalıdır.

## 🛡️ Root ve Sudo

Araç kullanıcıya doğrudan root hesabı dönüştürmek yerine Linux'un standart yetkilendirme mekanizması olan `sudo` kullanımını tercih eder.

Kullanıcıya sudo yetkisi vermek:

```bash
sudo usermod -aG sudo KULLANICI
```

## 🌐 Uygulama Dil Desteği

Sistem ve paket yöneticisi üzerinden mevcut Türkçe dil paketleri kontrol edilir.

Desteklenen uygulamalar arasında:

* Chromium
* Firefox / Firefox ESR
* LibreOffice

bulunur.

> Her Linux uygulamasının Türkçe arayüzü bulunmayabilir. Script yalnızca dağıtımda mevcut olan uygun dil paketlerini kurmaya çalışır.

## 💾 Yedekleme

Sistem ayarlarında değişiklik yapılmadan önce yedekleme işlemi gerçekleştirilir.

Yedekler aşağıdaki dizinde tutulur:

```text
/root/linux-turkce-backup-YYYYMMDD-HHMMSS/
```

## 📝 Log

Script çalışma kayıtlarını aşağıdaki dosyaya yazabilir:

```text
/var/log/linux-turkce.log
```

Sorun yaşandığında bu log dosyası hata tespiti için kullanılabilir.

## ⌨️ Türkçe Klavye

Sistem Türkçe Q klavye düzenine yapılandırılır.

Masaüstü ortamına ve sistem yapılandırmasına göre uygulanacak yöntem otomatik olarak belirlenir.

## 🖥️ Masaüstü Ortamları

Script mevcut masaüstü ortamını algılamaya çalışır.

Desteklenen ortamlar:

* GNOME
* KDE Plasma

## 📊 Sistem Bilgileri

Araç üzerinden aşağıdaki bilgiler görüntülenebilir:

* İşletim sistemi
* Kernel sürümü
* Mimari
* Hostname
* CPU
* RAM
* Disk kullanımı
* Aktif kullanıcı
* Masaüstü ortamı

## 🔄 Güncelleme

GitHub'daki güncel scripti tekrar çalıştırmak için:

```bash
curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash
```

## 📂 Proje Yapısı

```text
kali_turkcelestirme/
├── linux-turkce.sh
├── README.md
└── LICENSE
```

## ⚠️ Uyarı

Bu araç sistem yapılandırmalarında değişiklik yapar ve bazı işlemler için root yetkisi gerektirir.

Kullanımdan önce önemli dosyalarınızın yedeğini almanız önerilir.

Özellikle:

* Kullanıcı silme
* Kullanıcı adı değiştirme
* Sudo yetkisi değiştirme
* Sistem ayarlarını değiştirme

işlemlerinde dikkatli olunmalıdır.

## 👨‍💻 Geliştirici

**Vedat Taşçıer**

GitHub:

https://github.com/vedattascier

Proje:

https://github.com/vedattascier/kali_turkcelestirme

## 📜 Lisans

Bu proje açık kaynak olarak geliştirilmektedir.

Lisans koşulları için `LICENSE` dosyasına bakınız.
