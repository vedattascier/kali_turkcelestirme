#!/bin/bash

# ================================================================
# LINUX TÜRKÇELEŞTİRME & SİSTEM YÖNETİM ARACI
# Kali Linux / Debian
# Tek dosya sürümü
# ================================================================

set -o pipefail

VERSION="3.0"

# -------------------- RENKLER --------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

# -------------------- ROOT KONTROLÜ --------------------

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Bu program root yetkisi gerektiriyor.${RESET}"
    echo
    echo "Çalıştırma:"
    echo "sudo $0"
    exit 1
fi

# -------------------- SİSTEM --------------------

if [[ ! -f /etc/os-release ]]; then
    echo -e "${RED}İşletim sistemi tespit edilemedi.${RESET}"
    exit 1
fi

source /etc/os-release

if ! command -v apt >/dev/null 2>&1; then
    echo -e "${RED}Bu betik Debian/Ubuntu/Kali tabanlı apt sistemleri içindir.${RESET}"
    exit 1
fi

# -------------------- AKTİF KULLANICI --------------------

TARGET_USER=""

if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
fi

if [[ -z "$TARGET_USER" ]]; then
    TARGET_USER=$(logname 2>/dev/null || true)
fi

if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    TARGET_USER=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)
fi

if [[ -n "$TARGET_USER" ]]; then
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    TARGET_UID=$(id -u "$TARGET_USER" 2>/dev/null || echo "")
else
    TARGET_HOME=""
    TARGET_UID=""
fi

# -------------------- LOG --------------------

LOG_FILE="/var/log/linux-turkce.log"

touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# -------------------- YARDIMCI --------------------

pause() {
    echo
    read -rp "Devam etmek için ENTER'a basın..."
}

ask_yes_no() {
    local QUESTION="$1"
    local ANSWER

    read -rp "$QUESTION [e/H]: " ANSWER

    [[ "$ANSWER" =~ ^[eE]$ ]]
}

package_exists() {
    apt-cache show "$1" >/dev/null 2>&1
}

package_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null |
        grep -q "install ok installed"
}

install_if_available() {
    local PACKAGE="$1"

    if package_exists "$PACKAGE"; then

        if package_installed "$PACKAGE"; then
            echo -e "${GREEN}[✓] $PACKAGE zaten kurulu.${RESET}"
        else
            echo -e "${CYAN}[+] $PACKAGE kuruluyor...${RESET}"

            if apt-get install -y "$PACKAGE"; then
                echo -e "${GREEN}[✓] $PACKAGE kuruldu.${RESET}"
                log "Kuruldu: $PACKAGE"
            else
                echo -e "${RED}[!] $PACKAGE kurulamadı.${RESET}"
                log "Kurulum başarısız: $PACKAGE"
            fi
        fi

        return 0
    fi

    echo -e "${YELLOW}[-] $PACKAGE bu sistemin depolarında bulunamadı.${RESET}"
    return 1
}

# -------------------- YEDEK --------------------

create_backup() {

    BACKUP_DIR="/root/linux-turkce-backup-$(date '+%Y%m%d-%H%M%S')"

    mkdir -p "$BACKUP_DIR"

    echo -e "${CYAN}Sistem ayarları yedekleniyor...${RESET}"

    [[ -f /etc/locale.gen ]] &&
        cp /etc/locale.gen "$BACKUP_DIR/"

    [[ -f /etc/default/locale ]] &&
        cp /etc/default/locale "$BACKUP_DIR/"

    [[ -f /etc/default/keyboard ]] &&
        cp /etc/default/keyboard "$BACKUP_DIR/"

    [[ -f /etc/hostname ]] &&
        cp /etc/hostname "$BACKUP_DIR/"

    [[ -f /etc/hosts ]] &&
        cp /etc/hosts "$BACKUP_DIR/"

    echo -e "${GREEN}Yedek oluşturuldu:${RESET}"
    echo "$BACKUP_DIR"

    log "Yedek oluşturuldu: $BACKUP_DIR"
}

