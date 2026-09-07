#!/usr/bin/env bash

# ================================================================
# KALI LINUX TÜRKÇELEŞTİRME & SİSTEM YÖNETİM ARACI
# Kali Linux / Debian / Ubuntu
# Tek dosya sürümü
# GitHub + curl | sudo bash uyumlu
# ================================================================

set -o pipefail

VERSION="4.0"

# ================================================================
# RENKLER
# ================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
RESET='\033[0m'

# ================================================================
# ROOT KONTROLÜ
# ================================================================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Bu program root yetkisi gerektiriyor.${RESET}"
    echo
    echo "Kullanım:"
    echo "sudo bash $0"
    exit 1
fi

# ================================================================
# SİSTEM KONTROLÜ
# ================================================================

if [[ ! -r /etc/os-release ]]; then
    echo -e "${RED}İşletim sistemi tespit edilemedi.${RESET}"
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

if ! command -v apt-get >/dev/null 2>&1; then
    echo -e "${RED}Bu araç APT tabanlı sistemler içindir.${RESET}"
    exit 1
fi

if ! command -v dpkg >/dev/null 2>&1; then
    echo -e "${RED}dpkg bulunamadı.${RESET}"
    exit 1
fi

# ================================================================
# GLOBAL DEĞİŞKENLER
# ================================================================

LOG_FILE="/var/log/linux-turkce.log"
BACKUP_DIR=""
TARGET_USER=""
TARGET_UID=""
TARGET_HOME=""
DESKTOP=""

# ================================================================
# LOG
# ================================================================

touch "$LOG_FILE" 2>/dev/null || true
chmod 600 "$LOG_FILE" 2>/dev/null || true

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ================================================================
# HATA YAKALAMA
# ================================================================

trap 'log "Hata oluştu. Satır: $LINENO Komut: $BASH_COMMAND"' ERR

# ================================================================
# AKTİF / HEDEF KULLANICI TESPİTİ
# ================================================================

detect_target_user() {

    TARGET_USER=""
    TARGET_UID=""
    TARGET_HOME=""

    # sudo ile çalıştırıldıysa gerçek kullanıcı
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        if id "${SUDO_USER}" >/dev/null 2>&1; then
            TARGET_USER="$SUDO_USER"
        fi
    fi

    # logname
    if [[ -z "$TARGET_USER" ]]; then
        local LOGIN_USER=""
        LOGIN_USER="$(logname 2>/dev/null || true)"

        if [[ -n "$LOGIN_USER" &&
              "$LOGIN_USER" != "root" ]] &&
           id "$LOGIN_USER" >/dev/null 2>&1; then
            TARGET_USER="$LOGIN_USER"
        fi
    fi

    # /dev/console sahibi
    if [[ -z "$TARGET_USER" && -e /dev/console ]]; then
        local CONSOLE_USER=""
        CONSOLE_USER="$(stat -c '%U' /dev/console 2>/dev/null || true)"

        if [[ -n "$CONSOLE_USER" &&
              "$CONSOLE_USER" != "root" ]] &&
           id "$CONSOLE_USER" >/dev/null 2>&1; then
            TARGET_USER="$CONSOLE_USER"
        fi
    fi

    # İlk normal kullanıcı
    if [[ -z "$TARGET_USER" ]]; then
        TARGET_USER="$(
            awk -F: '
                $3 >= 1000 && $3 < 60000 &&
                $1 != "nobody" {
                    print $1
                    exit
                }
            ' /etc/passwd
        )"
    fi

    if [[ -n "$TARGET_USER" ]]; then
        TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || true)"
        TARGET_HOME="$(getent passwd "$TARGET_USER" |
            cut -d: -f6)"
    fi
}

detect_target_user

# ================================================================
# MASAÜSTÜ TESPİTİ
# ================================================================

detect_desktop() {

    DESKTOP="Bilinmiyor"

    local DESKTOP_TEXT=""

    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        DESKTOP_TEXT="${XDG_CURRENT_DESKTOP}"
    elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
        DESKTOP_TEXT="${DESKTOP_SESSION}"
    elif [[ -n "$TARGET_USER" ]]; then
        DESKTOP_TEXT="$(
            runuser -u "$TARGET_USER" -- \
            env XDG_CURRENT_DESKTOP="" \
            DESKTOP_SESSION="" \
            bash -c '
                printf "%s" "${XDG_CURRENT_DESKTOP:-}"
                printf " %s" "${DESKTOP_SESSION:-}"
            ' 2>/dev/null || true
        )"
    fi

    if [[ "$DESKTOP_TEXT" =~ [Gg][Nn][Oo][Mm][Ee] ]]; then
        DESKTOP="GNOME"
    elif [[ "$DESKTOP_TEXT" =~ [Kk][Dd][Ee]|[Pp]lasma ]]; then
        DESKTOP="KDE Plasma"
    elif [[ "$DESKTOP_TEXT" =~ [Xx][Ff][Cc][Ee] ]]; then
        DESKTOP="XFCE"
    elif [[ "$DESKTOP_TEXT" =~ [Ll][Xx][Qq][Tt] ]]; then
        DESKTOP="LXQt"
    elif [[ "$DESKTOP_TEXT" =~ [Cc]innamon ]]; then
        DESKTOP="Cinnamon"
    else
        DESKTOP="$DESKTOP_TEXT"
    fi
}

