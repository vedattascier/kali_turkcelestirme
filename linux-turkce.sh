#!/usr/bin/env bash

# ============================================================
# LINUX TÜRKÇELEŞTİRME & YÖNETİM ARACI
# Version: 2026.2
#
# Destek:
#   Kali Linux
#   Debian
#   Ubuntu ve Debian tabanlı sistemler
#
# Çalıştırma:
#   sudo bash linux-turkce.sh
#
# GitHub:
#   curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash
# ============================================================

set -uo pipefail

VERSION="2026.2"
SCRIPT_NAME="Linux Türkçeleştirme & Yönetim Aracı"
LOG_FILE="/var/log/linux-turkce.log"

# ============================================================
# RENKLER
# ============================================================

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    WHITE='\033[1;37m'
    GRAY='\033[0;90m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    WHITE=''
    GRAY=''
    NC=''
fi

# ============================================================
# LOG
# ============================================================

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
touch "$LOG_FILE" 2>/dev/null || true

log() {
    local msg="$*"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

info() {
    printf '%b[INFO]%b %s\n' "$CYAN" "$NC" "$*"
    log "INFO: $*"
}

success() {
    printf '%b[OK]%b %s\n' "$GREEN" "$NC" "$*"
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
# ROOT KONTROLÜ
# ============================================================

if [[ "${EUID:-999}" -ne 0 ]]; then
    printf '\n'
    error_msg "Bu program root yetkisiyle çalıştırılmalıdır."
    printf '\n'
    printf 'Yerel dosya için:\n'
    printf '  sudo bash linux-turkce.sh\n\n'
    printf 'GitHub üzerinden:\n'
    printf '  curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash\n\n'
    exit 1
fi

# ============================================================
# SİSTEM KONTROLÜ
# ============================================================

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
    error_msg "apt-get bulunamadı. Debian tabanlı bir sistem gerekli."
    exit 1
fi

# ============================================================
# HEDEF KULLANICI
# ============================================================

TARGET_USER=""

if [[ -n "${SUDO_USER:-}" ]] && id "$SUDO_USER" >/dev/null 2>&1; then
    TARGET_USER="$SUDO_USER"
fi

if [[ -z "$TARGET_USER" ]] && [[ -n "${USER:-}" ]] && id "$USER" >/dev/null 2>&1; then
    if [[ "$USER" != "root" ]]; then
        TARGET_USER="$USER"
    fi
fi

if [[ -z "$TARGET_USER" ]]; then
    TARGET_USER="$(
        awk -F: '
        $3 >= 1000 && $3 < 60000 && $1 != "nobody" {
            print $1
            exit
        }' /etc/passwd
    )"
fi

if [[ -z "$TARGET_USER" ]]; then
    TARGET_USER="root"
fi

TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || echo 0)"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "/root")"

# ============================================================
# MASAÜSTÜ TESPİTİ
# ============================================================

DESKTOP="Bilinmiyor"

if pgrep -u "$TARGET_USER" -x xfce4-session >/dev/null 2>&1 || \
   pgrep -u "$TARGET_USER" -x xfdesktop >/dev/null 2>&1; then
    DESKTOP="XFCE"
elif pgrep -u "$TARGET_USER" -x gnome-session >/dev/null 2>&1 || \
     pgrep -u "$TARGET_USER" -x gnome-shell >/dev/null 2>&1; then
    DESKTOP="GNOME"
elif pgrep -u "$TARGET_USER" -x plasmashell >/dev/null 2>&1; then
    DESKTOP="KDE Plasma"
elif pgrep -u "$TARGET_USER" -x cinnamon-session >/dev/null 2>&1; then
    DESKTOP="Cinnamon"
elif pgrep -u "$TARGET_USER" -x mate-session >/dev/null 2>&1; then
    DESKTOP="MATE"
else
    DESKTOP="${XDG_CURRENT_DESKTOP:-Bilinmiyor}"
    [[ -z "$DESKTOP" ]] && DESKTOP="Bilinmiyor"