# ================================================================
# TÜRKÇE LOCALE
# ================================================================

configure_locale() {

    echo
    echo -e "${BLUE}=== TÜRKÇE SİSTEM DİLİ ===${RESET}"
    echo

    create_backup

    install_if_available locales

    if [[ ! -f /etc/locale.gen ]]; then
        echo -e "${RED}/etc/locale.gen bulunamadı.${RESET}"
        return
    fi

    if grep -qE '^# *tr_TR\.UTF-8 UTF-8' /etc/locale.gen; then
        sed -i -E 's/^# *tr_TR\.UTF-8 UTF-8/tr_TR.UTF-8 UTF-8/' \
            /etc/locale.gen
    elif ! grep -qE '^tr_TR\.UTF-8 UTF-8' /etc/locale.gen; then
        echo "tr_TR.UTF-8 UTF-8" >> /etc/locale.gen
    fi

    echo
    echo "Türkçe locale oluşturuluyor..."

    locale-gen tr_TR.UTF-8

    cat > /etc/default/locale <<EOF
LANG=tr_TR.UTF-8
LANGUAGE=tr_TR:tr
LC_CTYPE=tr_TR.UTF-8
LC_NUMERIC=tr_TR.UTF-8
LC_TIME=tr_TR.UTF-8
LC_COLLATE=tr_TR.UTF-8
LC_MONETARY=tr_TR.UTF-8
LC_MESSAGES=tr_TR.UTF-8
LC_PAPER=tr_TR.UTF-8
LC_NAME=tr_TR.UTF-8
LC_ADDRESS=tr_TR.UTF-8
LC_TELEPHONE=tr_TR.UTF-8
LC_MEASUREMENT=tr_TR.UTF-8
LC_IDENTIFICATION=tr_TR.UTF-8
EOF

    cat > /etc/profile.d/turkish-locale.sh <<'EOF'
export LANG=tr_TR.UTF-8
export LANGUAGE=tr_TR:tr
export LC_CTYPE=tr_TR.UTF-8
export LC_NUMERIC=tr_TR.UTF-8
export LC_TIME=tr_TR.UTF-8
export LC_COLLATE=tr_TR.UTF-8
export LC_MONETARY=tr_TR.UTF-8
export LC_MESSAGES=tr_TR.UTF-8
export LC_PAPER=tr_TR.UTF-8
export LC_MEASUREMENT=tr_TR.UTF-8
EOF

    chmod 644 /etc/profile.d/turkish-locale.sh

    echo
    echo -e "${GREEN}✓ Sistem dili Türkçe olarak ayarlandı.${RESET}"

    log "Türkçe locale yapılandırıldı."
}

# ================================================================
# KLAVYE
# ================================================================

configure_keyboard() {

    echo
    echo -e "${BLUE}=== TÜRKÇE Q KLAVYE ===${RESET}"
    echo

    create_backup

    install_if_available keyboard-configuration
    install_if_available console-setup

    cat > /etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="tr"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

    if command -v localectl >/dev/null 2>&1; then
        localectl set-keymap tr-q 2>/dev/null || true
        localectl set-x11-keymap tr pc105 "" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Türkçe Q klavye ayarlandı.${RESET}"

    log "Türkçe Q klavye ayarlandı."
}

# ================================================================
# GNOME
# ================================================================