detect_desktop

# ================================================================
# YARDIMCI
# ================================================================

pause() {
    echo
    read -r -p "Devam etmek için ENTER'a basın..."
}

ask_yes_no() {

    local QUESTION="$1"
    local ANSWER=""

    while true; do

        read -r -p "$QUESTION [E/h]: " ANSWER

        case "$ANSWER" in
            e|E|evet|EVET|y|Y|yes|YES)
                return 0
                ;;
            h|H|hayır|HAYIR|n|N|no|NO|"")
                return 1
                ;;
            *)
                echo -e "${YELLOW}Lütfen E veya H girin.${RESET}"
                ;;
        esac
    done
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_exists() {

    local PACKAGE="$1"

    apt-cache show "$PACKAGE" >/dev/null 2>&1
}

package_installed() {

    local PACKAGE="$1"

    dpkg-query \
        -W \
        -f='${Status}' \
        "$PACKAGE" 2>/dev/null |
        grep -q "install ok installed"
}

install_if_available() {

    local PACKAGE="$1"

    if package_installed "$PACKAGE"; then
        echo -e "${GREEN}[✓] $PACKAGE zaten kurulu.${RESET}"
        return 0
    fi

    if ! package_exists "$PACKAGE"; then
        echo -e "${YELLOW}[-] $PACKAGE depoda bulunamadı.${RESET}"
        return 1
    fi

    echo -e "${CYAN}[+] $PACKAGE kuruluyor...${RESET}"

    if apt-get install -y "$PACKAGE"; then
        echo -e "${GREEN}[✓] $PACKAGE kuruldu.${RESET}"
        log "Paket kuruldu: $PACKAGE"
        return 0
    fi

    echo -e "${RED}[!] $PACKAGE kurulamadı.${RESET}"
    log "Paket kurulamadı: $PACKAGE"
    return 1
}

# ================================================================
# APT KİLİT KONTROLÜ
# ================================================================

check_apt_lock() {

    if command_exists fuser; then

        if fuser \
            /var/lib/dpkg/lock-frontend \
            /var/lib/apt/lists/lock \
            /var/cache/apt/archives/lock \
            >/dev/null 2>&1; then

            echo -e "${YELLOW}APT başka bir işlem tarafından kullanılıyor.${RESET}"
            echo "Lütfen diğer paket yöneticisini kapatın."
            return 1
        fi
    fi

    return 0
}

# ================================================================
# YEDEKLEME
# ================================================================

create_backup() {

    if [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]]; then
        return 0
    fi

    BACKUP_DIR="/root/linux-turkce-backup-$(date '+%Y%m%d-%H%M%S')"

    mkdir -p "$BACKUP_DIR"

    echo -e "${CYAN}Sistem ayarları yedekleniyor...${RESET}"

    local FILE

    for FILE in \
        /etc/locale.gen \
        /etc/default/locale \
        /etc/default/keyboard \
        /etc/hostname \
        /etc/hosts
    do

        if [[ -f "$FILE" ]]; then
            cp -a "$FILE" "$BACKUP_DIR/" 2>/dev/null || true
        fi

    done

    if [[ -f /etc/profile.d/turkish-locale.sh ]]; then
        cp -a \
            /etc/profile.d/turkish-locale.sh \
            "$BACKUP_DIR/" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Yedek oluşturuldu:${RESET}"
    echo "$BACKUP_DIR"

    log "Yedek oluşturuldu: $BACKUP_DIR"
}

# ================================================================
# APT UPDATE
# ================================================================

update_package_list_silent() {

    echo -e "${CYAN}[+] Paket listesi kontrol ediliyor...${RESET}"

    if ! check_apt_lock; then
        return 1
    fi

    if apt-get update; then
        echo -e "${GREEN}[✓] Paket listesi güncellendi.${RESET}"
        log "apt update başarılı."
        return 0
    fi

    echo -e "${RED}[!] apt update başarısız.${RESET}"
    log "apt update başarısız."
    return 1
}

# ================================================================
# LOCALE
# ================================================================