fi

HOSTNAME_CURRENT="$(hostname 2>/dev/null || echo "Bilinmiyor")"

# ============================================================
# TTY GİRİŞ FONKSİYONLARI
#
# ÖNEMLİ:
# curl | sudo bash kullanımında stdin curl pipe'ıdır.
# Bu nedenle kullanıcı girişlerini /dev/tty üzerinden alıyoruz.
# ============================================================

read_tty() {
    local variable_name="$1"
    local prompt_text="$2"
    local value=""

    if [[ -t 0 ]]; then
        IFS= read -r -p "$prompt_text" value
    elif [[ -r /dev/tty ]]; then
        IFS= read -r -p "$prompt_text" value < /dev/tty
    else
        error_msg "Terminal girişi alınamıyor."
        return 1
    fi

    printf -v "$variable_name" '%s' "$value"
    return 0
}

read_tty_hidden() {
    local variable_name="$1"
    local prompt_text="$2"
    local value=""

    if [[ -t 0 ]]; then
        IFS= read -r -s -p "$prompt_text" value
    elif [[ -r /dev/tty ]]; then
        IFS= read -r -s -p "$prompt_text" value < /dev/tty
    else
        error_msg "Terminal girişi alınamıyor."
        return 1
    fi

    printf '\n'
    printf -v "$variable_name" '%s' "$value"
    return 0
}

ask_yes_no() {
    local question="$1"
    local answer=""

    while true; do
        if ! read_tty answer "$question [e/H]: "; then
            return 1
        fi

        case "${answer,,}" in
            e|evet|y|yes)
                return 0
                ;;
            h|hayır|hayir|n|no|"")
                return 1
                ;;
            *)
                printf '%bLütfen e veya h girin.%b\n' "$YELLOW" "$NC"
                ;;
        esac
    done
}

pause_tty() {
    local dummy=""

    printf '\n%bDevam etmek için Enter tuşuna basın...%b' "$GRAY" "$NC"

    if [[ -r /dev/tty ]]; then
        IFS= read -r dummy < /dev/tty
    elif [[ -t 0 ]]; then
        IFS= read -r dummy
    fi

    printf '\n'
}

clear_screen() {
    if command -v clear >/dev/null 2>&1 && [[ -t 1 ]]; then
        clear 2>/dev/null || true
    else
        printf '\n\n'
    fi
}

# ============================================================
# PAKET FONKSİYONLARI
# ============================================================

package_available() {
    local package="$1"

    [[ -n "$package" ]] || return 1

    apt-cache show "$package" >/dev/null 2>&1
}

package_installed() {
    local package="$1"

    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | \
        grep -q 'install ok installed'
}

install_package() {
    local package="$1"

    [[ -n "$package" ]] || return 1

    if package_installed "$package"; then
        success "$package zaten kurulu."
        return 0
    fi

    if ! package_available "$package"; then
        warning "$package mevcut depolarda bulunamadı."
        return 1
    fi

    info "$package kuruluyor..."

    if DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"; then
        success "$package kuruldu."
        return 0
    fi

    warning "$package kurulamadı."
    return 1
}

install_if_available() {
    local package="$1"
    install_package "$package"
}

# ============================================================
# APT UPDATE
# ============================================================

update_apt() {
    printf '\n'
    printf '%bAPT paket listesi güncelleniyor...%b\n\n' "$CYAN" "$NC"

    if apt-get update; then
        success "APT paket listeleri güncellendi."
    else
        error_msg "APT güncellemesi sırasında hata oluştu."
        return 1
    fi
}

# ============================================================
# YEDEKLEME
# ============================================================

BACKUP_DIR=""

create_backup() {

    if [[ -n "$BACKUP_DIR" ]] && [[ -d "$BACKUP_DIR" ]]; then
        return 0
    fi

    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"

    BACKUP_DIR="/root/linux-turkce-backup-$timestamp"

    mkdir -p "$BACKUP_DIR"

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

    success "Yedek oluşturuldu: $BACKUP_DIR"
    log "Backup: $BACKUP_DIR"
}