configure_gnome() {

    echo
    echo -e "${BLUE}=== GNOME ===${RESET}"
    echo

    if ! command -v gsettings >/dev/null 2>&1; then
        echo -e "${YELLOW}GNOME/gsettings bulunamadı.${RESET}"
        return
    fi

    if [[ -z "$TARGET_USER" || -z "$TARGET_UID" ]]; then
        echo -e "${YELLOW}Grafik kullanıcı tespit edilemedi.${RESET}"
        return
    fi

    if [[ ! -S "/run/user/$TARGET_UID/bus" ]]; then
        echo -e "${YELLOW}Aktif GNOME oturumu bulunamadı.${RESET}"
        echo "Kullanıcı oturum açtıktan sonra bu ayar uygulanabilir."
        return
    fi

    runuser -u "$TARGET_USER" -- \
        env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" \
        gsettings set org.gnome.system.locale region "tr_TR.UTF-8" \
        2>/dev/null || true

    echo -e "${GREEN}✓ GNOME locale ayarı uygulandı.${RESET}"

    log "GNOME locale ayarı uygulandı."
}

# ================================================================
# KDE
# ================================================================

configure_kde() {

    echo
    echo -e "${BLUE}=== KDE PLASMA ===${RESET}"
    echo

    if [[ "${XDG_CURRENT_DESKTOP:-}" == *"KDE"* ||
          "${XDG_CURRENT_DESKTOP:-}" == *"Plasma"* ]]; then

        echo "KDE Plasma tespit edildi."

        install_if_available kde-l10n-tr

        echo
        echo -e "${GREEN}KDE için mevcut Türkçe paketler kontrol edildi.${RESET}"

    else
        echo "Aktif KDE Plasma oturumu tespit edilmedi."
    fi
}

# ================================================================
# FONTLAR
# ================================================================

configure_fonts() {

    echo
    echo -e "${BLUE}=== TÜRKÇE FONTLAR ===${RESET}"
    echo

    install_if_available fonts-noto-core
    install_if_available fonts-noto-extra
    install_if_available fonts-dejavu
    install_if_available fontconfig

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f
    fi

    echo -e "${GREEN}✓ Font önbelleği yenilendi.${RESET}"

    log "Türkçe fontlar yapılandırıldı."
}

# ================================================================
# CHROMIUM
# ================================================================

configure_chromium() {

    echo
    echo -e "${BLUE}=== CHROMIUM ===${RESET}"
    echo

    if ! command -v chromium >/dev/null 2>&1 &&
       ! command -v chromium-browser >/dev/null 2>&1; then

        echo "Chromium kurulu değil."

        if ask_yes_no "Chromium kurulsun mu?"; then

            if package_exists chromium; then
                apt-get install -y chromium
            else
                echo -e "${YELLOW}Chromium deposunda bulunamadı.${RESET}"
                return
            fi
        else
            return
        fi
    fi

    install_if_available chromium-l10n

    echo
    echo -e "${GREEN}✓ Chromium Türkçe desteği kontrol edildi.${RESET}"

    # Chromium çalışıyorsa dosyasına dokunmuyoruz.
    # Böylece çalışan tarayıcının ayar dosyası bozulmaz.

    echo
    echo "Chromium'da:"
    echo "Ayarlar → Dil → Türkçe"
    echo "seçilmelidir."

    log "Chromium Türkçe desteği kontrol edildi."
}

# ================================================================
# FIREFOX
# ================================================================

configure_firefox() {

    echo
    echo -e "${BLUE}=== FIREFOX ===${RESET}"
    echo

    if ! command -v firefox >/dev/null 2>&1 &&
       ! command -v firefox-esr >/dev/null 2>&1; then

        echo "Firefox kurulu değil."
        return
    fi

    if package_exists firefox-esr-l10n-tr; then
        install_if_available firefox-esr-l10n-tr
    fi

    if package_exists firefox-l10n-tr; then
        install_if_available firefox-l10n-tr
    fi

    echo -e "${GREEN}✓ Firefox Türkçe desteği kontrol edildi.${RESET}"

    log "Firefox Türkçe desteği kontrol edildi."
}

# ================================================================
# LIBREOFFICE
# ================================================================