configure_locale() {

    echo
    echo -e "${BLUE}=== TÜRKÇE SİSTEM DİLİ ===${RESET}"
    echo

    create_backup

    install_if_available locales || true

    if [[ ! -f /etc/locale.gen ]]; then
        echo -e "${RED}/etc/locale.gen bulunamadı.${RESET}"
        return 1
    fi

    if grep -qE '^[[:space:]]*#?[[:space:]]*tr_TR\.UTF-8[[:space:]]+UTF-8' \
        /etc/locale.gen; then

        sed -i -E \
            's/^[[:space:]]*#[[:space:]]*(tr_TR\.UTF-8[[:space:]]+UTF-8)/\1/' \
            /etc/locale.gen

    elif ! grep -qE '^[[:space:]]*tr_TR\.UTF-8[[:space:]]+UTF-8' \
        /etc/locale.gen; then

        echo "tr_TR.UTF-8 UTF-8" >> /etc/locale.gen
    fi

    if command_exists locale-gen; then

        if locale-gen tr_TR.UTF-8; then
            echo -e "${GREEN}✓ Türkçe locale oluşturuldu.${RESET}"
        else
            echo -e "${RED}Locale oluşturulamadı.${RESET}"
            return 1
        fi

    else
        echo -e "${RED}locale-gen bulunamadı.${RESET}"
        return 1
    fi

    # LANGUAGE öncelikli olarak Türkçe.
    # LC_ALL özellikle ayarlanmıyor.
    cat > /etc/default/locale <<'EOF'
LANG=tr_TR.UTF-8
LANGUAGE=tr_TR:tr:en
EOF

    cat > /etc/profile.d/turkish-locale.sh <<'EOF'
export LANG=tr_TR.UTF-8
export LANGUAGE=tr_TR:tr:en
EOF

    chmod 644 /etc/profile.d/turkish-locale.sh

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

    install_if_available keyboard-configuration || true
    install_if_available console-setup || true

    cat > /etc/default/keyboard <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="tr"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

    if command_exists dpkg-reconfigure; then
        DEBIAN_FRONTEND=noninteractive \
            dpkg-reconfigure keyboard-configuration \
            >/dev/null 2>&1 || true
    fi

    if command_exists localectl; then

        localectl set-x11-keymap \
            tr \
            pc105 \
            "" \
            "" \
            >/dev/null 2>&1 || true

        localectl set-keymap tr \
            >/dev/null 2>&1 || true
    fi

    echo -e "${GREEN}✓ Türkçe Q klavye yapılandırıldı.${RESET}"

    log "Türkçe Q klavye yapılandırıldı."
}

# ================================================================
# GNOME
# ================================================================

configure_gnome() {

    echo
    echo -e "${BLUE}=== GNOME ===${RESET}"
    echo

    if [[ "$DESKTOP" != "GNOME" &&
          "$DESKTOP" != *"GNOME"* ]]; then

        echo "Aktif GNOME masaüstü tespit edilmedi."
        return 0
    fi

    if [[ -z "$TARGET_USER" ]]; then
        echo -e "${YELLOW}Grafik kullanıcı bulunamadı.${RESET}"
        return 1
    fi

    if ! command_exists gsettings; then
        echo -e "${YELLOW}gsettings bulunamadı.${RESET}"
        return 1
    fi

    local USER_UID
    USER_UID="$(id -u "$TARGET_USER" 2>/dev/null || true)"

    if [[ -z "$USER_UID" ]]; then
        return 1
    fi

    if [[ ! -S "/run/user/$USER_UID/bus" ]]; then
        echo -e "${YELLOW}Aktif GNOME D-Bus oturumu bulunamadı.${RESET}"
        echo "Kullanıcı grafik oturumu açtıktan sonra ayar uygulanabilir."
        return 0
    fi

    runuser -u "$TARGET_USER" -- \
        env \
        HOME="$TARGET_HOME" \
        USER="$TARGET_USER" \
        LOGNAME="$TARGET_USER" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_UID/bus" \
        gsettings set \
        org.gnome.desktop.input-sources \
        sources \
        "[('xkb', 'tr')]" \
        >/dev/null 2>&1 || true

    echo -e "${GREEN}✓ GNOME Türkçe klavye ayarı uygulandı.${RESET}"

    log "GNOME yapılandırıldı."
}

# ================================================================
# KDE
# ================================================================

configure_kde() {

    echo
    echo -e "${BLUE}=== KDE PLASMA ===${RESET}"
    echo

    if [[ "$DESKTOP" != *"KDE"* &&
          "$DESKTOP" != *"Plasma"* ]]; then

        echo "Aktif KDE Plasma masaüstü tespit edilmedi."
        return 0
    fi

    echo "KDE Plasma tespit edildi."

    # Modern Debian/Kali sistemlerinde eski kde-l10n-tr
    # paketi bulunmayabilir. Varsa kurulur.
    install_if_available kde-l10n-tr || true

    # KDE language pack alternatifleri
    install_if_available language-pack-kde-tr || true

    echo -e "${GREEN}✓ KDE Türkçe paketleri kontrol edildi.${RESET}"

    log "KDE Türkçe paketleri kontrol edildi."
}

# ================================================================
# FONTLAR
# ================================================================

configure_fonts() {

    echo
    echo -e "${BLUE}=== TÜRKÇE FONTLAR ===${RESET}"
    echo

    install_if_available fonts-noto-core || true
    install_if_available fonts-noto-extra || true
    install_if_available fonts-dejavu || true
    install_if_available fontconfig || true

    if command_exists fc-cache; then
        fc-cache -f >/dev/null 2>&1 || true
    fi

    echo -e "${GREEN}✓ Font yapılandırması tamamlandı.${RESET}"

    log "Font yapılandırması tamamlandı."
}

