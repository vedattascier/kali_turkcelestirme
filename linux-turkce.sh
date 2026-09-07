#!/usr/bin/env bash

# ============================================================
# LINUX TÜRKÇELEŞTİRME & YÖNETİM ARACI
# v2026.2
#
# Destek:
#   Kali Linux
#   Debian
#   Ubuntu / Debian tabanlı sistemler
#
# Çalıştırma:
#
#   sudo bash linux-turkce.sh
#
# GitHub:
#
#   curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash
#
# ============================================================

set -u
set -o pipefail

VERSION="2026.2"
LOG_FILE="/var/log/linux-turkce.log"

# ============================================================
# RENKLER
# ============================================================

if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    MAGENTA=$'\033[0;35m'
    WHITE=$'\033[1;37m'
    GRAY=$'\033[0;90m'
    NC=$'\033[0m'
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    MAGENTA=""
    WHITE=""
    GRAY=""
    NC=""
fi

# ============================================================
# LOG
# ============================================================

init_log() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || true
}

log() {
    printf '[%s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$*" >> "$LOG_FILE" 2>/dev/null || true
}

info() {
    printf '%b[INFO]%b %s\n' "$CYAN" "$NC" "$*"
    log "INFO: $*"
}

success() {
    printf '%b[ OK ]%b %s\n' "$GREEN" "$NC" "$*"
    log "OK: $*"
}

warning() {
    printf '%b[UYARI]%b %s\n' "$YELLOW" "$NC" "$*"
    log "UYARI: $*"
}

error_msg() {
    printf '%b[HATA]%b %s\n' "$RED" "$NC" "$*"
    log "HATA: $*"
}

# ============================================================
# ROOT
# ============================================================

check_root() {
    if [[ "${EUID:-999}" -ne 0 ]]; then
        printf '\n'
        error_msg "Bu script root yetkisiyle çalıştırılmalıdır."
        printf '\n'
        printf 'Yerel kullanım:\n'
        printf '  sudo bash linux-turkce.sh\n\n'
        printf 'GitHub kullanım:\n'
        printf '  curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash\n\n'
        exit 1
    fi
}

# ============================================================
# SİSTEM
# ============================================================

load_system_info() {

    if [[ ! -f /etc/os-release ]]; then
        error_msg "/etc/os-release bulunamadı."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    OS_NAME="${PRETTY_NAME:-${NAME:-Bilinmeyen Linux}}"
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"

    if ! command -v apt-get >/dev/null 2>&1; then
        error_msg "apt-get bulunamadı."
        error_msg "Debian tabanlı bir sistem gereklidir."
        exit 1
    fi
}

# ============================================================
# KULLANICI TESPİTİ
# ============================================================

detect_target_user() {

    TARGET_USER=""

    if [[ -n "${SUDO_USER:-}" ]] &&
       [[ "${SUDO_USER:-}" != "root" ]] &&
       id "${SUDO_USER:-}" >/dev/null 2>&1; then

        TARGET_USER="$SUDO_USER"

    elif [[ -n "${USER:-}" ]] &&
         [[ "$USER" != "root" ]] &&
         id "$USER" >/dev/null 2>&1; then

        TARGET_USER="$USER"

    else

        TARGET_USER="$(
            awk -F: '
                $3 >= 1000 &&
                $3 < 60000 &&
                $1 != "nobody" {
                    print $1
                    exit
                }
            ' /etc/passwd
        )"

    fi

    if [[ -z "$TARGET_USER" ]]; then
        TARGET_USER="root"
    fi

    TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || printf '0')"
    TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"

    if [[ -z "$TARGET_HOME" ]]; then
        TARGET_HOME="/root"
    fi
}

# ============================================================
# MASAÜSTÜ
# ============================================================

detect_desktop() {

    DESKTOP="Bilinmiyor"

    if pgrep -u "$TARGET_USER" -x xfce4-session >/dev/null 2>&1 ||
       pgrep -u "$TARGET_USER" -x xfdesktop >/dev/null 2>&1; then

        DESKTOP="XFCE"

    elif pgrep -u "$TARGET_USER" -x gnome-session >/dev/null 2>&1 ||
         pgrep -u "$TARGET_USER" -x gnome-shell >/dev/null 2>&1; then

        DESKTOP="GNOME"

    elif pgrep -u "$TARGET_USER" -x plasmashell >/dev/null 2>&1; then

        DESKTOP="KDE Plasma"

    elif pgrep -u "$TARGET_USER" -x cinnamon-session >/dev/null 2>&1; then

        DESKTOP="Cinnamon"

    elif pgrep -u "$TARGET_USER" -x mate-session >/dev/null 2>&1; then

        DESKTOP="MATE"

    else

        if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
            DESKTOP="$XDG_CURRENT_DESKTOP"
        elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
            DESKTOP="$DESKTOP_SESSION"
        fi

    fi
}

