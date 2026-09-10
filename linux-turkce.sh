```bash
#!/usr/bin/env bash

# ============================================================
# LINUX TÜRKÇELEŞTİRME + PENTEST KURULUM ARACI
# v2026.8
#
# KURULUMDA SADECE 2 SORU SORAR:
#
#   1) Linux Türkçe yapılsın mı?
#   2) Pentest araçları kurulsun mu?
#
# Ardından seçilen işlemleri otomatik gerçekleştirir.
#
# Kullanım:
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

VERSION="2026.8"
LOG_FILE="/var/log/linux-turkce.log"

# ============================================================
# RENKLER
# ============================================================

if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    CYAN=$'\033[0;36m'
    MAGENTA=$'\033[0;35m'
    WHITE=$'\033[1;37m'
    GRAY=$'\033[0;90m'
    NC=$'\033[0m'
else
    RED=""
    GREEN=""
    YELLOW=""
    CYAN=""
    MAGENTA=""
    WHITE=""
    GRAY=""
    NC=""
fi

# ============================================================
# GLOBAL
# ============================================================

OS_NAME="Bilinmiyor"
OS_ID="unknown"
OS_VERSION="unknown"
OS_LIKE=""

TARGET_USER="root"
TARGET_HOME="/root"
DESKTOP="Bilinmiyor"

BACKUP_DIR=""

DO_TURKISH=0
DO_PENTEST=0

TOTAL_PACKAGES=0
INSTALLED_PACKAGES=0
ALREADY_INSTALLED=0
SKIPPED_PACKAGES=0
FAILED_PACKAGES=0

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

        error_msg "Bu script root yetkisiyle çalıştırılmalıdır."

        printf '\n'
        printf 'Kullanım:\n'
        printf '  sudo bash linux-turkce.sh\n\n'

        exit 1
    fi
}

# ============================================================
# SİSTEM TESPİTİ
# ============================================================

load_system_info() {

    if [[ ! -r /etc/os-release ]]; then

        error_msg "/etc/os-release bulunamadı."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    OS_NAME="${PRETTY_NAME:-${NAME:-Bilinmeyen Linux}}"
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"

    if ! command -v apt-get >/dev/null 2>&1; then

        error_msg "apt-get bulunamadı."
        error_msg "Debian/Kali/Ubuntu tabanlı sistem gereklidir."

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
         [[ "${USER:-}" != "root" ]] &&
         id "${USER:-}" >/dev/null 2>&1; then

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

    [[ -n "$TARGET_USER" ]] ||
        TARGET_USER="root"

    TARGET_HOME="$(
        getent passwd "$TARGET_USER" 2>/dev/null |
        cut -d: -f6
    )"

    [[ -n "$TARGET_HOME" ]] ||
        TARGET_HOME="/root"
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

    elif [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then

        DESKTOP="$XDG_CURRENT_DESKTOP"

    elif [[ -n "${DESKTOP_SESSION:-}" ]]; then

        DESKTOP="$DESKTOP_SESSION"
    fi
}

# ============================================================
# TTY OKUMA
# ============================================================

read_tty() {

    local variable="$1"
    local prompt="$2"
    local value=""

    if [[ -r /dev/tty ]]; then

        printf '%s' "$prompt" > /dev/tty

        if ! IFS= read -r value < /dev/tty; then
            return 1
        fi

    elif [[ -t 0 ]]; then

        printf '%s' "$prompt"

        if ! IFS= read -r value; then
            return 1
        fi

    else

        return 1
    fi

    value="${value//$'\r'/}"

    printf -v "$variable" '%s' "$value"

    return 0
}

# ============================================================
# EVET / HAYIR
# ============================================================

ask_yes_no() {

    local question="$1"
    local answer=""

    while true; do

        if ! read_tty answer "$question [E/h]: "; then
            return 1
        fi

        answer="${answer,,}"

        case "$answer" in

            e|evet|y|yes)
                return 0
                ;;

            h|hayir|hayır|n|no|"")
                return 1
                ;;

            *)
                warning "Lütfen E veya H girin."
                ;;
        esac
    done
}

# ============================================================
# SEÇİMLER
# ============================================================

ask_options() {

    clear 2>/dev/null || true

    printf '%b╔══════════════════════════════════════════════════════════╗%b\n' \
        "$CYAN" "$NC"

    printf '%b║       LINUX TÜRKÇELEŞTİRME + PENTEST ARACI            ║%b\n' \
        "$CYAN" "$NC"

    printf '%b║                         v%-25s║%b\n' \
        "$CYAN" "$VERSION" "$NC"

    printf '%b╚══════════════════════════════════════════════════════════╝%b\n\n' \
        "$CYAN" "$NC"

    printf '%bSistem:%b %s\n' \
        "$WHITE" "$NC" "$OS_NAME"

    printf '%bKullanıcı:%b %s\n' \
        "$WHITE" "$NC" "$TARGET_USER"

    printf '%bMasaüstü:%b %s\n' \
        "$WHITE" "$NC" "$DESKTOP"

    printf '\n'

    # --------------------------------------------------------
    # 1. SORU
    # --------------------------------------------------------

    if ask_yes_no "Linux Türkçe yapılsın mı?"; then

        DO_TURKISH=1

    else

        DO_TURKISH=0
    fi

    # --------------------------------------------------------
    # 2. SORU
    # --------------------------------------------------------

    if ask_yes_no "Pentest araçları kurulsun mu?"; then

        DO_PENTEST=1

    else

        DO_PENTEST=0
    fi

    printf '\n'

    if [[ "$DO_TURKISH" -eq 0 &&
          "$DO_PENTEST" -eq 0 ]]; then

        info "Hiçbir kurulum seçilmedi."
        exit 0
    fi
}

# ============================================================
# APT KİLİT
# ============================================================

wait_for_apt_lock() {

    local waited=0
    local max_wait=90

    while true; do

        if ! fuser \
            /var/lib/dpkg/lock-frontend \
            /var/lib/dpkg/lock \
            /var/lib/apt/lists/lock \
            >/dev/null 2>&1; then

            return 0
        fi

        if [[ "$waited" -ge "$max_wait" ]]; then

            error_msg "APT kilidi açılamadı."
            error_msg "Başka bir paket yöneticisi çalışıyor olabilir."

            return 1
        fi

        printf '\r%bAPT kilidi bekleniyor: %2ds%b' \
            "$YELLOW" "$waited" "$NC"

        sleep 1
        ((waited++))
    done
}

# ============================================================
# APT UPDATE
# ============================================================

apt_update() {

    printf '\n'
    printf '%bAPT paket listeleri güncelleniyor...%b\n\n' \
        "$CYAN" "$NC"

    if ! wait_for_apt_lock; then
        return 1
    fi

    if apt-get update; then

        success "APT güncellendi."

    else

        error_msg "apt-get update başarısız."

        return 1
    fi

    # Yarım kalmış dpkg işlemleri
    dpkg --configure -a \
        >/dev/null 2>&1 || true

    return 0
}

# ============================================================
# PAKET KONTROL
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

# ============================================================
# TEK PAKET KUR
# ============================================================

install_one() {

    local package="$1"

    [[ -n "$package" ]] || return 0

    ((TOTAL_PACKAGES++))

    if package_installed "$package"; then

        ((ALREADY_INSTALLED++))

        printf '%b[VAR]%b       %s\n' \
            "$GREEN" "$NC" "$package"

        return 0
    fi

    if ! package_available "$package"; then

        ((SKIPPED_PACKAGES++))

        printf '%b[YOK]%b       %s\n' \
            "$YELLOW" "$NC" "$package"

        return 0
    fi

    printf '%b[KURULUYOR]%b %s\n' \
        "$CYAN" "$NC" "$package"

    if DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends "$package"; then

        ((INSTALLED_PACKAGES++))

        printf '%b[ OK ]%b      %s\n' \
            "$GREEN" "$NC" "$package"

    else

        ((FAILED_PACKAGES++))

        printf '%b[HATA]%b      %s\n' \
            "$RED" "$NC" "$package"

        dpkg --configure -a \
            >/dev/null 2>&1 || true
    fi
}

# ============================================================
# YEDEK
# ============================================================

create_backup() {

    local timestamp

    timestamp="$(date '+%Y%m%d_%H%M%S')"

    BACKUP_DIR="/root/linux-turkce-backup-$timestamp"

    if ! mkdir -p "$BACKUP_DIR"; then

        warning "Yedek klasörü oluşturulamadı."
        BACKUP_DIR=""
        return 1
    fi

    local files=(
        /etc/locale.gen
        /etc/default/locale
        /etc/default/keyboard
        /etc/hostname
        /etc/hosts
    )

    local file

    for file in "${files[@]}"; do

        if [[ -f "$file" ]]; then

            cp -a "$file" "$BACKUP_DIR/" \
                2>/dev/null || true
        fi
    done

    success "Yedek oluşturuldu: $BACKUP_DIR"
}

# ============================================================
# TÜRKÇE LOCALE
# ============================================================

configure_locale() {

    printf '\n'
    printf '%b[1/6] Sistem dili Türkçe yapılıyor...%b\n\n' \
        "$CYAN" "$NC"

    install_one locales

    [[ -f /etc/locale.gen ]] ||
        touch /etc/locale.gen

    sed -i \
        -E \
        '/^[[:space:]#]*tr_TR\.UTF-8[[:space:]]+UTF-8[[:space:]]*$/d' \
        /etc/locale.gen \
        2>/dev/null || true

    printf '%s\n' \
        'tr_TR.UTF-8 UTF-8' >> /etc/locale.gen

    if command -v locale-gen >/dev/null 2>&1; then

        locale-gen tr_TR.UTF-8 \
            >/dev/null 2>&1 || true
    fi

    if command -v update-locale >/dev/null 2>&1; then

        update-locale \
            LANG=tr_TR.UTF-8 \
            LANGUAGE=tr_TR:tr \
            >/dev/null 2>&1 || true

    else

        cat > /etc/default/locale <<'EOF'
LANG=tr_TR.UTF-8
LANGUAGE=tr_TR:tr
EOF

    fi

    cat > /etc/profile.d/turkish-locale.sh <<'EOF'
export LANG=tr_TR.UTF-8
export LANGUAGE=tr_TR:tr
EOF

    chmod 644 /etc/profile.d/turkish-locale.sh

    success "Sistem dili Türkçe ayarlandı."
}

# ============================================================
# KLAVYE
# ============================================================

configure_keyboard() {

    printf '%bTürkçe Q klavye ayarlanıyor...%b\n' \
        "$CYAN" "$NC"

    install_one keyboard-configuration

    cat > /etc/default/keyboard <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="tr"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

    if command -v localectl >/dev/null 2>&1; then

        localectl set-x11-keymap \
            tr pc105 "" "" \
            >/dev/null 2>&1 || true

        localectl set-keymap tr \
            >/dev/null 2>&1 || true
    fi

    if command -v setxkbmap >/dev/null 2>&1 &&
       [[ -n "${DISPLAY:-}" ]]; then

        setxkbmap tr \
            >/dev/null 2>&1 || true
    fi

    success "Türkçe Q klavye ayarlandı."
}

# ============================================================
# MASAÜSTÜ
# ============================================================

configure_desktop() {

    printf '%bMasaüstü ayarlanıyor...%b\n' \
        "$CYAN" "$NC"

    case "${DESKTOP,,}" in

        *gnome*)

            if command -v gsettings >/dev/null 2>&1 &&
               [[ "$TARGET_USER" != "root" ]]; then

                local uid

                uid="$(
                    id -u "$TARGET_USER" 2>/dev/null ||
                    printf '0'
                )"

                if [[ -S "/run/user/$uid/bus" ]]; then

                    runuser -u "$TARGET_USER" -- \
                        env \
                        HOME="$TARGET_HOME" \
                        XDG_RUNTIME_DIR="/run/user/$uid" \
                        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
                        gsettings set \
                        org.gnome.system.locale \
                        region \
                        'tr_TR.UTF-8' \
                        >/dev/null 2>&1 || true
                fi
            fi

            success "GNOME ayarlandı."
            ;;

        *kde*|*plasma*)

            if package_available kde-l10n-tr; then
                install_one kde-l10n-tr
            else
                info "KDE ayrı Türkçe paketi bulunamadı."
            fi

            ;;

        *xfce*)

            success "XFCE sistem locale kullanacak."
            ;;

        *)

            warning "Masaüstü algılanamadı: $DESKTOP"
            ;;
    esac
}

# ============================================================
# FONTLAR
# ============================================================

install_fonts() {

    printf '%bFontlar kuruluyor...%b\n' \
        "$CYAN" "$NC"

    install_one fonts-dejavu
    install_one fonts-liberation
    install_one fonts-noto-core
    install_one fonts-noto-cjk
    install_one fonts-noto-mono

    if command -v fc-cache >/dev/null 2>&1; then

        fc-cache -f \
            >/dev/null 2>&1 || true
    fi

    success "Font işlemi tamamlandı."
}

# ============================================================
# UYGULAMA DİLLERİ
# ============================================================

install_application_languages() {

    printf '%bUygulama Türkçe dil paketleri kuruluyor...%b\n' \
        "$CYAN" "$NC"

    if package_available firefox-esr-l10n-tr; then

        install_one firefox-esr-l10n-tr

    elif package_available firefox-l10n-tr; then

        install_one firefox-l10n-tr
    fi

    if package_available chromium-l10n; then

        install_one chromium-l10n
    fi

    if package_available libreoffice-l10n-tr; then

        install_one libreoffice-l10n-tr
    fi

    if [[ "$OS_ID" == "ubuntu" ]]; then

        if package_available language-pack-tr; then
            install_one language-pack-tr
        fi

        if package_available language-pack-gnome-tr; then
            install_one language-pack-gnome-tr
        fi
    fi

    success "Uygulama dil paketleri tamamlandı."
}

# ============================================================
# TÜRKÇE MAN
# ============================================================

install_manpages() {

    printf '%bTürkçe man sayfaları kuruluyor...%b\n' \
        "$CYAN" "$NC"

    if package_available manpages-tr; then

        install_one manpages-tr
    fi

    if package_available manpages-tr-dev; then

        install_one manpages-tr-dev
    fi

    success "Türkçe man sayfaları tamamlandı."
}

# ============================================================
# TAM TÜRKÇELEŞTİRME
# ============================================================

install_turkish() {

    printf '\n'
    printf '%b========================================%b\n' \
        "$CYAN" "$NC"

    printf '%b TÜRKÇELEŞTİRME %b\n' \
        "$CYAN" "$NC"

    printf '%b========================================%b\n\n' \
        "$CYAN" "$NC"

    configure_locale
    configure_keyboard
    configure_desktop
    install_fonts
    install_application_languages
    install_manpages

    success "Türkçeleştirme tamamlandı."
}

# ============================================================
# WEB / RECON
# ============================================================

install_web_recon() {

    printf '\n%b--- WEB / RECON --- %b\n' \
        "$MAGENTA" "$NC"

    install_one nmap
    install_one ncat
    install_one ndiff
    install_one nikto
    install_one sqlmap
    install_one gobuster
    install_one dirsearch
    install_one ffuf
    install_one feroxbuster
    install_one nuclei
    install_one whatweb
    install_one wafw00f
    install_one dnsenum
    install_one dnsrecon
    install_one fierce
    install_one amass
    install_one burpsuite
    install_one mitmproxy
    install_one zaproxy
}

# ============================================================
# REVERSE ENGINEERING
# ============================================================

install_reverse() {

    printf '\n%b--- REVERSE ENGINEERING --- %b\n' \
        "$MAGENTA" "$NC"

    install_one ghex
    install_one ghidra
    install_one jadx
    install_one rizin
    install_one radare2
    install_one rizin-cutter
    install_one rz-ghidra
    install_one apktool
    install_one dex2jar
    install_one bytecode-viewer
    install_one jd-gui
    install_one ropper
    install_one edb-debugger
    install_one binwalk
    install_one yara
    install_one gdb
    install_one strace
    install_one ltrace
    install_one binutils
}

# ============================================================
# WINDOWS / AD / SMB
# ============================================================

install_windows_ad() {

    printf '\n%b--- WINDOWS / AD / SMB --- %b\n' \
        "$MAGENTA" "$NC"

    install_one evil-winrm
    install_one samba
    install_one smbclient
    install_one cifs-utils
    install_one ldap-utils
    install_one enum4linux
    install_one enum4linux-ng
    install_one impacket-scripts
    install_one netexec
    install_one responder
    install_one bloodyad
}

# ============================================================
# STEGO / FORENSICS
# ============================================================

install_stego_forensics() {

    printf '\n%b--- STEGANOGRAPHY / FORENSICS --- %b\n' \
        "$MAGENTA" "$NC"

    install_one steghide
    install_one stegsnow
    install_one outguess
    install_one exiftool
    install_one foremost
    install_one sleuthkit
    install_one autopsy
    install_one testdisk
    install_one dc3dd
    install_one scalpel
}

# ============================================================
# NETWORK
# ============================================================

install_network() {

    printf '\n%b--- NETWORK / TRAFFIC --- %b\n' \
        "$MAGENTA" "$NC"

    install_one wireshark
    install_one tshark
    install_one tcpdump
    install_one netcat-openbsd
    install_one socat
    install_one bettercap
    install_one ettercap-graphical
    install_one arp-scan
    install_one traceroute
    install_one iperf3
    install_one masscan
}

# ============================================================
# PASSWORD / HASH
# ============================================================

install_password() {

    printf '\n%b--- PASSWORD / HASH --- %b\n' \
        "$MAGENTA" "$NC"

    install_one hashcat
    install_one john
    install_one hashid
    install_one hydra
    install_one medusa
    install_one patator
    install_one crunch
    install_one seclists
    install_one wordlists
}

# ============================================================
# WIRELESS
# ============================================================

install_wireless() {

    printf '\n%b--- WIRELESS --- %b\n' \
        "$MAGENTA" "$NC"

    install_one aircrack-ng
    install_one reaver
    install_one bully
    install_one kismet
    install_one hcxdumptool
    install_one hcxpcapngtool
    install_one wifite
    install_one rfkill
    install_one iw
}

# ============================================================
# GVM / OPENVAS
# ============================================================

install_gvm() {

    printf '\n%b--- GVM / OPENVAS --- %b\n' \
        "$MAGENTA" "$NC"

    if package_available gvm; then

        install_one gvm

    else

        warning "gvm paketi bu depoda bulunamadı."
    fi
}

# ============================================================
# YARDIMCI ARAÇLAR
# ============================================================

install_helpers() {

    printf '\n%b--- YARDIMCI ARAÇLAR --- %b\n' \
        "$MAGENTA" "$NC"

    install_one gedit
    install_one plank
    install_one kazam
    install_one terminator
    install_one sonic-visualiser

    install_one fzf
    install_one ripgrep
    install_one tmux
    install_one btop
    install_one jq
    install_one curl
    install_one wget
    install_one unzip
    install_one p7zip-full
    install_one git
    install_one gh

    if package_available eza; then
        install_one eza
    fi

    if package_available bat; then
        install_one bat
    fi
}

# ============================================================
# KALI METAPAKETLERİ
# ============================================================

install_kali_meta() {

    [[ "$OS_ID" == "kali" ]] || return 0

    printf '\n%b--- KALI METAPAKETLERİ --- %b\n' \
        "$MAGENTA" "$NC"

    if package_available kali-tools-web; then
        install_one kali-tools-web
    fi

    if package_available kali-tools-reverse-engineering; then
        install_one kali-tools-reverse-engineering
    fi

    if package_available kali-tools-information-gathering; then
        install_one kali-tools-information-gathering
    fi

    if package_available kali-tools-passwords; then
        install_one kali-tools-passwords
    fi

    if package_available kali-tools-wireless; then
        install_one kali-tools-wireless
    fi

    if package_available kali-tools-forensics; then
        install_one kali-tools-forensics
    fi

    if package_available kali-tools-windows-resources; then
        install_one kali-tools-windows-resources
    fi
}

# ============================================================
# PENTEST TAM KURULUM
# ============================================================

install_pentest() {

    printf '\n'
    printf '%b========================================%b\n' \
        "$MAGENTA" "$NC"

    printf '%b PENTEST ARAÇLARI KURULUYOR %b\n' \
        "$MAGENTA" "$NC"

    printf '%b========================================%b\n' \
        "$MAGENTA" "$NC"

    install_web_recon
    install_reverse
    install_windows_ad
    install_stego_forensics
    install_network
    install_password
    install_wireless
    install_gvm
    install_helpers
    install_kali_meta

    success "Pentest araç kurulumu tamamlandı."
}

# ============================================================
# SON KONTROL
# ============================================================

final_check() {

    printf '\n'
    info "Sistem son kontrolleri yapılıyor..."

    dpkg --configure -a \
        >/dev/null 2>&1 || true

    apt-get -f install -y \
        >/dev/null 2>&1 || true

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi

    success "Son kontroller tamamlandı."
}

# ============================================================
# ÖZET
# ============================================================

show_summary() {

    printf '\n\n'

    printf '%b╔══════════════════════════════════════════════════════════╗%b\n' \
        "$GREEN" "$NC"

    printf '%b║                  KURULUM TAMAMLANDI                   ║%b\n' \
        "$GREEN" "$NC"

    printf '%b╚══════════════════════════════════════════════════════════╝%b\n' \
        "$GREEN" "$NC"

    printf '\n'

    printf '%bSistem:%b %s\n' \
        "$WHITE" "$NC" "$OS_NAME"

    printf '%bKullanıcı:%b %s\n' \
        "$WHITE" "$NC" "$TARGET_USER"

    printf '%bMasaüstü:%b %s\n' \
        "$WHITE" "$NC" "$DESKTOP"

    printf '\n'

    if [[ "$DO_TURKISH" -eq 1 ]]; then
        printf 'Türkçeleştirme : EVET\n'
    else
        printf 'Türkçeleştirme : HAYIR\n'
    fi

    if [[ "$DO_PENTEST" -eq 1 ]]; then
        printf 'Pentest         : EVET\n'
    else
        printf 'Pentest         : HAYIR\n'
    fi

    printf '\n'

    printf '%bPAKET İSTATİSTİKLERİ%b\n' \
        "$CYAN" "$NC"

    printf '  Kontrol edilen : %s\n' "$TOTAL_PACKAGES"
    printf '  Yeni kurulan   : %s\n' "$INSTALLED_PACKAGES"
    printf '  Zaten kurulu   : %s\n' "$ALREADY_INSTALLED"
    printf '  Depoda olmayan : %s\n' "$SKIPPED_PACKAGES"
    printf '  Kurulum hatası : %s\n' "$FAILED_PACKAGES"

    if [[ -n "$BACKUP_DIR" ]]; then

        printf '\n'
        printf '%bYedek:%b %s\n' \
            "$CYAN" "$NC" "$BACKUP_DIR"
    fi

    if package_installed gvm; then

        printf '\n'
        printf '%bGVM / OPENVAS:%b\n' \
            "$MAGENTA" "$NC"

        printf '  sudo gvm-setup\n'
        printf '  sudo gvm-check-setup\n'
        printf '  sudo gvm-start\n'
    fi

    printf '\n'

    printf '%bÖneri:%b Oturumu kapatıp açın veya sistemi yeniden başlatın.\n' \
        "$YELLOW" "$NC"

    printf '\n'

    success "İşlem tamamlandı."
}

# ============================================================
# MAIN
# ============================================================

main() {

    init_log

    check_root
    load_system_info
    detect_target_user
    detect_desktop

    log "=============================================="
    log "Linux Türkçeleştirme + Pentest"
    log "Version: $VERSION"
    log "OS: $OS_NAME"
    log "OS ID: $OS_ID"
    log "User: $TARGET_USER"
    log "Desktop: $DESKTOP"
    log "=============================================="

    # --------------------------------------------------------
    # SADECE 2 SORU
    # --------------------------------------------------------

    ask_options

    # --------------------------------------------------------
    # APT HER ZAMAN İLK
    # --------------------------------------------------------

    if ! apt_update; then

        error_msg "APT güncellenemedi."
        error_msg "Kurulum durduruldu."

        exit 1
    fi

    # --------------------------------------------------------
    # YEDEK
    # --------------------------------------------------------

    if [[ "$DO_TURKISH" -eq 1 ]]; then

        create_backup
    fi

    # --------------------------------------------------------
    # TÜRKÇELEŞTİRME
    # --------------------------------------------------------

    if [[ "$DO_TURKISH" -eq 1 ]]; then

        install_turkish
    fi

    # --------------------------------------------------------
    # PENTEST
    # --------------------------------------------------------

    if [[ "$DO_PENTEST" -eq 1 ]]; then

        install_pentest
    fi

    # --------------------------------------------------------
    # SON KONTROL
    # --------------------------------------------------------

    final_check

    # --------------------------------------------------------
    # ÖZET
    # --------------------------------------------------------

    show_summary
}

main "$@"
```