# ================================================================
# CHROMIUM
# ================================================================

configure_chromium() {

    echo
    echo -e "${BLUE}=== CHROMIUM ===${RESET}"
    echo

    local CHROMIUM_BIN=""

    if command_exists chromium; then
        CHROMIUM_BIN="chromium"
    elif command_exists chromium-browser; then
        CHROMIUM_BIN="chromium-browser"
    fi

    if [[ -z "$CHROMIUM_BIN" ]]; then

        echo "Chromium kurulu değil."

        if ask_yes_no "Chromium kurulsun mu?"; then

            if ! check_apt_lock; then
                return 1
            fi

            if package_exists chromium; then

                if apt-get install -y chromium; then
                    CHROMIUM_BIN="chromium"
                else
                    echo -e "${RED}Chromium kurulamadı.${RESET}"
                    return 1
                fi

            else
                echo -e "${YELLOW}Chromium APT depolarında bulunamadı.${RESET}"
                return 1
            fi

        else
            return 0
        fi
    fi

    install_if_available chromium-l10n || true

    echo -e "${GREEN}✓ Chromium Türkçe dil paketi kontrol edildi.${RESET}"
    echo
    echo "Chromium'u yeniden başlattıktan sonra:"
    echo "Ayarlar → Diller → Türkçe"

    log "Chromium Türkçe desteği kontrol edildi."
}

# ================================================================
# FIREFOX
# ================================================================

configure_firefox() {

    echo
    echo -e "${BLUE}=== FIREFOX ===${RESET}"
    echo

    if ! command_exists firefox &&
       ! command_exists firefox-esr; then

        echo "Firefox kurulu değil."
        return 0
    fi

    local INSTALLED=0

    if package_exists firefox-esr-l10n-tr; then
        install_if_available firefox-esr-l10n-tr || true
        INSTALLED=1
    fi

    if package_exists firefox-l10n-tr; then
        install_if_available firefox-l10n-tr || true
        INSTALLED=1
    fi

    if [[ "$INSTALLED" -eq 0 ]]; then
        echo -e "${YELLOW}Uygun Firefox Türkçe paketi depoda bulunamadı.${RESET}"
    else
        echo -e "${GREEN}✓ Firefox Türkçe desteği kontrol edildi.${RESET}"
    fi

    echo "Firefox'u yeniden başlatmanız gerekebilir."

    log "Firefox Türkçe desteği kontrol edildi."
}

# ================================================================
# LIBREOFFICE
# ================================================================

configure_libreoffice() {

    echo
    echo -e "${BLUE}=== LIBREOFFICE ===${RESET}"
    echo

    if ! command_exists libreoffice; then
        echo "LibreOffice kurulu değil."
        return 0
    fi

    install_if_available libreoffice-l10n-tr || true

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
    echo -e "${GREEN}✓ Uygulama dil desteği kontrolü tamamlandı.${RESET}"

    log "Uygulama Türkçe desteği kontrol edildi."
}

# ================================================================
# TÜRKÇE MAN
# ================================================================

configure_man() {

    echo
    echo -e "${BLUE}=== TÜRKÇE MAN SAYFALARI ===${RESET}"
    echo

    install_if_available manpages-tr || true
    install_if_available manpages-tr-dev || true

    echo -e "${GREEN}✓ Türkçe man paketleri kontrol edildi.${RESET}"

    log "Türkçe man paketleri kontrol edildi."
}

# ================================================================
# SUDO YETKİSİ VER
# ================================================================

grant_sudo() {

    echo
    echo -e "${BLUE}=== SUDO YETKİSİ VER ===${RESET}"
    echo

    local USER=""

    read -r -p "Kullanıcı adı: " USER

    if [[ -z "$USER" ]]; then
        return 1
    fi

    if ! id "$USER" >/dev/null 2>&1; then
        echo -e "${RED}Kullanıcı bulunamadı.${RESET}"
        return 1
    fi

    if [[ "$USER" == "root" ]]; then
        echo "root zaten yönetici."
        return 0
    fi

    if getent group sudo >/dev/null 2>&1; then

        if usermod -aG sudo "$USER"; then
            echo -e "${GREEN}✓ $USER sudo grubuna eklendi.${RESET}"
            log "$USER sudo grubuna eklendi."
        fi

    elif getent group wheel >/dev/null 2>&1; then

        if usermod -aG wheel "$USER"; then
            echo -e "${GREEN}✓ $USER wheel grubuna eklendi.${RESET}"
            log "$USER wheel grubuna eklendi."
        fi

    else
        echo -e "${RED}sudo/wheel grubu bulunamadı.${RESET}"
        return 1
    fi

    echo
    echo "Değişikliğin aktif olması için kullanıcı oturumunu"
    echo "kapatıp tekrar açmalıdır."
}