# ============================================================
# TERMINAL GİRİŞİ
#
# KRİTİK:
#
# curl | sudo bash
#
# kullanımında stdin curl'a bağlıdır.
# Bu nedenle bütün kullanıcı girişleri /dev/tty üzerinden
# okunur.
# ============================================================

tty_available() {
    [[ -r /dev/tty ]]
}

read_tty() {

    local __variable="$1"
    local __prompt="$2"
    local __value=""

    if tty_available; then

        printf '%s' "$__prompt" > /dev/tty

        if ! IFS= read -r __value < /dev/tty; then
            return 1
        fi

    elif [[ -t 0 ]]; then

        printf '%s' "$__prompt"

        if ! IFS= read -r __value; then
            return 1
        fi

    else

        return 1

    fi

    printf -v "$__variable" '%s' "$__value"

    return 0
}

read_tty_hidden() {

    local __variable="$1"
    local __prompt="$2"
    local __value=""

    if tty_available; then

        printf '%s' "$__prompt" > /dev/tty

        if ! IFS= read -r -s __value < /dev/tty; then
            return 1
        fi

        printf '\n' > /dev/tty

    elif [[ -t 0 ]]; then

        printf '%s' "$__prompt"

        if ! IFS= read -r -s __value; then
            return 1
        fi

        printf '\n'

    else

        return 1

    fi

    printf -v "$__variable" '%s' "$__value"

    return 0
}

pause_tty() {

    local dummy=""

    if tty_available; then

        printf '\n%bDevam etmek için Enter tuşuna basın...%b' \
            "$GRAY" "$NC" > /dev/tty

        IFS= read -r dummy < /dev/tty || true

    elif [[ -t 0 ]]; then

        printf '\n%bDevam etmek için Enter tuşuna basın...%b' \
            "$GRAY" "$NC"

        IFS= read -r dummy || true

    fi
}

ask_yes_no() {

    local question="$1"
    local answer=""

    while true; do

        if ! read_tty answer "$question [e/H]: "; then
            return 1
        fi

        # CR temizle
        answer="${answer//$'\r'/}"

        case "${answer,,}" in

            e|evet|y|yes)
                return 0
                ;;

            h|hayir|hayır|n|no|"")
                return 1
                ;;

            *)
                printf '%bLütfen e veya h girin.%b\n' \
                    "$YELLOW" "$NC"
                ;;

        esac

    done
}

# ============================================================
# EKRAN
# ============================================================

clear_screen() {
    clear 2>/dev/null || printf '\n\n'
}

# ============================================================
# APT
# ============================================================

package_installed() {

    local package="$1"

    dpkg-query \
        -W \
        -f='${Status}' \
        "$package" 2>/dev/null |
        grep -q '^install ok installed$'
}

package_available() {

    local package="$1"

    [[ -n "$package" ]] || return 1

    apt-cache show "$package" >/dev/null 2>&1
}

install_package() {

    local package="$1"

    if [[ -z "$package" ]]; then
        return 1
    fi

    if package_installed "$package"; then
        success "$package zaten kurulu."
        return 0
    fi

    if ! package_available "$package"; then
        warning "$package depolarda bulunamadı."
        return 1
    fi

    info "$package kuruluyor..."

    if DEBIAN_FRONTEND=noninteractive \
        apt-get install -y "$package"; then

        success "$package kuruldu."
        return 0

    else

        warning "$package kurulamadı."
        return 1

    fi
}

# ============================================================
# YEDEK
# ============================================================

BACKUP_DIR=""

create_backup() {

    if [[ -n "$BACKUP_DIR" ]] &&
       [[ -d "$BACKUP_DIR" ]]; then
        return 0
    fi

    local timestamp

    timestamp="$(date '+%Y%m%d_%H%M%S')"

    BACKUP_DIR="/root/linux-turkce-backup-$timestamp"

    if ! mkdir -p "$BACKUP_DIR"; then
        error_msg "Yedek klasörü oluşturulamadı."
        BACKUP_DIR=""
        return 1
    fi

    local files=(
        "/etc/locale.gen"
        "/etc/default/locale"
        "/etc/default/keyboard"
        "/etc/hostname"
        "/etc/hosts"
    )

    local file

    for file in "${files[@]}"; do

        if [[ -f "$file" ]]; then
            cp -a "$file" "$BACKUP_DIR/" 2>/dev/null || true
        fi

    done

    success "Yedek oluşturuldu:"
    printf '  %s\n' "$BACKUP_DIR"

    log "Yedek: $BACKUP_DIR"
}

show_last_backup() {

    printf '\n'
    printf '%bSON YEDEKLER%b\n\n' "$CYAN" "$NC"

    local found=0
    local dir

    while IFS= read -r dir; do

        [[ -n "$dir" ]] || continue

        printf '  %s\n' "$dir"

        found=1

    done < <(
        find /root \
            -maxdepth 1 \
            -type d \
            -name 'linux-turkce-backup-*' \
            -print 2>/dev/null |
        sort -r |
        head -10
    )

    if [[ "$found" -eq 0 ]]; then
        warning "Henüz yedek bulunamadı."
    fi
}