show_last_backup() {

    printf '\n'
    printf '%bSon yedekler:%b\n\n' "$CYAN" "$NC"

    local found=0

    while IFS= read -r dir; do
        printf '  %s\n' "$dir"
        found=1
    done < <(find /root -maxdepth 1 -type d -name 'linux-turkce-backup-*' -print 2>/dev/null | sort -r | head -10)

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

    install_if_available locales

    if [[ ! -f /etc/locale.gen ]]; then
        touch /etc/locale.gen
    fi

    if grep -qE '^[[:space:]#]*tr_TR\.UTF-8[[:space:]]+UTF-8' /etc/locale.gen; then
        sed -i -E 's/^[[:space:]#]*tr_TR\.UTF-8[[:space:]]+UTF-8/tr_TR.UTF-8 UTF-8/' /etc/locale.gen
    else
        printf '%s\n' 'tr_TR.UTF-8 UTF-8' >> /etc/locale.gen
    fi

    if command -v locale-gen >/dev/null 2>&1; then
        locale-gen tr_TR.UTF-8 || warning "locale-gen sırasında uyarı oluştu."
    fi

    if command -v update-locale >/dev/null 2>&1; then
        update-locale LANG=tr_TR.UTF-8 LANGUAGE=tr_TR:tr || \
            warning "update-locale başarısız oldu."
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

    export LANG="tr_TR.UTF-8"
    export LANGUAGE="tr_TR:tr"

    success "Sistem locale ayarları Türkçe olarak yapılandırıldı."
    warning "Dil değişikliğinin tüm uygulamalara uygulanması için oturumu kapatıp açmanız veya sistemi yeniden başlatmanız gerekebilir."
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

    install_if_available keyboard-configuration

    cat > /etc/default/keyboard <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="tr"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

    if command -v localectl >/dev/null 2>&1; then
        localectl set-x11-keymap tr pc105 "" "" 2>/dev/null || true
        localectl set-keymap tr 2>/dev/null || true
    fi

    if command -v setxkbmap >/dev/null 2>&1; then
        if [[ -n "${DISPLAY:-}" ]]; then
            setxkbmap tr 2>/dev/null || true
        fi
    fi

    success "Türkçe Q klavye yapılandırıldı."
}

# ============================================================
# GNOME / KDE / XFCE
# ============================================================

run_as_target_user() {

    local command_to_run=("$@")

    if [[ "$TARGET_USER" == "root" ]]; then
        "${command_to_run[@]}"
        return $?
    fi

    local uid
    uid="$(id -u "$TARGET_USER" 2>/dev/null || echo 0)"

    if [[ -S "/run/user/$uid/bus" ]]; then
        runuser -u "$TARGET_USER" -- \
            env \
            XDG_RUNTIME_DIR="/run/user/$uid" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
            "${command_to_run[@]}"
    else
        runuser -u "$TARGET_USER" -- "${command_to_run[@]}"
    fi
}

configure_gnome() {

    if ! command -v gsettings >/dev/null 2>&1; then
        warning "gsettings bulunamadı."
        return 1
    fi

    if run_as_target_user gsettings set org.gnome.system.locale region 'tr_TR.UTF-8'; then
        success "GNOME bölge ayarı Türkçe olarak ayarlandı."
    else
        warning "GNOME oturum DBus bağlantısı bulunamadı."
    fi
}

configure_kde() {

    install_if_available kde-l10n-tr || true

    warning "Modern KDE Plasma sürümlerinde Türkçe arayüz paketi masaüstü sürümüne göre değişebilir."
    warning "Locale Türkçe olarak ayarlandığında KDE oturumu yeniden başlatılmalıdır."
}