# ================================================================
# SUDO YETKİSİ KALDIR
# ================================================================

remove_sudo() {

    echo
    echo -e "${BLUE}=== SUDO YETKİSİNİ KALDIR ===${RESET}"
    echo

    local USER=""

    read -r -p "Kullanıcı adı: " USER

    if ! id "$USER" >/dev/null 2>&1; then
        echo -e "${RED}Kullanıcı bulunamadı.${RESET}"
        return 1
    fi

    if [[ "$USER" == "root" ]]; then
        echo "root için işlem yapılmaz."
        return 0
    fi

    if ! ask_yes_no "$USER kullanıcısının sudo yetkisi kaldırılsın mı?"; then
        return 0
    fi

    if getent group sudo >/dev/null 2>&1; then
        gpasswd -d "$USER" sudo >/dev/null 2>&1 || true
    fi

    if getent group wheel >/dev/null 2>&1; then
        gpasswd -d "$USER" wheel >/dev/null 2>&1 || true
    fi

    echo -e "${GREEN}✓ Grup tabanlı sudo yetkisi kaldırıldı.${RESET}"

    log "$USER sudo/wheel gruplarından çıkarıldı."
}

# ================================================================
# KULLANICI LİSTELE
# ================================================================

list_users() {

    echo
    echo -e "${BLUE}=== NORMAL KULLANICILAR ===${RESET}"
    echo

    printf "%-22s %-8s %-35s\n" \
        "KULLANICI" "UID" "HOME"

    echo "----------------------------------------------------------------"

    awk -F: '
        $3 >= 1000 && $3 < 60000 {
            printf "%-22s %-8s %-35s\n",$1,$3,$6
        }
    ' /etc/passwd
}

# ================================================================
# KULLANICI OLUŞTUR
# ================================================================