# ============================================================
# LOCALE
# ============================================================

configure_locale() {

    printf '\n'
    printf '%b========================================%b\n' "$CYAN" "$NC"
    printf '%bSİSTEM DİLİ / LOCALE%b\n' "$CYAN" "$NC"
    printf '%b========================================%b\n\n' "$CYAN" "$NC"

    create_backup

    install_package locales || true

    if [[ ! -f /etc/locale.gen ]]; then
        touch /etc/locale.gen
    fi

    # Önce mevcut Türkçe satırlarını temizle
    sed -i \
        -E \
        '/^[[:space:]#]*tr_TR\.UTF-8[[:space:]]+UTF-8[[:space:]]*$/d' \
        /etc/locale.gen 2>/dev/null || true

    printf '%s\n' 'tr_TR.UTF-8 UTF-8' >> /etc/locale.gen

    if command -v locale-gen >/dev/null 2>&1; then
        locale-gen tr_TR.UTF-8 || \
            warning "locale-gen sırasında hata oluştu."
    fi

    if command -v update-locale >/dev/null 2>&1; then

        if ! update-locale \
            LANG=tr_TR.UTF-8 \
            LANGUAGE=tr_TR:tr; then

            warning "update-locale başarısız oldu."
        fi

    else

        cat > /etc/default/locale <<'EOF'
LANG=tr_TR.UTF-8
LANGUAGE=tr_TR:tr
EOF

    fi

    cat > /etc/profile.d/turkish-locale.sh <<'EOF'
# Linux Türkçeleştirme
export LANG=tr_TR.UTF-8
export LANGUAGE=tr_TR:tr
EOF

    chmod 644 /etc/profile.d/turkish-locale.sh

    success "Sistem dili Türkçe olarak ayarlandı."

    warning "Tam uygulanması için oturumu kapatıp açmanız veya yeniden başlatmanız gerekebilir."
}

# ============================================================
# KLAVYE
# ============================================================

configure_keyboard() {

    printf '\n'
    printf '%b========================================%b\n' "$CYAN" "$NC"
    printf '%bTÜRKÇE Q KLAVYE%b\n' "$CYAN" "$NC"
    printf '%b========================================%b\n\n' "$CYAN" "$NC"

    create_backup

    install_package keyboard-configuration || true

    cat > /etc/default/keyboard <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="tr"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

    if command -v localectl >/dev/null 2>&1; then

        localectl set-x11-keymap tr pc105 "" "" \
            >/dev/null 2>&1 || true

        localectl set-keymap tr \
            >/dev/null 2>&1 || true

    fi

    if command -v setxkbmap >/dev/null 2>&1 &&
       [[ -n "${DISPLAY:-}" ]]; then

        setxkbmap tr >/dev/null 2>&1 || true

    fi

    success "Türkçe Q klavye ayarlandı."
}

# ============================================================
# GNOME
# ============================================================

run_as_target_user() {

    if [[ "$TARGET_USER" == "root" ]]; then
        "$@"
        return $?
    fi

    local uid

    uid="$(id -u "$TARGET_USER" 2>/dev/null || printf '0')"

    if [[ -S "/run/user/$uid/bus" ]]; then

        runuser -u "$TARGET_USER" -- \
            env \
            XDG_RUNTIME_DIR="/run/user/$uid" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
            "$@"

    else

        runuser -u "$TARGET_USER" -- "$@"

    fi
}

configure_gnome() {

    if ! command -v gsettings >/dev/null 2>&1; then
        warning "gsettings bulunamadı."
        return 1
    fi

    if run_as_target_user \
        gsettings set \
        org.gnome.system.locale \
        region \
        'tr_TR.UTF-8' \
        >/dev/null 2>&1; then

        success "GNOME bölge ayarı Türkçe yapıldı."

    else

        warning "GNOME oturum DBus bağlantısı bulunamadı."
        warning "Locale ayarı yine de sistem seviyesinde uygulanmıştır."

    fi
}

# ============================================================
# KDE
# ============================================================

configure_kde() {

    if package_available kde-l10n-tr; then
        install_package kde-l10n-tr || true
    else
        warning "kde-l10n-tr bu sistemde bulunamadı."
    fi

    warning "KDE Plasma dil değişikliği oturum yeniden başlatıldıktan sonra uygulanabilir."
}

# ============================================================
# XFCE
# ============================================================

configure_xfce() {

    if command -v xfconf-query >/dev/null 2>&1; then
        success "XFCE algılandı."
    else
        warning "XFCE araçları bulunamadı."
    fi

    info "XFCE sistem locale ayarlarını kullanacaktır."
}

# ============================================================
# MASAÜSTÜ
# ============================================================