configure_libreoffice() {

    echo
    echo -e "${BLUE}=== LIBREOFFICE ===${RESET}"
    echo

    if ! command -v libreoffice >/dev/null 2>&1; then
        echo "LibreOffice kurulu değil."
        return
    fi

    install_if_available libreoffice-l10n-tr

    echo -e "${GREEN}✓ LibreOffice Türkçe desteği kontrol edildi.${RESET}"

    log "LibreOffice Türkçe desteği kontrol edildi."
}

# ================================================================
# UYGULAMALAR
# ================================================================

configure_applications() {

    echo
    echo -e "${BLUE}=== UYGULAMA TÜRKÇELEŞTİRME ===${RESET}"
    echo

    configure_chromium
    configure_firefox
    configure_libreoffice

    echo
    echo "Ek olarak depoda bulunan Türkçe dil paketleri aranıyor."

    apt-cache search '(^|-)l10n-tr($|-)' 2>/dev/null |
        head -50

    echo
    echo -e "${GREEN}✓ Uygulama kontrolü tamamlandı.${RESET}"
}

# ================================================================
# TÜRKÇE MAN
# ================================================================

configure_man() {

    echo
    echo -e "${BLUE}=== TÜRKÇE MANUAL SAYFALARI ===${RESET}"
    echo

    install_if_available manpages-tr
    install_if_available manpages-tr-dev

    echo
    echo -e "${GREEN}✓ Türkçe man paketleri kontrol edildi.${RESET}"
}

# ================================================================
# SUDO
# ================================================================

grant_sudo() {

    echo
    echo -e "${BLUE}=== SUDO YETKİSİ ===${RESET}"
    echo

    if [[ -z "$TARGET_USER" ]]; then
        echo -e "${RED}Kullanıcı tespit edilemedi.${RESET}"
        return
    fi

    echo "Kullanıcı: $TARGET_USER"
    echo
    echo "Not: Kullanıcıyı doğrudan root yapmak yerine sudo grubuna"
    echo "eklemek daha güvenlidir."
    echo

    if ! ask_yes_no "$TARGET_USER kullanıcısına sudo yetkisi verilsin mi?"; then
        echo "İşlem iptal edildi."
        return
    fi

    if getent group sudo >/dev/null 2>&1; then

        usermod -aG sudo "$TARGET_USER"

        echo -e "${GREEN}✓ $TARGET_USER sudo grubuna eklendi.${RESET}"
        log "$TARGET_USER sudo grubuna eklendi."

    elif getent group wheel >/dev/null 2>&1; then

        usermod -aG wheel "$TARGET_USER"

        echo -e "${GREEN}✓ $TARGET_USER wheel grubuna eklendi.${RESET}"
        log "$TARGET_USER wheel grubuna eklendi."

    else
        echo -e "${RED}sudo/wheel grubu bulunamadı.${RESET}"
    fi

    echo
    echo "Değişikliğin aktif olması için oturum kapatılıp açılmalıdır."
}

# ================================================================
# SUDO KALDIR
# ================================================================

remove_sudo() {

    echo
    echo -e "${BLUE}=== SUDO YETKİSİNİ KALDIR ===${RESET}"
    echo

    read -rp "Kullanıcı adı: " USER

    if ! id "$USER" >/dev/null 2>&1; then
        echo -e "${RED}Kullanıcı bulunamadı.${RESET}"
        return
    fi

    if [[ "$USER" == "root" ]]; then
        echo "root için bu işlem yapılmaz."
        return
    fi

    if ask_yes_no "$USER kullanıcısının sudo yetkisi kaldırılsın mı?"; then

        if getent group sudo >/dev/null 2>&1; then
            gpasswd -d "$USER" sudo 2>/dev/null || true
        fi

        if getent group wheel >/dev/null 2>&1; then
            gpasswd -d "$USER" wheel 2>/dev/null || true
        fi

        echo -e "${GREEN}✓ Sudo yetkisi kaldırıldı.${RESET}"
        log "$USER sudo yetkisi kaldırıldı."
    fi
}

