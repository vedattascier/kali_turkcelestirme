 
---

# Kali Linux Türkçe Dil ve Klavye Ayarlama Bash Betiği

Bu betik, Kali Linux'ta sistemi tamamen Türkçe diline geçirir ve klavyeyi başlangıçta Türkçe Q olarak ayarlar.

## Özellikler:
- Sistem dilini `tr_TR.UTF-8` olarak ayarlar.
- Klavye düzenini başlangıçta Türkçe Q (`tr`) yapar.
- GNOME veya benzeri grafik arayüzler için varsayılan dili Türkçe olarak yapılandırır.
- Değişikliklerin tam olarak uygulanabilmesi için yeniden başlatma önerir.

## Kullanım:

1. **Betiği bir dosyaya kaydedin**  
   Betik içeriğini bir dosyaya kaydedin, örneğin `kali_turkcelestirme.sh`.

2. **Çalıştırma izni verin**  
   Terminalde aşağıdaki komutu kullanarak dosyaya çalıştırma izni verin:  
   ```bash
   chmod +x kali_turkcelestirme.sh
   ```

3. **Betik çalıştırın**  
   Betiği root yetkileriyle çalıştırın:  
   ```bash
   sudo ./kali_turkcelestirme.sh
   ```

4. **Yeniden başlatma**  
   Betik, değişikliklerin etkili olabilmesi için sistemi yeniden başlatmanızı önerecektir. Onay verirseniz sistem yeniden başlatılır.

## Önemli Notlar:
- Bu betik yalnızca root yetkileriyle çalıştırılabilir.
- Ayarlar tüm kullanıcılar için geçerlidir.
- Betik, GNOME masaüstü ortamını varsayar. Farklı masaüstü ortamlarında ek ayarlar gerekebilir.

## Betik İçeriği:

```bash
#!/bin/bash

# Dil ve klavye ayarları için gerekli yetkiler kontrol ediliyor
if [ "$(id -u)" -ne 0 ]; then
    echo "Bu betiği çalıştırmak için root yetkileri gereklidir. 'sudo' ile çalıştırın."
    exit 1
fi

# Sistem dilini Türkçe olarak ayarla
echo "Dil ayarları Türkçe olarak güncelleniyor..."
sed -i 's/^# tr_TR.UTF-8 UTF-8/tr_TR.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=tr_TR.UTF-8

# Klavyeyi başlangıçta Türkçe Q olarak ayarla
echo "Klavyeyi Türkçe Q olarak ayarlama..."
cat <<EOL > /etc/default/keyboard
XKBLAYOUT="tr"
XKBVARIANT=""
BACKSPACE="guess"
EOL

# GNOME veya grafik arayüz için dil ayarı
echo "Varsayılan dil ve klavye Türkçe olarak ayarlanıyor..."
gsettings set org.gnome.system.locale region 'tr_TR.UTF-8'

# Başlangıç klavyesi ve dil doğrulaması
echo "Klavye ve dil başlangıç için Türkçe olarak ayarlandı."

# Sistem reboot için bilgi ver
echo "Değişikliklerin tam olarak uygulanması için sistemi yeniden başlatmanız önerilir."
read -p "Şimdi sistemi yeniden başlatmak istiyor musunuz? (e/h): " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" == "e" || "$REBOOT_CHOICE" == "E" ]]; then
    echo "Sistem yeniden başlatılıyor..."
    reboot
else
    echo "Ayarlar uygulandı ancak yeniden başlatmadan tam olarak aktif olmayabilir."
fi

```

--- 