configure_desktop() {

    printf '\n'
    printf '%b========================================%b\n' "$CYAN" "$NC"
    printf '%bMASAÜSTÜ YAPILANDIRMASI%b\n' "$CYAN" "$NC"
    printf '%b========================================%b\n\n' "$CYAN" "$NC"

    case "${DESKTOP,,}" in

        *xfce*)
            configure_xfce
            ;;

        *gnome*)
            configure_gnome || true
            ;;

        *kde*|*plasma*)
            configure_kde
            ;;

        *)
            warning "Masaüstü otomatik tanınamadı: $DESKTOP"
            info "Sistem locale ayarı kullanılacaktır."
            ;;

    esac
}

# ============================================================
# FONTLAR
# ============================================================

install_turkish_fonts() {

    printf '\n'
    printf '%b========================================%b\n' "$CYAN" "$NC"
    printf '%bTÜRKÇE FONTLAR%b\n' "$CYAN" "$NC"
    printf '%b========================================%b\n\n' "$CYAN" "$NC"

    local packages=(
        fonts-dejavu
        fonts-liberation
        fonts-noto-core
        fonts-noto-cjk
    )

    local package

    for package in "${packages[@]}"; do
        install_package "$package" || true
    done

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi

    success "Türkçe karakter desteği için fontlar kontrol edildi."
}

# ============================================================
# CHROMIUM
# ============================================================

configure_chromium() {

    if package_available chromium-l10n; then
        install_package chromium-l10n || true
    else
        warning "chromium-l10n bulunamadı."
    fi
}

# ============================================================
# FIREFOX
# ============================================================

configure_firefox() {

    if package_available firefox-esr-l10n-tr; then

        install_package firefox-esr-l10n-tr || true

    elif package_available firefox-l10n-tr; then

        install_package firefox-l10n-tr || true

    else

        warning "Firefox Türkçe dil paketi bulunamadı."

    fi
}

# ============================================================
# LIBREOFFICE
# ============================================================

configure_libreoffice() {

    if package_available libreoffice-l10n-tr; then
        install_package libreoffice-l10n-tr || true
    else
        warning "LibreOffice Türkçe dil paketi bulunamadı."
    fi
}

# ============================================================
# UYGULAMALAR
# ============================================================

configure_applications() {

    printf '\n'
    printf '%b========================================%b\n' "$CYAN" "$NC"
    printf '%bUYGULAMALARI TÜRKÇELEŞTİR%b\n' "$CYAN" "$NC"
    printf '%b========================================%b\n\n' "$CYAN" "$NC"

    configure_chromium
    configure_firefox
    configure_libreoffice

    # Debian/Kali'de bulunuyorsa kur
    install_package language-pack-tr || true
    install_package language-pack-gnome-tr || true

    success "Uygulama dil paketleri kontrol edildi."

    warning "Bazı uygulamalar Türkçe arayüz için yeniden başlatılmalıdır."
}

# ============================================================
# MAN
# ============================================================

install_turkish_manpages() {

    printf '\n'
    printf '%b========================================%b\n' "$CYAN" "$NC"
    printf '%bTÜRKÇE MAN SAYFALARI%b\n' "$CYAN" "$NC"
    printf '%b========================================%b\n\n' "$CYAN" "$NC"

    if package_available manpages-tr; then
        install_package manpages-tr || true
    else
        warning "manpages-tr bulunamadı."
    fi

    if package_available manpages-tr-dev; then
        install_package manpages-tr-dev || true
    fi

    success "Türkçe man paketleri kontrol edildi."
}

# ============================================================
# TÜRKÇE PAKET ARAMA
# ============================================================

search_turkish_packages() {

    local search_term=""

    printf '\n'
    printf '%b========================================%b\n' "$CYAN" "$NC"
    printf '%bTÜRKÇE PAKET ARAMA%b\n' "$CYAN" "$NC"
    printf '%b========================================%b\n\n' "$CYAN" "$NC"

    if ! read_tty search_term "Aranacak ifade: "; then
        error_msg "Girdi alınamadı."
        return 1
    fi

    search_term="${search_term//$'\r'/}"

    if [[ -z "$search_term" ]]; then
        warning "Arama ifadesi boş."
        return 1
    fi

    printf '\n'

    apt-cache search "$search_term" 2>/dev/null |
        head -100

    printf '\n'
    success "Arama tamamlandı."
}

# ============================================================
# SUDO VER
# ============================================================

grant_sudo() {

    local username="$1"

    if ! id "$username" >/dev/null 2>&1; then
        error_msg "Kullanıcı bulunamadı: $username"
        return 1
    fi

    if getent group sudo >/dev/null 2>&1; then

        usermod -aG sudo "$username"

        success "$username sudo grubuna eklendi."

    elif getent group wheel >/dev/null 2>&1; then

        usermod -aG wheel "$username"

        success "$username wheel grubuna eklendi."

    else

        error_msg "sudo veya wheel grubu bulunamadı."
        return 1

    fi
}