# ================================================================
# KULLANICI LİSTESİ
# ================================================================

list_users() {

    echo
    echo -e "${BLUE}=== NORMAL KULLANICILAR ===${RESET}"
    echo

    printf "%-20s %-10s %-30s\n" "KULLANICI" "UID" "HOME"
    echo "------------------------------------------------------------"

    awk -F: '$3 >= 1000 && $3 < 60000 {
        printf "%-20s %-10s %-30s\n",$1,$3,$6
    }' /etc/passwd
}

# ================================================================
# KULLANICI OLUŞTUR
# ================================================================

create_user() {

    echo
    echo -e "${BLUE}=== KULLANICI OLUŞTUR ===${RESET}"
    echo

    read -rp "Yeni kullanıcı adı: " NEW_USER

    if [[ ! "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "${RED}Geçersiz kullanıcı adı.${RESET}"
        return
    fi

    if id "$NEW_USER" >/dev/null 2>&1; then
        echo -e "${RED}Bu kullanıcı zaten mevcut.${RESET}"
        return
    fi

    if useradd -m -s /bin/bash "$NEW_USER"; then

        echo -e "${GREEN}✓ Kullanıcı oluşturuldu.${RESET}"

        passwd "$NEW_USER"

        echo
        if ask_yes_no "$NEW_USER kullanıcısına sudo yetkisi verilsin mi?"; then

            if getent group sudo >/dev/null 2>&1; then
                usermod -aG sudo "$NEW_USER"
            elif getent group wheel >/dev/null 2>&1; then
                usermod -aG wheel "$NEW_USER"
            fi

            echo -e "${GREEN}✓ Sudo yetkisi verildi.${RESET}"
        fi

        log "Yeni kullanıcı oluşturuldu: $NEW_USER"

    else
        echo -e "${RED}Kullanıcı oluşturulamadı.${RESET}"
    fi
}

# ================================================================
# ŞİFRE DEĞİŞTİR
# ================================================================

change_password() {

    echo
    echo -e "${BLUE}=== ŞİFRE DEĞİŞTİR ===${RESET}"
    echo

    read -rp "Kullanıcı adı: " USER

    if ! id "$USER" >/dev/null 2>&1; then
        echo -e "${RED}Kullanıcı bulunamadı.${RESET}"
        return
    fi

    passwd "$USER"

    log "$USER şifresi değiştirildi."
}

# ================================================================
# KULLANICI ADI DEĞİŞTİR
# ================================================================

change_username() {

    echo
    echo -e "${BLUE}=== KULLANICI ADI DEĞİŞTİR ===${RESET}"
    echo

    read -rp "Mevcut kullanıcı: " OLD_USER

    if ! id "$OLD_USER" >/dev/null 2>&1; then
        echo -e "${RED}Kullanıcı bulunamadı.${RESET}"
        return
    fi

    if [[ "$OLD_USER" == "root" ]]; then
        echo -e "${RED}root kullanıcı adı bu araçtan değiştirilmez.${RESET}"
        return
    fi

    # Aktif kullanıcıyı değiştirmeyi engelle
    if [[ "$OLD_USER" == "$TARGET_USER" ]]; then
        echo
        echo -e "${RED}Aktif oturumdaki kullanıcı değiştirilemez.${RESET}"
        echo "Önce başka bir yönetici hesabıyla oturum açın."
        return
    fi

    read -rp "Yeni kullanıcı adı: " NEW_USER

    if [[ ! "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "${RED}Geçersiz kullanıcı adı.${RESET}"
        return
    fi

    if id "$NEW_USER" >/dev/null 2>&1; then
        echo -e "${RED}Bu kullanıcı zaten mevcut.${RESET}"
        return
    fi

    echo
    echo "Eski kullanıcı : $OLD_USER"
    echo "Yeni kullanıcı : $NEW_USER"
    echo

    if ! ask_yes_no "Kullanıcı adı değiştirilsin mi?"; then
        return
    fi

    if usermod -l "$NEW_USER" "$OLD_USER"; then

        OLD_HOME=$(getent passwd "$NEW_USER" | cut -d: -f6)

        if [[ "$OLD_HOME" == "/home/$OLD_USER" &&
              -d "/home/$OLD_USER" ]]; then

            usermod -d "/home/$NEW_USER" -m "$NEW_USER"
        fi

        if getent group "$OLD_USER" >/dev/null 2>&1; then
            groupmod -n "$NEW_USER" "$OLD_USER" 2>/dev/null || true
        fi

        echo -e "${GREEN}✓ Kullanıcı adı değiştirildi.${RESET}"
        echo "Eski: $OLD_USER"
        echo "Yeni: $NEW_USER"

        log "Kullanıcı adı değiştirildi: $OLD_USER -> $NEW_USER"

    else
        echo -e "${RED}Kullanıcı adı değiştirilemedi.${RESET}"
    fi
}

# ================================================================
# KULLANICI SİL
# ================================================================

delete_user() {

    echo
    echo -e "${BLUE}=== KULLANICI SİL ===${RESET}"
    echo

    read -rp "Silinecek kullanıcı: " USER

    if ! id "$USER" >/dev/null 2>&1; then
        echo -e "${RED}Kullanıcı bulunamadı.${RESET}"
        return
    fi

    if [[ "$USER" == "root" ]]; then
        echo -e "${RED}root silinemez.${RESET}"
        return
    fi

    if [[ "$USER" == "$TARGET_USER" ]]; then
        echo -e "${RED}Aktif kullanıcı silinemez.${RESET}"
        return
    fi

    echo
    echo -e "${YELLOW}UYARI: Kullanıcı hesabı silinecek.${RESET}"
    echo

    if ask_yes_no "$USER kullanıcısı ve HOME dizini silinsin mi?"; then

        userdel -r "$USER"

        echo -e "${GREEN}✓ Kullanıcı silindi.${RESET}"
        log "Kullanıcı silindi: $USER"
    fi
}

# ================================================================
# HOSTNAME
# ================================================================

change_hostname() {

    echo
    echo -e "${BLUE}=== BİLGİSAYAR ADI ===${RESET}"
    echo

    CURRENT_HOST=$(hostname)

    echo "Mevcut hostname: $CURRENT_HOST"
    echo

    read -rp "Yeni hostname: " NEW_HOST

    if [[ ! "$NEW_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
        echo -e "${RED}Geçersiz hostname.${RESET}"
        return
    fi

    if ! ask_yes_no "Hostname '$NEW_HOST' olarak değiştirilsin mi?"; then
        return
    fi

    create_backup

    hostnamectl set-hostname "$NEW_HOST"

    echo -e "${GREEN}✓ Hostname değiştirildi.${RESET}"

    log "Hostname değiştirildi: $CURRENT_HOST -> $NEW_HOST"
}

# ================================================================
# SISTEM BİLGİLERİ
# ================================================================

system_info() {

    echo
    echo -e "${BLUE}================================================${RESET}"
    echo -e "${BLUE}                 SİSTEM BİLGİLERİ               ${RESET}"
    echo -e "${BLUE}================================================${RESET}"
    echo

    echo -e "${WHITE}Dağıtım:${RESET}"
    echo "${PRETTY_NAME:-Bilinmiyor}"

    echo
    echo -e "${WHITE}Kernel:${RESET}"
    uname -r

    echo
    echo -e "${WHITE}Mimari:${RESET}"
    uname -m

    echo
    echo -e "${WHITE}Hostname:${RESET}"
    hostname

    echo
    echo -e "${WHITE}Aktif kullanıcı:${RESET}"
    echo "${TARGET_USER:-Bilinmiyor}"

    echo
    echo -e "${WHITE}Locale:${RESET}"
    locale 2>/dev/null | head -15

    echo
    echo -e "${WHITE}Klavye:${RESET}"
    cat /etc/default/keyboard 2>/dev/null

    echo
    echo -e "${WHITE}Masaüstü:${RESET}"
    echo "${XDG_CURRENT_DESKTOP:-Tespit edilemedi}"

    echo
    echo -e "${WHITE}Shell:${RESET}"
    echo "${SHELL:-Bilinmiyor}"

    echo
    echo -e "${WHITE}Disk:${RESET}"
    df -h / | tail -1
}

# ================================================================
# TÜRKÇE PAKET ARAMA
# ================================================================

search_turkish_packages() {

    echo
    echo -e "${BLUE}=== TÜRKÇE DİL PAKETLERİ ===${RESET}"
    echo

    echo "Depolardaki Türkçe/l10n paketleri aranıyor..."
    echo

    apt-cache search 'tr$|tr-' 2>/dev/null |
        grep -Ei '(^| )(turkish|turkce|Türkçe|l10n.*tr|tr.*l10n)' |
        head -100

    echo
    echo "Doğrudan -tr paketleri:"
    echo

    apt-cache search '-tr$' 2>/dev/null |
        head -100
}

# ================================================================
# SİSTEM GÜNCELLEME
# ================================================================

update_package_list() {

    echo
    echo -e "${BLUE}=== PAKET LİSTESİNİ GÜNCELLE ===${RESET}"
    echo

    echo "apt update çalıştırılacak."
    echo "Bu işlem kurulu paketleri yükseltmez."

    if ask_yes_no "Devam edilsin mi?"; then

        apt-get update

        echo
        echo -e "${GREEN}✓ Paket listesi güncellendi.${RESET}"

        log "apt update çalıştırıldı."
    fi
}

# ================================================================
# TÜRKÇE TAM KURULUM
# ================================================================

full_turkish_setup() {

    echo
    echo -e "${CYAN}================================================${RESET}"
    echo -e "${CYAN}          TAM TÜRKÇE SİSTEM KURULUMU            ${RESET}"
    echo -e "${CYAN}================================================${RESET}"
    echo

    echo "Bu işlem:"
    echo " • Türkçe locale"
    echo " • Türkçe Q klavye"
    echo " • Türkçe fontlar"
    echo " • GNOME/KDE ayarları"
    echo " • Chromium"
    echo " • Firefox"
    echo " • LibreOffice"
    echo " • Türkçe man sayfaları"
    echo "desteğini kontrol edecektir."
    echo
    echo "Mevcut olmayan paketler zorla kurulmayacaktır."
    echo

    if ! ask_yes_no "Devam edilsin mi?"; then
        return
    fi

    create_backup

    configure_locale
    configure_keyboard
    configure_fonts
    configure_gnome
    configure_kde
    configure_chromium
    configure_firefox
    configure_libreoffice
    configure_man

    echo
    echo -e "${GREEN}================================================${RESET}"
    echo -e "${GREEN}          TÜRKÇE KURULUM TAMAMLANDI             ${RESET}"
    echo -e "${GREEN}================================================${RESET}"
    echo
    echo "Bazı uygulamalar dili yeni oturum açıldığında algılar."
    echo "Sistemi yeniden başlatmanız önerilir."

    log "Tam Türkçe kurulum tamamlandı."
}

# ================================================================
# YENİDEN BAŞLAT
# ================================================================

reboot_system() {

    echo
    echo -e "${YELLOW}Sistem yeniden başlatılacak.${RESET}"
    echo

    if ask_yes_no "Şimdi yeniden başlatılsın mı?"; then

        log "Sistem yeniden başlatılıyor."

        sync
        reboot
    fi
}

# ================================================================
# KULLANICI MENÜSÜ
# ================================================================

user_menu() {

    while true; do

        clear

        echo
        echo -e "${CYAN}============================================================${RESET}"
        echo -e "${CYAN}                    KULLANICI YÖNETİMİ                       ${RESET}"
        echo -e "${CYAN}============================================================${RESET}"
        echo
        echo " 1) Kullanıcıları listele"
        echo " 2) Kullanıcı oluştur"
        echo " 3) Kullanıcı şifresi değiştir"
        echo " 4) Kullanıcı adı değiştir"
        echo " 5) Kullanıcı sil"
        echo " 6) Sudo yetkisi ver"
        echo " 7) Sudo yetkisini kaldır"
        echo " 0) Geri"
        echo

        read -rp "Seçim: " CHOICE

        case "$CHOICE" in

            1) list_users; pause ;;
            2) create_user; pause ;;
            3) change_password; pause ;;
            4) change_username; pause ;;
            5) delete_user; pause ;;
            6) grant_sudo; pause ;;
            7) remove_sudo; pause ;;
            0) return ;;
            *) echo "Geçersiz seçim."; sleep 1 ;;

        esac

    done
}