create_user() {

    echo
    echo -e "${BLUE}=== KULLANICI OLUŞTUR ===${RESET}"
    echo

    local NEW_USER=""

    read -r -p "Yeni kullanıcı adı: " NEW_USER

    if [[ ! "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "${RED}Geçersiz kullanıcı adı.${RESET}"
        return 1
    fi

    if id "$NEW_USER" >/dev/null 2>&1; then
        echo -e "${RED}Bu kullanıcı zaten mevcut.${RESET}"
        return 1
    fi

    if ! useradd \
        -m \
        -s /bin/bash \
        "$NEW_USER"; then

        echo -e "${RED}Kullanıcı oluşturulamadı.${RESET}"
        return 1
    fi

    echo -e "${GREEN}✓ Kullanıcı oluşturuldu.${RESET}"

    if ! passwd "$NEW_USER"; then
        echo -e "${YELLOW}Şifre ayarlanamadı.${RESET}"
    fi

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
}

# ================================================================
# ŞİFRE DEĞİŞTİR
# ================================================================

change_password() {

    echo
    echo -e "${BLUE}=== ŞİFRE DEĞİŞTİR ===${RESET}"
    echo

    local USER=""

    read -r -p "Kullanıcı adı: " USER

    if ! id "$USER" >/dev/null 2>&1; then
        echo -e "${RED}Kullanıcı bulunamadı.${RESET}"
        return 1
    fi

    if passwd "$USER"; then
        echo -e "${GREEN}✓ Şifre değiştirildi.${RESET}"
        log "$USER şifresi değiştirildi."
    else
        echo -e "${RED}Şifre değiştirilemedi.${RESET}"
        return 1
    fi
}

# ================================================================
# KULLANICI ADI DEĞİŞTİR
# ================================================================

change_username() {

    echo
    echo -e "${BLUE}=== KULLANICI ADI DEĞİŞTİR ===${RESET}"
    echo

    local OLD_USER=""
    local NEW_USER=""
    local OLD_HOME=""
    local NEW_HOME=""

    read -r -p "Mevcut kullanıcı: " OLD_USER

    if ! id "$OLD_USER" >/dev/null 2>&1; then
        echo -e "${RED}Kullanıcı bulunamadı.${RESET}"
        return 1
    fi

    if [[ "$OLD_USER" == "root" ]]; then
        echo -e "${RED}root kullanıcı adı değiştirilemez.${RESET}"
        return 1
    fi

    if [[ "$OLD_USER" == "$TARGET_USER" ]]; then
        echo
        echo -e "${RED}Aktif kullanıcı değiştirilemez.${RESET}"
        echo "Başka bir yönetici hesabıyla oturum açın."
        return 1
    fi

    # Çalışan süreç kontrolü
    if command_exists pgrep; then

        if pgrep -u "$OLD_USER" >/dev/null 2>&1; then
            echo -e "${RED}Kullanıcının çalışan süreçleri var.${RESET}"
            echo "Önce kullanıcı oturumunu kapatın."
            return 1
        fi
    fi

    read -r -p "Yeni kullanıcı adı: " NEW_USER

    if [[ ! "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -e "${RED}Geçersiz kullanıcı adı.${RESET}"
        return 1
    fi

    if id "$NEW_USER" >/dev/null 2>&1; then
        echo -e "${RED}Bu kullanıcı zaten mevcut.${RESET}"
        return 1
    fi

    OLD_HOME="$(getent passwd "$OLD_USER" | cut -d: -f6)"
    NEW_HOME="/home/$NEW_USER"

    echo
    echo "Eski kullanıcı : $OLD_USER"
    echo "Yeni kullanıcı : $NEW_USER"
    echo "Eski HOME      : $OLD_HOME"
    echo "Yeni HOME      : $NEW_HOME"
    echo

    if ! ask_yes_no "Değişiklik yapılsın mı?"; then
        return 0
    fi

    create_backup

    if ! usermod -l "$NEW_USER" "$OLD_USER"; then
        echo -e "${RED}Kullanıcı adı değiştirilemedi.${RESET}"
        return 1
    fi

    # Home dizini standart /home/OLD_USER ise taşı.
    if [[ "$OLD_HOME" == "/home/$OLD_USER" &&
          -d "$OLD_HOME" ]]; then

        if usermod -d "$NEW_HOME" -m "$NEW_USER"; then
            echo -e "${GREEN}✓ HOME dizini taşındı.${RESET}"
        else
            echo -e "${YELLOW}HOME dizini taşınamadı.${RESET}"
        fi
    fi

    # Aynı isimde primary group varsa değiştir.
    if getent group "$OLD_USER" >/dev/null 2>&1; then
        groupmod -n "$NEW_USER" "$OLD_USER" \
            >/dev/null 2>&1 || true
    fi

    echo -e "${GREEN}✓ Kullanıcı adı değiştirildi.${RESET}"

    log "Kullanıcı adı değiştirildi: $OLD_USER -> $NEW_USER"
}

# ================================================================
# KULLANICI SİL
# ================================================================

delete_user() {

    echo
    echo -e "${BLUE}=== KULLANICI SİL ===${RESET}"
    echo

    local USER=""

    read -r -p "Silinecek kullanıcı: " USER

    if ! id "$USER" >/dev/null 2>&1; then
        echo -e "${RED}Kullanıcı bulunamadı.${RESET}"
        return 1
    fi

    if [[ "$USER" == "root" ]]; then
        echo -e "${RED}root silinemez.${RESET}"
        return 1
    fi

    if [[ "$USER" == "$TARGET_USER" ]]; then
        echo -e "${RED}Aktif kullanıcı silinemez.${RESET}"
        return 1
    fi

    if command_exists pgrep &&
       pgrep -u "$USER" >/dev/null 2>&1; then

        echo -e "${RED}Kullanıcının çalışan süreçleri var.${RESET}"
        echo "Önce kullanıcı oturumunu kapatın."
        return 1
    fi

    echo
    echo -e "${YELLOW}UYARI: Kullanıcı ve HOME dizini silinecek.${RESET}"

    if ! ask_yes_no "$USER tamamen silinsin mi?"; then
        return 0
    fi

    if userdel -r "$USER"; then
        echo -e "${GREEN}✓ Kullanıcı silindi.${RESET}"
        log "Kullanıcı silindi: $USER"
    else
        echo -e "${RED}Kullanıcı silinemedi.${RESET}"
        return 1
    fi
}

# ================================================================
# HOSTNAME
# ================================================================

change_hostname() {

    echo
    echo -e "${BLUE}=== HOSTNAME ===${RESET}"
    echo

    local CURRENT_HOST=""
    local NEW_HOST=""

    CURRENT_HOST="$(hostname)"

    echo "Mevcut hostname: $CURRENT_HOST"
    echo

    read -r -p "Yeni hostname: " NEW_HOST

    if [[ ! "$NEW_HOST" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
        echo -e "${RED}Geçersiz hostname.${RESET}"
        return 1
    fi

    if ! ask_yes_no "Hostname '$NEW_HOST' olarak değiştirilsin mi?"; then
        return 0
    fi

    create_backup

    if command_exists hostnamectl; then

        if hostnamectl set-hostname "$NEW_HOST"; then
            echo -e "${GREEN}✓ Hostname değiştirildi.${RESET}"
        else
            echo -e "${RED}Hostname değiştirilemedi.${RESET}"
            return 1
        fi

    else

        echo "$NEW_HOST" > /etc/hostname
        hostname "$NEW_HOST" 2>/dev/null || true

        echo -e "${GREEN}✓ Hostname değiştirildi.${RESET}"
    fi

    log "Hostname: $CURRENT_HOST -> $NEW_HOST"
}

# ================================================================
# SİSTEM BİLGİLERİ
# ================================================================

system_info() {

    detect_target_user
    detect_desktop

    echo
    echo -e "${CYAN}================================================${RESET}"
    echo -e "${CYAN}              SİSTEM BİLGİLERİ                 ${RESET}"
    echo -e "${CYAN}================================================${RESET}"
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
    echo -e "${WHITE}Kullanıcı:${RESET}"
    echo "${TARGET_USER:-Bilinmiyor}"

    echo
    echo -e "${WHITE}Masaüstü:${RESET}"
    echo "${DESKTOP:-Bilinmiyor}"

    echo
    echo -e "${WHITE}Locale:${RESET}"
    locale 2>/dev/null | head -15

    echo
    echo -e "${WHITE}Klavye:${RESET}"
    if [[ -f /etc/default/keyboard ]]; then
        cat /etc/default/keyboard
    else
        echo "Bulunamadı."
    fi

    echo
    echo -e "${WHITE}Shell:${RESET}"
    if [[ -n "$TARGET_USER" ]]; then
        getent passwd "$TARGET_USER" |
            cut -d: -f7
    else
        echo "Bilinmiyor"
    fi

    echo
    echo -e "${WHITE}Disk:${RESET}"
    df -h / | tail -1

    echo
    echo -e "${WHITE}RAM:${RESET}"
    free -h | awk '/^Mem:/ {print $0}'
}

# ================================================================
# TÜRKÇE PAKET ARAMA
# ================================================================

search_turkish_packages() {

    echo
    echo -e "${BLUE}=== TÜRKÇE PAKETLER ===${RESET}"
    echo

    if ! command_exists apt-cache; then
        echo -e "${RED}apt-cache bulunamadı.${RESET}"
        return 1
    fi

    echo "Türkçe / l10n paketleri aranıyor..."
    echo

    apt-cache search turkish 2>/dev/null |
        head -100

    echo
    echo "Türkçe l10n paketleri:"
    echo

    apt-cache search l10n 2>/dev/null |
        grep -Ei '(^|[-[:space:]])(tr|turkish)([-[:space:]]|$)' |
        head -100
}

# ================================================================
# PAKET LİSTESİ GÜNCELLE
# ================================================================

update_package_list() {

    echo
    echo -e "${BLUE}=== APT UPDATE ===${RESET}"
    echo

    echo "Kurulu paketler yükseltilmeyecek."
    echo "Sadece paket listesi güncellenecek."
    echo

    if ! ask_yes_no "Devam edilsin mi?"; then
        return 0
    fi

    update_package_list_silent
}

# ================================================================
# TAM TÜRKÇELEŞTİRME
# ================================================================

full_turkish_setup() {

    echo
    echo -e "${CYAN}============================================================${RESET}"
    echo -e "${CYAN}             TAM TÜRKÇELEŞTİRME KURULUMU                   ${RESET}"
    echo -e "${CYAN}============================================================${RESET}"
    echo

    echo "Yapılacak işlemler:"
    echo
    echo " • Türkçe locale"
    echo " • Türkçe Q klavye"
    echo " • Türkçe fontlar"
    echo " • GNOME / KDE kontrolü"
    echo " • Chromium Türkçe desteği"
    echo " • Firefox Türkçe desteği"
    echo " • LibreOffice Türkçe desteği"
    echo " • Türkçe man sayfaları"
    echo
    echo "Mevcut olmayan paketler zorla kurulmayacaktır."
    echo

    if ! ask_yes_no "Kurulum başlatılsın mı?"; then
        return 0
    fi

    if ! check_apt_lock; then
        return 1
    fi

    create_backup

    echo
    echo -e "${CYAN}[1/8] Paket listesi${RESET}"
    update_package_list_silent || true

    echo
    echo -e "${CYAN}[2/8] Locale${RESET}"
    configure_locale || true

    echo
    echo -e "${CYAN}[3/8] Klavye${RESET}"
    configure_keyboard || true

    echo
    echo -e "${CYAN}[4/8] Fontlar${RESET}"
    configure_fonts || true

    echo
    echo -e "${CYAN}[5/8] Masaüstü${RESET}"
    configure_gnome || true
    configure_kde || true

    echo
    echo -e "${CYAN}[6/8] Uygulamalar${RESET}"
    configure_chromium || true
    configure_firefox || true
    configure_libreoffice || true

    echo
    echo -e "${CYAN}[7/8] Man sayfaları${RESET}"
    configure_man || true

    echo
    echo -e "${CYAN}[8/8] Son kontroller${RESET}"

    detect_target_user
    detect_desktop

    echo
    echo -e "${GREEN}============================================================${RESET}"
    echo -e "${GREEN}             TÜRKÇELEŞTİRME TAMAMLANDI                     ${RESET}"
    echo -e "${GREEN}============================================================${RESET}"
    echo

    echo "Kullanıcı : ${TARGET_USER:-Bilinmiyor}"
    echo "Masaüstü  : ${DESKTOP:-Bilinmiyor}"
    echo "Yedek     : ${BACKUP_DIR:-Oluşturulmadı}"
    echo
    echo "Bazı uygulamalar için yeniden başlatma gerekebilir."
    echo

    log "Tam Türkçeleştirme tamamlandı."
}

# ================================================================
# YEDEK BİLGİSİ
# ================================================================

show_backup() {

    echo
    echo -e "${BLUE}=== SON YEDEK ===${RESET}"
    echo

    if [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]]; then
        echo "$BACKUP_DIR"
        ls -lah "$BACKUP_DIR"
    else
        echo "Bu çalıştırmada yedek oluşturulmadı."
    fi
}

# ================================================================
# SUDO / KULLANICI MENÜSÜ
# ================================================================

user_menu() {

    while true; do

        clear

        echo
        echo -e "${CYAN}============================================================${RESET}"
        echo -e "${CYAN}                  KULLANICI YÖNETİMİ                        ${RESET}"
        echo -e "${CYAN}============================================================${RESET}"
        echo
        echo " 1) Kullanıcıları listele"
        echo " 2) Kullanıcı oluştur"
        echo " 3) Şifre değiştir"
        echo " 4) Kullanıcı adı değiştir"
        echo " 5) Kullanıcı sil"
        echo " 6) Sudo yetkisi ver"
        echo " 7) Sudo yetkisini kaldır"
        echo " 0) Geri"
        echo

        local CHOICE=""

        read -r -p "Seçim: " CHOICE

        case "$CHOICE" in

            1)
                list_users
                pause
                ;;

            2)
                create_user
                pause
                ;;

            3)
                change_password
                pause
                ;;

            4)
                change_username
                pause
                ;;

            5)
                delete_user
                pause
                ;;

            6)
                grant_sudo
                pause
                ;;

            7)
                remove_sudo
                pause
                ;;

            0)
                return
                ;;

            *)
                echo -e "${RED}Geçersiz seçim.${RESET}"
                sleep 1
                ;;
        esac
    done
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
# BAŞLANGIÇ
# ================================================================