# ============================================================
# SUDO KALDIR
# ============================================================

remove_sudo() {

    local username="$1"

    if ! id "$username" >/dev/null 2>&1; then
        error_msg "Kullanıcı bulunamadı."
        return 1
    fi

    if getent group sudo >/dev/null 2>&1; then
        gpasswd -d "$username" sudo >/dev/null 2>&1 || true
    fi

    if getent group wheel >/dev/null 2>&1; then
        gpasswd -d "$username" wheel >/dev/null 2>&1 || true
    fi

    success "$username sudo/wheel gruplarından çıkarıldı."
}

# ============================================================
# KULLANICI LİSTE
# ============================================================

list_users() {

    printf '\n'
    printf '%bKULLANICILAR%b\n\n' "$CYAN" "$NC"

    printf '%-20s %-8s %-30s\n' \
        "KULLANICI" "UID" "HOME"

    printf '%-20s %-8s %-30s\n' \
        "--------------------" \
        "--------" \
        "------------------------------"

    awk -F: '
        $3 >= 1000 && $3 < 60000 {
            printf "%-20s %-8s %-30s\n", $1, $3, $6
        }
    ' /etc/passwd

    printf '\n'
}

# ============================================================
# KULLANICI OLUŞTUR
# ============================================================

create_user() {

    local username=""

    printf '\n'
    printf '%bYENİ KULLANICI%b\n\n' "$CYAN" "$NC"

    if ! read_tty username "Kullanıcı adı: "; then
        return 1
    fi

    username="${username//$'\r'/}"

    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        error_msg "Geçersiz kullanıcı adı."
        return 1
    fi

    if id "$username" >/dev/null 2>&1; then
        error_msg "Bu kullanıcı zaten mevcut."
        return 1
    fi

    if ! useradd \
        -m \
        -s /bin/bash \
        "$username"; then

        error_msg "Kullanıcı oluşturulamadı."
        return 1
    fi

    printf '\n'
    passwd "$username"

    if ask_yes_no "Bu kullanıcıya sudo yetkisi verilsin mi?"; then
        grant_sudo "$username"
    fi

    success "Kullanıcı oluşturuldu: $username"
}

# ============================================================
# ŞİFRE DEĞİŞTİR
# ============================================================

change_user_password() {

    local username=""

    if ! read_tty username "Şifresi değiştirilecek kullanıcı: "; then
        return 1
    fi

    username="${username//$'\r'/}"

    if ! id "$username" >/dev/null 2>&1; then
        error_msg "Kullanıcı bulunamadı."
        return 1
    fi

    passwd "$username"
}

# ============================================================
# KULLANICI ADI DEĞİŞTİR
# ============================================================