configure_xfce() {

    if command -v xfconf-query >/dev/null 2>&1; then
        success "XFCE algılandı."
        info "XFCE için sistem locale ve klavye ayarları kullanılacaktır."
    else
        warning "xfconf-query bulunamadı."
    fi
}

configure_desktop() {

    printf '\n'
    printf '%b========================================%b\n' "$CYAN" "$NC"
    printf '%bGNOME / KDE / XFCE%b\n' "$CYAN" "$NC"
    printf '%b========================================%b\n\n' "$CYAN" "$NC"

    case "${DESKTOP,,}" in

        *gnome*)
            info "GNOME masaüstü algılandı."
            configure_gnome
            ;;

        *kde*|*plasma*)
            info "KDE Plasma masaüstü algılandı."
            configure_kde
            ;;

        *xfce*)
            info "XFCE masaüstü algılandı."
            configure_xfce
            ;;

        *)
            warning "Masaüstü otomatik olarak tanınamadı: $DESKTOP"
            info "GNOME ayarları deneniyor..."
            configure_gnome || true
            info "KDE dil paketi kontrol ediliyor..."
            configure_kde || true
            ;;

    esac

    printf '\n'
    success "Masaüstü yapılandırma işlemi tamamlandı."
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
        install_if_available "$package" || true
    done

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi

    success "Font kurulumu tamamlandı."
}

# ============================================================
# UYGULAMALAR
# ============================================================

configure_chromium() {

    if package_available chromium-l10n; then
        install_if_available chromium-l10n || true
    else
        warning "chromium-l10n paketi bulunamadı."
    fi
}

configure_firefox() {

    if package_available firefox-esr-l10n-tr; then
        install_if_available firefox-esr-l10n-tr || true
    elif package_available firefox-l10n-tr; then
        install_if_available firefox-l10n-tr || true
    else
        warning "Firefox Türkçe dil paketi bulunamadı."
    fi
}

configure_libreoffice() {

    if package_available libreoffice-l10n-tr; then
        install_if_available libreoffice-l10n-tr || true
    else
        warning "LibreOffice Türkçe dil paketi bulunamadı."
    fi
}

configure_applications() {

    printf '\n'
    printf '%b========================================%b\n' "$CYAN" "$NC"
    printf '%bUYGULAMALARI TÜRKÇELEŞTİR%b\n' "$CYAN" "$NC"
    printf '%b========================================%b\n\n' "$CYAN" "$NC"

    configure_chromium
    configure_firefox
    configure_libreoffice

    # Genel Türkçe dil paketleri
    install_if_available language-pack-tr || true
    install_if_available language-pack-gnome-tr || true

    success "Uygulama dil paketleri kontrol edildi."
    warning "Bazı uygulamalarda Türkçe arayüz için uygulamayı kapatıp yeniden açmak veya Ayarlar > Dil bölümünden Türkçe seçmek gerekebilir."
}

# ============================================================
# MAN SAYFALARI
# ============================================================

install_turkish_manpages() {

    printf '\n'
    printf '%b========================================%b\n' "$CYAN" "$NC"
    printf '%bTÜRKÇE MAN SAYFALARI%b\n' "$CYAN" "$NC"
    printf '%b========================================%b\n\n' "$CYAN" "$NC"

    local packages=(
        manpages-tr
        manpages-tr-dev
    )

    local package

    for package in "${packages[@]}"; do
        install_if_available "$package" || true
    done

    success "Türkçe man sayfası paketleri kontrol edildi."
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
        return 1
    fi

    if [[ -z "$search_term" ]]; then
        warning "Arama ifadesi boş."
        return 1
    fi

    printf '\n'
    apt-cache search "$search_term" 2>/dev/null | head -100

    printf '\n'
    success "Arama tamamlandı."
}

# ============================================================
# SUDO YÖNETİMİ
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
        error_msg "sudo/wheel grubu bulunamadı."
        return 1
    fi
}