# ================================================================
# ANA MENÜ
# ================================================================

while true; do

    clear

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║        LINUX TÜRKÇELEŞTİRME & YÖNETİM ARACI             ║${RESET}"
    echo -e "${CYAN}║                         v$VERSION                         ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET} Sistem   : ${WHITE}${PRETTY_NAME:-Bilinmiyor}${RESET}"
    echo -e "${CYAN}║${RESET} Kullanıcı: ${WHITE}${TARGET_USER:-Bilinmiyor}${RESET}"
    echo -e "${CYAN}║${RESET} Hostname : ${WHITE}$(hostname)${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  1) 🇹🇷 Tam Türkçe sistem kurulumu"
    echo -e "${CYAN}║${RESET}  2) 🌍 Sistem dili / Locale"
    echo -e "${CYAN}║${RESET}  3) ⌨️  Türkçe Q klavye"
    echo -e "${CYAN}║${RESET}  4) 🖥️  GNOME / KDE ayarları"
    echo -e "${CYAN}║${RESET}  5) 🌐 Uygulamaları Türkçeleştir"
    echo -e "${CYAN}║${RESET}  6) 🔤 Türkçe fontları kur"
    echo -e "${CYAN}║${RESET}  7) 📖 Türkçe man sayfaları"
    echo -e "${CYAN}║${RESET}  8) 🔎 Türkçe paketleri ara"
    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  9) 👤 Kullanıcı yönetimi"
    echo -e "${CYAN}║${RESET} 10) 💻 Hostname değiştir"
    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} 11) 📊 Sistem bilgileri"
    echo -e "${CYAN}║${RESET} 12) 🔄 Paket listesini güncelle"
    echo -e "${CYAN}║${RESET} 13) 🔁 Yeniden başlat"
    echo -e "${CYAN}║${RESET}  0) ❌ Çıkış"
    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo

    read -rp "Seçiminiz: " CHOICE

    case "$CHOICE" in

        1)
            full_turkish_setup
            pause
            ;;

        2)
            configure_locale
            pause
            ;;

        3)
            configure_keyboard
            pause
            ;;

        4)
            configure_gnome
            configure_kde
            pause
            ;;

        5)
            configure_applications
            pause
            ;;

        6)
            configure_fonts
            pause
            ;;

        7)
            configure_man
            pause
            ;;

        8)
            search_turkish_packages
            pause
            ;;

        9)
            user_menu
            ;;

        10)
            change_hostname
            pause
            ;;

        11)
            system_info
            pause
            ;;

        12)
            update_package_list
            pause
            ;;

        13)
            reboot_system
            ;;

        0)
            echo
            echo -e "${GREEN}Çıkış yapılıyor.${RESET}"
            exit 0
            ;;

        *)
            echo -e "${RED}Geçersiz seçim.${RESET}"
            sleep 1
            ;;

    esac

done