change_username() {

    local old_username=""
    local new_username=""
    local old_home=""
    local new_home=""

    if ! read_tty old_username "Mevcut kullanıcı adı: "; then
        return 1
    fi

    old_username="${old_username//$'\r'/}"

    if ! id "$old_username" >/dev/null 2>&1; then
        error_msg "Kullanıcı bulunamadı."
        return 1
    fi

    if [[ "$old_username" == "$TARGET_USER" ]]; then
        error_msg "Aktif kullanıcı adı değiştirilemez."
        warning "Başka bir yönetici hesabından çalıştırın."
        return 1
    fi

    if ! read_tty new_username "Yeni kullanıcı adı: "; then
        return 1
    fi

    new_username="${new_username//$'\r'/}"

    if [[ ! "$new_username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        error_msg "Geçersiz yeni kullanıcı adı."
        return 1
    fi

    if id "$new_username" >/dev/null 2>&1; then
        error_msg "Bu kullanıcı adı zaten mevcut."
        return 1
    fi

    if pgrep -u "$old_username" >/dev/null 2>&1; then
        error_msg "Kullanıcının çalışan işlemleri var."
        warning "Kullanıcının oturumunu kapatıp tekrar deneyin."
        return 1
    fi

    old_home="$(getent passwd "$old_username" | cut -d: -f6)"
    new_home="/home/$new_username"

    if ! usermod -l "$new_username" "$old_username"; then
        error_msg "Kullanıcı adı değiştirilemedi."
        return 1
    fi

    if [[ -n "$old_home" ]] &&
       [[ -d "$old_home" ]]; then

        if ! usermod \
            -d "$new_home" \
            -m \
            "$new_username"; then

            warning "Home dizini taşınamadı."
        fi
    fi

    success "Kullanıcı adı değiştirildi."
    printf '  %s -> %s\n' "$old_username" "$new_username"
}

# ============================================================
# KULLANICI SİL
# ============================================================

delete_user() {

    local username=""

    if ! read_tty username "Silinecek kullanıcı: "; then
        return 1
    fi

    username="${username//$'\r'/}"

    if [[ "$username" == "root" ]]; then
        error_msg "root kullanıcısı silinemez."
        return 1
    fi

    if [[ "$username" == "$TARGET_USER" ]]; then
        error_msg "Aktif kullanıcı silinemez."
        return 1
    fi

    if ! id "$username" >/dev/null 2>&1; then
        error_msg "Kullanıcı bulunamadı."
        return 1
    fi

    warning "Kullanıcının home dizini de silinecek."

    if ask_yes_no "Kullanıcı gerçekten silinsin mi?"; then

        if userdel -r "$username"; then
            success "$username silindi."
        else
            error_msg "Kullanıcı silinemedi."
        fi

    else

        info "İşlem iptal edildi."

    fi
}

# ============================================================
# KULLANICI MENÜSÜ
# ============================================================

user_management_menu() {

    while true; do

        clear_screen

        printf '%b\n' "$CYAN"
        printf '╔══════════════════════════════════════════════╗\n'
        printf '║              KULLANICI YÖNETİMİ             ║\n'
        printf '╠══════════════════════════════════════════════╣\n'
        printf '║ 1) Kullanıcıları listele                    ║\n'
        printf '║ 2) Kullanıcı oluştur                        ║\n'
        printf '║ 3) Kullanıcı şifresi değiştir               ║\n'
        printf '║ 4) Kullanıcıya sudo yetkisi ver             ║\n'
        printf '║ 5) Kullanıcıdan sudo yetkisini kaldır      ║\n'
        printf '║ 6) Kullanıcı adını değiştir                 ║\n'
        printf '║ 7) Kullanıcı sil                            ║\n'
        printf '║ 0) Geri                                     ║\n'
        printf '╚══════════════════════════════════════════════╝\n'
        printf '%b\n' "$NC"

        local choice=""

        # DOĞRUDAN TTY
        if ! read_tty choice "Seçiminiz [0-7]: "; then
            error_msg "Terminal girişi alınamadı."
            return 1
        fi

        choice="${choice//$'\r'/}"
        choice="${choice#"${choice%%[![:space:]]*}"}"
        choice="${choice%"${choice##*[![:space:]]}"}"

        case "$choice" in

            0)
                return 0
                ;;

            1)
                list_users
                pause_tty
                ;;

            2)
                create_user
                pause_tty
                ;;

            3)
                change_user_password
                pause_tty
                ;;

            4)
                local username_grant=""

                if read_tty \
                    username_grant \
                    "Sudo verilecek kullanıcı: "; then

                    username_grant="${username_grant//$'\r'/}"

                    grant_sudo "$username_grant"
                fi

                pause_tty
                ;;

            5)
                local username_remove=""

                if read_tty \
                    username_remove \
                    "Sudo kaldırılacak kullanıcı: "; then

                    username_remove="${username_remove//$'\r'/}"

                    remove_sudo "$username_remove"
                fi

                pause_tty
                ;;

            6)
                change_username
                pause_tty
                ;;

            7)
                delete_user
                pause_tty
                ;;

            *)
                warning "Geçersiz seçim: [$choice]"
                printf 'Lütfen 0-7 arasında seçim yapın.\n'
                sleep 1
                ;;

        esac

    done
}

# ============================================================
# HOSTNAME
# ============================================================

change_hostname() {

    local new_hostname=""

    printf '\n'
    printf '%bMevcut hostname:%b %s\n\n' \
        "$CYAN" "$NC" "$(hostname)"

    if ! read_tty new_hostname "Yeni hostname: "; then
        return 1
    fi

    new_hostname="${new_hostname//$'\r'/}"

    if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{0,62}$ ]]; then
        error_msg "Geçersiz hostname."
        return 1
    fi

    create_backup

    if command -v hostnamectl >/dev/null 2>&1 &&
       hostnamectl set-hostname "$new_hostname" >/dev/null 2>&1; then

        success "Hostname değiştirildi: $new_hostname"

    else

        if hostname "$new_hostname" >/dev/null 2>&1; then

            printf '%s\n' "$new_hostname" > /etc/hostname

            success "Hostname değiştirildi."

        else

            error_msg "Hostname değiştirilemedi."
            return 1

        fi

    fi

    HOSTNAME_CURRENT="$new_hostname"
}

# ============================================================
# SİSTEM BİLGİLERİ
# ============================================================