remove_sudo() {

    local username="$1"

    if getent group sudo >/dev/null 2>&1; then
        gpasswd -d "$username" sudo >/dev/null 2>&1 || true
    fi

    if getent group wheel >/dev/null 2>&1; then
        gpasswd -d "$username" wheel >/dev/null 2>&1 || true
    fi

    success "$username sudo/wheel gruplarından çıkarıldı."
}

# ============================================================
# KULLANICI LİSTELE
# ============================================================

list_users() {

    printf '\n'
    printf '%bKullanıcılar:%b\n\n' "$CYAN" "$NC"

    printf '%-20s %-8s %-30s\n' "KULLANICI" "UID" "HOME"
    printf '%-20s %-8s %-30s\n' "--------------------" "--------" "------------------------------"

    awk -F: '$3 >= 1000 && $3 < 60000 {
        printf "%-20s %-8s %-30s\n", $1, $3, $6
    }' /etc/passwd

    printf '\n'
}

# ============================================================
# KULLANICI OLUŞTUR
# ============================================================

create_user() {

    local username=""
    local password=""
    local password2=""

    printf '\n'
    printf '%bYENİ KULLANICI%b\n\n' "$CYAN" "$NC"

    if ! read_tty username "Kullanıcı adı: "; then
        return 1
    fi

    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        error_msg "Geçersiz kullanıcı adı."
        return 1
    fi

    if id "$username" >/dev/null 2>&1; then
        error_msg "Bu kullanıcı zaten mevcut."
        return 1
    fi

    if ! useradd -m -s /bin/bash "$username"; then
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

    if ! id "$old_username" >/dev/null 2>&1; then
        error_msg "Kullanıcı bulunamadı."
        return 1
    fi

    if [[ "$old_username" == "$TARGET_USER" ]]; then
        error_msg "Aktif kullanıcı adını bu menüden değiştirmek güvenli değil."
        warning "Önce farklı bir yönetici hesabıyla giriş yapın."
        return 1
    fi

    if ! read_tty new_username "Yeni kullanıcı adı: "; then
        return 1
    fi

    if [[ ! "$new_username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        error_msg "Geçersiz yeni kullanıcı adı."
        return 1
    fi

    if id "$new_username" >/dev/null 2>&1; then
        error_msg "Yeni kullanıcı adı zaten kullanılıyor."
        return 1
    fi

    if pgrep -u "$old_username" >/dev/null 2>&1; then
        error_msg "Kullanıcının çalışan işlemleri var."
        warning "Kullanıcı oturumunu kapatıp tekrar deneyin."
        return 1
    fi

    old_home="$(getent passwd "$old_username" | cut -d: -f6)"
    new_home="/home/$new_username"

    if ! usermod -l "$new_username" "$old_username"; then
        error_msg "Kullanıcı adı değiştirilemedi."
        return 1
    fi

    if [[ -n "$old_home" && -d "$old_home" ]]; then
        usermod -d "$new_home" -m "$new_username" || \
            warning "Home dizini taşınamadı."
    fi

    success "Kullanıcı adı değiştirildi: $old_username -> $new_username"
}

# ============================================================
# KULLANICI SİL
# ============================================================

delete_user() {

    local username=""

    if ! read_tty username "Silinecek kullanıcı: "; then
        return 1
    fi

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

    printf '\n'
    warning "Bu işlem kullanıcı home dizinini de silecektir."

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
# KULLANICI YÖNETİM MENÜSÜ
# ============================================================

user_management_menu() {

    while true; do

        clear_screen

        printf '%b\n'
        printf '%b╔══════════════════════════════════════════════╗%b\n' "$CYAN" "$NC"
        printf '%b║              KULLANICI YÖNETİMİ             ║%b\n' "$CYAN" "$NC"
        printf '%b╠══════════════════════════════════════════════╣%b\n' "$CYAN" "$NC"
        printf '%b║ 1) Kullanıcıları listele                    ║%b\n' "$NC"
        printf '%b║ 2) Kullanıcı oluştur                        ║%b\n' "$NC"
        printf '%b║ 3) Kullanıcı şifresi değiştir               ║%b\n' "$NC"
        printf '%b║ 4) Kullanıcıya sudo yetkisi ver             ║%b\n' "$NC"
        printf '%b║ 5) Kullanıcıdan sudo yetkisini kaldır      ║%b\n' "$NC"
        printf '%b║ 6) Kullanıcı adını değiştir                 ║%b\n' "$NC"
        printf '%b║ 7) Kullanıcı sil                            ║%b\n' "$NC"
        printf '%b║ 0) Geri                                      ║%b\n' "$NC"
        printf '%b╚══════════════════════════════════════════════╝%b\n\n' "$CYAN" "$NC"

        local choice=""

        if ! read_tty choice "Seçiminiz [0-7]: "; then
            return 1
        fi

        choice="${choice#"${choice%%[![:space:]]*}"}"
        choice="${choice%"${choice##*[![:space:]]}"}"

        case "$choice" in

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
                if read_tty username_grant "Sudo verilecek kullanıcı: "; then
                    grant_sudo "$username_grant"
                fi
                pause_tty
                ;;

            5)
                local username_remove=""
                if read_tty username_remove "Sudo kaldırılacak kullanıcı: "; then
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

            0)
                return 0
                ;;

            *)
                warning "Geçersiz seçim: [$choice]"
                printf 'Lütfen 0 ile 7 arasında seçim yapın.\n'
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
    printf '%bMEVCUT HOSTNAME: %s%b\n\n' "$CYAN" "$HOSTNAME_CURRENT" "$NC"

    if ! read_tty new_hostname "Yeni hostname: "; then
        return 1
    fi

    if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{0,62}$ ]]; then
        error_msg "Geçersiz hostname."
        return 1
    fi

    create_backup

    if hostnamectl set-hostname "$new_hostname" 2>/dev/null; then
        success "Hostname değiştirildi: $new_hostname"
    else
        if hostname "$new_hostname" 2>/dev/null; then
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

    printf '%b\n'
    printf '%b╔══════════════════════════════════════════════════════════╗%b\n' "$CYAN" "$NC"
    printf '%b║                    SİSTEM BİLGİLERİ                     ║%b\n' "$CYAN" "$NC"
    printf '%b╚══════════════════════════════════════════════════════════╝%b\n\n' "$CYAN" "$NC"

    printf '%bİşletim Sistemi:%b %s\n' "$WHITE" "$NC" "$OS_NAME"
    printf '%bOS ID          :%b %s\n' "$WHITE" "$NC" "$OS_ID"
    printf '%bKernel         :%b %s\n' "$WHITE" "$NC" "$(uname -r)"
    printf '%bMimari         :%b %s\n' "$WHITE" "$NC" "$(uname -m)"
    printf '%bKullanıcı      :%b %s\n' "$WHITE" "$NC" "$TARGET_USER"
    printf '%bUID            :%b %s\n' "$WHITE" "$NC" "$TARGET_UID"
    printf '%bHome           :%b %s\n' "$WHITE" "$NC" "$TARGET_HOME"
    printf '%bMasaüstü       :%b %s\n' "$WHITE" "$NC" "$DESKTOP"
    printf '%bHostname       :%b %s\n' "$WHITE" "$NC" "$(hostname)"
    printf '%bLocale         :%b %s\n' "$WHITE" "$NC" "${LANG:-ayarlı değil}"

    printf '\n%bBellek:%b\n' "$WHITE" "$NC"

    if command -v free >/dev/null 2>&1; then
        free -h
    fi

    printf '\n%bDisk:%b\n' "$WHITE" "$NC"

    df -h / 2>/dev/null || true

    printf '\n%bIP adresleri:%b\n' "$WHITE" "$NC"

    if command -v ip >/dev/null 2>&1; then
        ip -brief address 2>/dev/null || true
    fi
}