clear

echo
echo -e "${CYAN}============================================================${RESET}"
echo -e "${CYAN}       LINUX TÜRKÇELEŞTİRME & YÖNETİM ARACI                ${RESET}"
echo -e "${CYAN}                         v$VERSION                          ${RESET}"
echo -e "${CYAN}============================================================${RESET}"
echo
echo -e "${GREEN}Sistem:${RESET} ${PRETTY_NAME:-Bilinmiyor}"
echo -e "${GREEN}Kullanıcı:${RESET} ${TARGET_USER:-Bilinmiyor}"
echo -e "${GREEN}Masaüstü:${RESET} ${DESKTOP:-Bilinmiyor}"
echo
echo "Log: $LOG_FILE"
echo

log "Program başlatıldı. Sürüm: $VERSION"

# ================================================================
# ANA MENÜ
# ================================================================

while true; do

    detect_target_user
    detect_desktop

    clear

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║        LINUX TÜRKÇELEŞTİRME & YÖNETİM ARACI             ║${RESET}"
    echo -e "${CYAN}║                         v$VERSION                         ║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET} Sistem   : ${WHITE}${PRETTY_NAME:-Bilinmiyor}${RESET}"
    echo -e "${CYAN}║${RESET} Kullanıcı: ${WHITE}${TARGET_USER:-Bilinmiyor}${RESET}"
    echo -e "${CYAN}║${RESET} Masaüstü : ${WHITE}${DESKTOP:-Bilinmiyor}${RESET}"
    echo -e "${CYAN}║${RESET} Hostname : ${WHITE}$(hostname)${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  1) 🇹🇷 Tam Türkçeleştirme"
    echo -e "${CYAN}║${RESET}  2) 🌍 Sistem dili / Locale"
    echo -e "${CYAN}║${RESET}  3) ⌨️  Türkçe Q klavye"
    echo -e "${CYAN}║${RESET}  4) 🖥️  GNOME / KDE"
    echo -e "${CYAN}║${RESET}  5) 🌐 Uygulamaları Türkçeleştir"
    echo -e "${CYAN}║${RESET}  6) 🔤 Türkçe fontlar"
    echo -e "${CYAN}║${RESET}  7) 📖 Türkçe man sayfaları"
    echo -e "${CYAN}║${RESET}  8) 🔎 Türkçe paketleri ara"
    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  9) 👤 Kullanıcı yönetimi"
    echo -e "${CYAN}║${RESET} 10) 💻 Hostname değiştir"
    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} 11) 📊 Sistem bilgileri"
    echo -e "${CYAN}║${RESET} 12) 🔄 APT paket listesini güncelle"
    echo -e "${CYAN}║${RESET} 13) 💾 Son yedeği göster"
    echo -e "${CYAN}║${RESET} 14) 🔁 Yeniden başlat"
    echo -e "${CYAN}║${RESET}  0) ❌ Çıkış"
    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo

    local_choice=""

    read -r -p "Seçiminiz: " local_choice

    case "$local_choice" in

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
            show_backup
            pause
            ;;

        14)
            reboot_system
            ;;

        0)
            echo
            echo -e "${GREEN}Çıkış yapılıyor.${RESET}"
            log "Program kapatıldı."
            exit 0
            ;;

        *)
            echo -e "${RED}Geçersiz seçim.${RESET}"
            sleep 1
            ;;
    esac

done