system_information() {

    clear_screen

    printf '%b\n' "$CYAN"
    printf '╔══════════════════════════════════════════════════════════╗\n'
    printf '║                    SİSTEM BİLGİLERİ                     ║\n'
    printf '╚══════════════════════════════════════════════════════════╝\n'
    printf '%b\n' "$NC"

    printf '%bİşletim Sistemi:%b %s\n' \
        "$WHITE" "$NC" "$OS_NAME"

    printf '%bOS ID          :%b %s\n' \
        "$WHITE" "$NC" "$OS_ID"

    printf '%bKernel         :%b %s\n' \
        "$WHITE" "$NC" "$(uname -r)"

    printf '%bMimari         :%b %s\n' \
        "$WHITE" "$NC" "$(uname -m)"

    printf '%bKullanıcı      :%b %s\n' \
        "$WHITE" "$NC" "$TARGET_USER"

    printf '%bUID            :%b %s\n' \
        "$WHITE" "$NC" "$TARGET_UID"

    printf '%bHome           :%b %s\n' \
        "$WHITE" "$NC" "$TARGET_HOME"

    printf '%bMasaüstü       :%b %s\n' \
        "$WHITE" "$NC" "$DESKTOP"

    printf '%bHostname       :%b %s\n' \
        "$WHITE" "$NC" "$(hostname)"

    printf '%bLocale         :%b %s\n' \
        "$WHITE" "$NC" "${LANG:-ayarlı değil}"

    printf '\n'
    printf '%bBELLEK%b\n' "$CYAN" "$NC"

    if command -v free >/dev/null 2>&1; then
        free -h
    fi

    printf '\n'
    printf '%bDİSK%b\n' "$CYAN" "$NC"

    df -h / 2>/dev/null || true

    printf '\n'
    printf '%bAĞ%b\n' "$CYAN" "$NC"

    if command -v ip >/dev/null 2>&1; then
        ip -brief address 2>/dev/null || true
    fi
}

# ============================================================
# TAM TÜRKÇELEŞTİRME
# ============================================================

full_turkish_setup() {

    printf '\n'
    printf '%b╔══════════════════════════════════════════════════════════╗%b\n' \
        "$GREEN" "$NC"

    printf '%b║              TAM TÜRKÇELEŞTİRME                         ║%b\n' \
        "$GREEN" "$NC"

    printf '%b╚══════════════════════════════════════════════════════════╝%b\n\n' \
        "$GREEN" "$NC"

    warning "Sistem locale, klavye, masaüstü, font ve uygulama dil paketleri ayarlanacaktır."

    printf '\n'

    if ! ask_yes_no "Devam edilsin mi?"; then
        info "İşlem iptal edildi."
        return 0
    fi

    create_backup

    printf '\n'
    printf '%b[1/6] Sistem dili%b\n' "$CYAN" "$NC"
    configure_locale

    printf '\n'
    printf '%b[2/6] Türkçe Q klavye%b\n' "$CYAN" "$NC"
    configure_keyboard

    printf '\n'
    printf '%b[3/6] Masaüstü%b\n' "$CYAN" "$NC"
    configure_desktop

    printf '\n'
    printf '%b[4/6] Fontlar%b\n' "$CYAN" "$NC"
    install_turkish_fonts

    printf '\n'
    printf '%b[5/6] Uygulamalar%b\n' "$CYAN" "$NC"
    configure_applications

    printf '\n'
    printf '%b[6/6] Man sayfaları%b\n' "$CYAN" "$NC"
    install_turkish_manpages

    printf '\n'
    printf '%b╔══════════════════════════════════════════════════════════╗%b\n' \
        "$GREEN" "$NC"

    printf '%b║              İŞLEM TAMAMLANDI                           ║%b\n' \
        "$GREEN" "$NC"

    printf '%b╚══════════════════════════════════════════════════════════╝%b\n' \
        "$GREEN" "$NC"

    printf '\n'

    success "Türkçeleştirme tamamlandı."

    if [[ -n "$BACKUP_DIR" ]]; then
        info "Yedek: $BACKUP_DIR"
    fi

    warning "Tüm değişikliklerin uygulanması için yeniden başlatma önerilir."
}

# ============================================================
# APT GÜNCELLE
# ============================================================

update_apt() {

    printf '\n'
    printf '%bAPT paket listesi güncelleniyor...%b\n\n' \
        "$CYAN" "$NC"

    if apt-get update; then
        success "APT paket listeleri güncellendi."
    else
        error_msg "APT güncellemesi başarısız oldu."
        return 1
    fi
}

# ============================================================
# REBOOT
# ============================================================

reboot_system() {

    printf '\n'

    warning "Sistem yeniden başlatılacak."

    if ! ask_yes_no "Şimdi yeniden başlatılsın mı?"; then
        info "Yeniden başlatma iptal edildi."
        return 0
    fi

    sync

    if command -v systemctl >/dev/null 2>&1; then
        systemctl reboot
    else
        reboot
    fi
}

# ============================================================
# ANA MENÜ
# ============================================================