# ============================================================
# TAM TÜRKÇELEŞTİRME
# ============================================================

full_turkish_setup() {

    printf '\n'
    printf '%b╔══════════════════════════════════════════════════════════╗%b\n' "$GREEN" "$NC"
    printf '%b║              TAM TÜRKÇELEŞTİRME                         ║%b\n' "$GREEN" "$NC"
    printf '%b╚══════════════════════════════════════════════════════════╝%b\n\n' "$GREEN" "$NC"

    warning "İşlem sistem locale, klavye, font ve uygulama dil paketlerini yapılandıracaktır."
    printf '\n'

    if ! ask_yes_no "Devam edilsin mi?"; then
        info "İşlem iptal edildi."
        return 0
    fi

    create_backup

    printf '\n'
    info "APT paket listesi güncelleniyor..."

    if ! apt-get update; then
        warning "APT güncellemesi başarısız oldu."
        warning "Mevcut paket listeleriyle devam edilecek."
    fi

    printf '\n'
    printf '%b[1/6] Locale%b\n' "$CYAN" "$NC"
    configure_locale

    printf '\n'
    printf '%b[2/6] Klavye%b\n' "$CYAN" "$NC"
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
    printf '%b╔══════════════════════════════════════════════════════════╗%b\n' "$GREEN" "$NC"
    printf '%b║              İŞLEM TAMAMLANDI                           ║%b\n' "$GREEN" "$NC"
    printf '%b╚══════════════════════════════════════════════════════════╝%b\n' "$GREEN" "$NC"

    printf '\n'
    success "Türkçeleştirme işlemleri tamamlandı."

    if [[ -n "$BACKUP_DIR" ]]; then
        info "Yedek: $BACKUP_DIR"
    fi

    warning "Değişikliklerin tamamının uygulanması için sistemi yeniden başlatmanız önerilir."
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

        printf '%b\n' "$WHITE"
        printf '╔══════════════════════════════════════════════════════════╗\n'
        printf '║        LINUX TÜRKÇELEŞTİRME & YÖNETİM ARACI             ║\n'
        printf '║                         v%s                         ║\n' "$VERSION"
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
        printf '%b\n' "$NC"

        local choice=""

        # ====================================================
        # EN ÖNEMLİ KISIM:
        # stdin pipe olsa bile /dev/tty'den seçim alıyoruz.
        # Böylece:
        #
        # curl ... | sudo bash
        #
        # komutu takılmaz.
        # ====================================================

        if ! read_tty choice "Seçiminiz [0-14]: "; then
            printf '\n'
            error_msg "Terminal girişi alınamadı."
            exit 1
        fi

        # Boşlukları temizle
        choice="${choice#"${choice%%[![:space:]]*}"}"
        choice="${choice%"${choice##*[![:space:]]}"}"

        case "$choice" in

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

            0)
                printf '\n'
                success "Programdan çıkılıyor."
                exit 0
                ;;

            "")
                warning "Seçim boş bırakılamaz."
                sleep 1
                ;;

            *)
                # GEÇERSİZ SEÇİM BURADA TAKILMAZ.
                warning "Geçersiz seçim: [$choice]"
                printf 'Lütfen 0 ile 14 arasında bir seçim yapın.\n'
                sleep 1
                ;;

        esac

    done
}

# ============================================================
# BAŞLANGIÇ
# ============================================================

main() {

    log "=========================================="
    log "Script başlatıldı"
    log "Version: $VERSION"
    log "OS: $OS_NAME"
    log "User: $TARGET_USER"
    log "Desktop: $DESKTOP"
    log "Hostname: $HOSTNAME_CURRENT"

    printf '\n'
    printf '%b%s v%s%b\n' "$GREEN" "$SCRIPT_NAME" "$VERSION" "$NC"
    printf '%bSistem: %s%b\n' "$GRAY" "$OS_NAME" "$NC"
    printf '%bKullanıcı: %s%b\n' "$GRAY" "$TARGET_USER" "$NC"
    printf '\n'

    main_menu
}

main "$@"