main_menu() {

    while true; do

        clear_screen

        printf '%b' "$WHITE"

        printf '╔══════════════════════════════════════════════════════════╗\n'
        printf '║        LINUX TÜRKÇELEŞTİRME & YÖNETİM ARACI             ║\n'
        printf '║                         v%-25s║\n' "$VERSION"
        printf '╠══════════════════════════════════════════════════════════╣\n'
        printf '║ Sistem   : %-44s ║\n' "$OS_NAME"
        printf '║ Kullanıcı: %-44s ║\n' "$TARGET_USER"
        printf '║ Masaüstü : %-44s ║\n' "$DESKTOP"
        printf '║ Hostname : %-44s ║\n' "$HOSTNAME_CURRENT"
        printf '╠══════════════════════════════════════════════════════════╣\n'
        printf '║                                                          ║\n'
        printf '║  1) 🇹🇷 Tam Türkçeleştirme                              ║\n'
        printf '║  2) 🌍 Sistem dili / Locale                             ║\n'
        printf '║  3) ⌨️  Türkçe Q klavye                                ║\n'
        printf '║  4) 🖥️  GNOME / KDE / XFCE                            ║\n'
        printf '║  5) 🌐 Uygulamaları Türkçeleştir                       ║\n'
        printf '║  6) 🔤 Türkçe fontlar                                  ║\n'
        printf '║  7) 📖 Türkçe man sayfaları                            ║\n'
        printf '║  8) 🔎 Türkçe paketleri ara                            ║\n'
        printf '║                                                          ║\n'
        printf '║  9) 👤 Kullanıcı yönetimi                              ║\n'
        printf '║ 10) 💻 Hostname değiştir                               ║\n'
        printf '║                                                          ║\n'
        printf '║ 11) 📊 Sistem bilgileri                                ║\n'
        printf '║ 12) 🔄 APT paket listesini güncelle                    ║\n'
        printf '║ 13) 💾 Son yedeği göster                               ║\n'
        printf '║ 14) 🔁 Yeniden başlat                                  ║\n'
        printf '║  0) ❌ Çıkış                                            ║\n'
        printf '║                                                          ║\n'
        printf '╚══════════════════════════════════════════════════════════╝\n'

        printf '%b' "$NC"

        printf '\n'

        # ====================================================
        # BURASI ÖNEMLİ
        #
        # read doğrudan /dev/tty üzerinden çalışıyor.
        #
        # curl | sudo bash
        #
        # olduğunda stdin curl pipe'ı olsa bile seçim gerçek
        # terminalden alınır.
        # ====================================================

        local choice=""

        if ! read_tty choice "Seçiminiz [0-14]: "; then

            printf '\n'
            error_msg "Terminalden giriş alınamadı."
            printf '\n'
            printf 'Scripti normal bir terminalden çalıştırın.\n'
            exit 1

        fi

        # CR temizle
        choice="${choice//$'\r'/}"

        # Baştaki boşlukları temizle
        choice="${choice#"${choice%%[![:space:]]*}"}"

        # Sondaki boşlukları temizle
        choice="${choice%"${choice##*[![:space:]]}"}"

        # ====================================================
        # BOŞ SEÇİM
        # ====================================================

        if [[ -z "$choice" ]]; then

            printf '\n'
            warning "Seçim boş bırakılamaz."
            sleep 1
            continue

        fi

        # ====================================================
        # SADECE SAYI
        # ====================================================

        if [[ ! "$choice" =~ ^[0-9]+$ ]]; then

            printf '\n'
            warning "Geçersiz seçim: [$choice]"
            printf 'Lütfen 0-14 arasında bir sayı girin.\n'
            sleep 1
            continue

        fi

        # ====================================================
        # MENÜ
        # ====================================================

        case "$choice" in

            0)

                printf '\n'
                success "Programdan çıkılıyor."
                exit 0

                ;;

            1)

                full_turkish_setup
                pause_tty

                ;;

            2)

                configure_locale
                pause_tty

                ;;

            3)

                configure_keyboard
                pause_tty

                ;;

            4)

                configure_desktop
                pause_tty

                ;;

            5)

                configure_applications
                pause_tty

                ;;

            6)

                install_turkish_fonts
                pause_tty

                ;;

            7)

                install_turkish_manpages
                pause_tty

                ;;

            8)

                search_turkish_packages
                pause_tty

                ;;

            9)

                user_management_menu

                ;;

            10)

                change_hostname
                pause_tty

                ;;

            11)

                system_information
                pause_tty

                ;;

            12)

                update_apt
                pause_tty

                ;;

            13)

                show_last_backup
                pause_tty

                ;;

            14)

                reboot_system

                ;;

            *)

                # Bu kısım normalde ulaşılmaz çünkü yukarıda
                # sadece sayı kontrolü yapılıyor.
                printf '\n'
                warning "Geçersiz seçim: [$choice]"
                sleep 1

                ;;

        esac

    done
}

# ============================================================
# BAŞLAT
# ============================================================

main() {

    init_log

    check_root

    load_system_info

    detect_target_user

    detect_desktop

    HOSTNAME_CURRENT="$(hostname 2>/dev/null || printf 'Bilinmiyor')"

    log "=============================================="
    log "Linux Türkçeleştirme başlatıldı"
    log "Version: $VERSION"
    log "OS: $OS_NAME"
    log "User: $TARGET_USER"
    log "Desktop: $DESKTOP"
    log "Hostname: $HOSTNAME_CURRENT"
    log "=============================================="

    main_menu
}

main "$@"
