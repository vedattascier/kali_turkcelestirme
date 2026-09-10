#!/usr/bin/env bash

# ============================================================
# LINUX TÜRKÇELEŞTİRME + PENTEST ARAÇLARI
# v2026.6
#
# TEK SORU -> TEK SEFERDE KURULUM
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

VERSION="2026.6"
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

TOTAL=0
INSTALLED=0
ALREADY=0
SKIPPED=0
FAILED=0

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

ok() {
    printf '%b[ OK ]%b %s\n' "$GREEN" "$NC" "$*"
    log "OK: $*"
}

warn() {
    printf '%b[UYARI]%b %s\n' "$YELLOW" "$NC" "$*"
    log "UYARI: $*"
}

err() {
    printf '%b[HATA]%b %s\n' "$RED" "$NC" "$*"
    log "HATA: $*"
}

# ============================================================
# ROOT
# ============================================================

check_root() {

    if [[ "${EUID:-999}" -ne 0 ]]; then

        err "Bu script root yetkisiyle çalıştırılmalıdır."

        printf '\n'
        printf 'Kullanım:\n'
        printf '  sudo bash linux-turkce.sh\n\n'

        printf 'GitHub:\n'
        printf '  curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash\n\n'

        exit 1
    fi
}

# ============================================================
# SİSTEM
# ============================================================

load_system() {

    if [[ ! -r /etc/os-release ]]; then
        err "/etc/os-release bulunamadı."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    OS_NAME="${PRETTY_NAME:-${NAME:-Bilinmeyen Linux}}"
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"

    if ! command -v apt-get >/dev/null 2>&1; then
        err "apt-get bulunamadı."
        err "Debian/Kali/Ubuntu tabanlı sistem gereklidir."
        exit 1
    fi
}

# ============================================================
# HEDEF KULLANICI
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

    [[ -n "$TARGET_USER" ]] || TARGET_USER="root"

    TARGET_HOME="$(
        getent passwd "$TARGET_USER" 2>/dev/null |
        cut -d: -f6
    )"

    [[ -n "$TARGET_HOME" ]] || TARGET_HOME="/root"
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
# TTY GİRDİ
# ============================================================

read_tty() {

    local var_name="$1"
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

    printf -v "$var_name" '%s' "$value"

    return 0
}

# ============================================================
# TEK SORU
# ============================================================

ask_install() {

    local answer=""

    printf '\n'

    printf '%b╔══════════════════════════════════════════════════════════╗%b\n' \
        "$CYAN" "$NC"

    printf '%b║        TÜRKÇELEŞTİRME + PENTEST KURULUMU              ║%b\n' \
        "$CYAN" "$NC"

    printf '%b╚══════════════════════════════════════════════════════════╝%b\n\n' \
        "$CYAN" "$NC"

    printf '%bSistem:%b %s\n' "$WHITE" "$NC" "$OS_NAME"
    printf '%bKullanıcı:%b %s\n' "$WHITE" "$NC" "$TARGET_USER"
    printf '%bMasaüstü:%b %s\n' "$WHITE" "$NC" "$DESKTOP"

    printf '\n'
    printf 'Kurulum sırasında:\n'
    printf '  • APT güncellenecek\n'
    printf '  • Sistem Türkçeleştirilecek\n'
    printf '  • Türkçe Q klavye ayarlanacak\n'
    printf '  • Türkçe fontlar kurulacak\n'
    printf '  • Uygulama dil paketleri kurulacak\n'
    printf '  • Türkçe man sayfaları kurulacak\n'
    printf '  • Kali pentest araçları kurulacak\n'
    printf '  • Reverse engineering araçları kurulacak\n'
    printf '  • Windows / AD / SMB araçları kurulacak\n'
    printf '  • Web / Recon araçları kurulacak\n'
    printf '  • Network araçları kurulacak\n'
    printf '  • Wireless araçları kurulacak\n'
    printf '  • Password / Hash araçları kurulacak\n'
    printf '  • Steganography / Forensics araçları kurulacak\n'
    printf '  • GVM / OpenVAS kurulacak\n'
    printf '  • Gerekli yardımcı araçlar kurulacak\n'

    printf '\n'

    if ! read_tty answer \
        "Hepsi tek seferde kurulsun mu? [E/h]: "; then

        err "Terminal girdisi alınamadı."
        exit 1
    fi

    case "${answer,,}" in

        e|evet|y|yes)
            return 0
            ;;

        *)
            info "Kurulum iptal edildi."
            exit 0
            ;;
    esac
}

# ============================================================
# APT KİLİT
# ============================================================

wait_for_apt_lock() {

    local waited=0
    local max=90

    while true; do

        if ! fuser \
            /var/lib/dpkg/lock-frontend \
            /var/lib/dpkg/lock \
            /var/lib/apt/lists/lock \
            >/dev/null 2>&1; then

            return 0
        fi

        if [[ "$waited" -ge "$max" ]]; then

            err "APT kilidi açılamadı."
            err "Başka bir paket yöneticisi çalışıyor olabilir."

            return 1
        fi

        printf '\r%bAPT başka bir işlem tarafından kullanılıyor... %2ds%b' \
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
    printf '%b[1] APT güncelleniyor...%b\n\n' \
        "$CYAN" "$NC"

    if ! wait_for_apt_lock; then
        return 1
    fi

    if apt-get update; then

        ok "APT paket listeleri güncellendi."

    else

        err "apt-get update başarısız oldu."

        return 1
    fi

    # Yarım kalmış dpkg işlemlerini toparla
    dpkg --configure -a >/dev/null 2>&1 || true

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
# TEK PAKET
# ============================================================

install_one() {

    local package="$1"

    [[ -n "$package" ]] || return 0

    ((TOTAL++))

    if package_installed "$package"; then

        ((ALREADY++))

        printf '%b[VAR]%b       %s\n' \
            "$GREEN" "$NC" "$package"

        return 0
    fi

    if ! package_available "$package"; then

        ((SKIPPED++))

        printf '%b[YOK]%b       %s\n' \
            "$YELLOW" "$NC" "$package"

        return 0
    fi

    printf '%b[KURULUYOR]%b %s\n' \
        "$CYAN" "$NC" "$package"

    if DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends "$package"; then

        ((INSTALLED++))

        printf '%b[ OK ]%b      %s\n' \
            "$GREEN" "$NC" "$package"

    else

        ((FAILED++))

        printf '%b[HATA]%b      %s\n' \
            "$RED" "$NC" "$package"

        # Bozuk dpkg durumunda toparlamayı dene
        dpkg --configure -a >/dev/null 2>&1 || true
        apt-get -f install -y >/dev/null 2>&1 || true
    fi
}

# ============================================================
# PAKET LİSTESİ
# ============================================================

install_list() {

    local package

    for package in "$@"; do
        install_one "$package"
    done
}

# ============================================================
# YEDEK
# ============================================================

create_backup() {

    local timestamp

    timestamp="$(date '+%Y%m%d_%H%M%S')"

    BACKUP_DIR="/root/linux-turkce-backup-$timestamp"

    if ! mkdir -p "$BACKUP_DIR"; then

        warn "Yedek klasörü oluşturulamadı."
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

    ok "Sistem ayarlarının yedeği oluşturuldu: $BACKUP_DIR"
}

# ============================================================
# LOCALE
# ============================================================

configure_locale() {

    printf '\n'
    printf '%b[2] Türkçeleştiriliyor...%b\n\n' \
        "$CYAN" "$NC"

    install_one locales

    [[ -f /etc/locale.gen ]] ||
        touch /etc/locale.gen

    # Eski Türkçe satırlarını temizle
    sed -i \
        -E \
        '/^[[:space:]#]*tr_TR\.UTF-8[[:space:]]+UTF-8[[:space:]]*$/d' \
        /etc/locale.gen \
        2>/dev/null || true

    printf '%s\n' \
        'tr_TR.UTF-8 UTF-8' >> /etc/locale.gen

    if command -v locale-gen >/dev/null 2>&1; then
        locale-gen tr_TR.UTF-8 >/dev/null 2>&1 || true
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

    ok "Sistem dili Türkçe ayarlandı."
}

# ============================================================
# KLAVYE
# ============================================================

configure_keyboard() {

    printf '\n'
    printf '%b[3] Türkçe Q klavye ayarlanıyor...%b\n\n' \
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

        setxkbmap tr >/dev/null 2>&1 || true
    fi

    ok "Türkçe Q klavye ayarlandı."
}

# ============================================================
# MASAÜSTÜ
# ============================================================

configure_desktop() {

    printf '\n'
    printf '%b[4] Masaüstü ayarlanıyor...%b\n\n' \
        "$CYAN" "$NC"

    case "${DESKTOP,,}" in

        *gnome*)

            if command -v gsettings >/dev/null 2>&1; then

                local uid

                uid="$(id -u "$TARGET_USER" 2>/dev/null || printf '0')"

                if [[ "$TARGET_USER" != "root" ]] &&
                   [[ -S "/run/user/$uid/bus" ]]; then

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

            ok "GNOME ayarları uygulandı."
            ;;

        *kde*|*plasma*)

            if package_available kde-l10n-tr; then
                install_one kde-l10n-tr
            else
                info "KDE ayrı Türkçe paket sunmuyorsa sistem locale kullanılacak."
            fi

            ;;

        *xfce*)

            ok "XFCE sistem locale ayarını kullanacak."
            ;;

        *)

            warn "Masaüstü algılanamadı: $DESKTOP"
            info "Sistem locale yine uygulanmıştır."
            ;;
    esac
}

# ============================================================
# FONTLAR
# ============================================================

install_fonts() {

    printf '\n'
    printf '%b[5] Fontlar kuruluyor...%b\n\n' \
        "$CYAN" "$NC"

    install_list \
        fonts-dejavu \
        fonts-liberation \
        fonts-noto-core \
        fonts-noto-cjk \
        fonts-noto-mono

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi

    ok "Font kurulumu tamamlandı."
}

# ============================================================
# UYGULAMALAR
# ============================================================

install_app_languages() {

    printf '\n'
    printf '%b[6] Uygulamaların Türkçe dil paketleri...%b\n\n' \
        "$CYAN" "$NC"

    if package_available firefox-esr-l10n-tr; then
        install_one firefox-esr-l10n-tr
    elif package_available firefox-l10n-tr; then
        install_one firefox-l10n-tr
    else
        info "Firefox Türkçe paketi bu depoda yok."
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

    ok "Uygulama dil paketleri kontrol edildi."
}

# ============================================================
# MAN
# ============================================================

install_manpages() {

    printf '\n'
    printf '%b[7] Türkçe man sayfaları...%b\n\n' \
        "$CYAN" "$NC"

    if package_available manpages-tr; then
        install_one manpages-tr
    fi

    if package_available manpages-tr-dev; then
        install_one manpages-tr-dev
    fi

    ok "Man sayfaları kontrol edildi."
}

# ============================================================
# PENTEST ARAÇLARI
# ============================================================

install_pentest_tools() {

    printf '\n'
    printf '%b[8] PENTEST ARAÇLARI KURULUYOR...%b\n' \
        "$MAGENTA" "$NC"

    printf '\n%b=== WEB / RECON ===%b\n' \
        "$MAGENTA" "$NC"

    install_list \
        nmap \
        ncat \
        ndiff \
        nikto \
        sqlmap \
        gobuster \
        dirsearch \
        ffuf \
        feroxbuster \
        nuclei \
        whatweb \
        wafw00f \
        dnsenum \
        dnsrecon \
        fierce \
        amass \
        burpsuite \
        mitmproxy \
        zaproxy

    printf '\n%b=== REVERSE ENGINEERING ===%b\n' \
        "$MAGENTA" "$NC"

    install_list \
        ghex \
        ghidra \
        jadx \
        rizin \
        radare2 \
        rizin-cutter \
        rz-ghidra \
        apktool \
        dex2jar \
        bytecode-viewer \
        jd-gui \
        ropper \
        edb-debugger \
        binwalk \
        yara \
        gdb \
        strace \
        ltrace \
        binutils

    printf '\n%b=== WINDOWS / AD / SMB ===%b\n' \
        "$MAGENTA" "$NC"

    install_list \
        evil-winrm \
        samba \
        smbclient \
        cifs-utils \
        ldap-utils \
        enum4linux \
        enum4linux-ng \
        impacket-scripts \
        netexec \
        responder \
        bloodyad

    printf '\n%b=== STEGANOGRAPHY / FORENSICS ===%b\n' \
        "$MAGENTA" "$NC"

    install_list \
        steghide \
        stegsnow \
        outguess \
        exiftool \
        foremost \
        sleuthkit \
        autopsy \
        testdisk \
        dc3dd \
        scalpel

    printf '\n%b=== NETWORK / TRAFFIC ===%b\n' \
        "$MAGENTA" "$NC"

    install_list \
        wireshark \
        tshark \
        tcpdump \
        netcat-openbsd \
        socat \
        bettercap \
        ettercap-graphical \
        arp-scan \
        traceroute \
        iperf3 \
        masscan

    printf '\n%b=== PASSWORD / HASH ===%b\n' \
        "$MAGENTA" "$NC"

    install_list \
        hashcat \
        john \
        hashid \
        hydra \
        medusa \
        patator \
        crunch \
        seclists \
        wordlists

    printf '\n%b=== WIRELESS ===%b\n' \
        "$MAGENTA" "$NC"

    install_list \
        aircrack-ng \
        reaver \
        bully \
        kismet \
        hcxdumptool \
        hcxpcapngtool \
        wifite \
        rfkill \
        iw

    printf '\n'

    ok "Pentest araçları kurulumu tamamlandı."
}

# ============================================================
# GVM / OPENVAS
# ============================================================

install_gvm() {

    printf '\n'
    printf '%b[9] GVM / OPENVAS...%b\n\n' \
        "$MAGENTA" "$NC"

    if package_available gvm; then

        install_one gvm

    else

        warn "gvm paketi bu depoda bulunamadı."
    fi
}

# ============================================================
# YARDIMCI ARAÇLAR
# ============================================================

install_utilities() {

    printf '\n'
    printf '%b[10] Yardımcı araçlar...%b\n\n' \
        "$CYAN" "$NC"

    install_list \
        gedit \
        plank \
        kazam \
        terminator \
        sonic-visualiser \
        fzf \
        ripgrep \
        tmux \
        btop \
        jq \
        curl \
        wget \
        unzip \
        p7zip-full \
        git \
        gh

    # eza / bat bazı Debian/Kali sürümlerinde olmayabilir
    if package_available eza; then
        install_one eza
    fi

    if package_available bat; then
        install_one bat
    fi

    # Arsenal
    if package_available arsenal; then
        install_one arsenal
    elif package_available arsenal-ng; then
        install_one arsenal-ng
    fi

    # jwt-tool
    if package_available jwt-tool; then

        install_one jwt-tool

    elif package_available jwt-toolkit; then

        install_one jwt-toolkit

    else

        info "jwt-tool APT depolarında yok; atlandı."
    fi

    # Sublime Text için üçüncü taraf depo eklemiyoruz.
    if package_available sublime-text; then

        install_one sublime-text

    else

        info "Sublime Text APT deposunda yok; atlandı."
    fi
}

# ============================================================
# KALI METAPAKETLERİ
# ============================================================
#
# Kali üzerinde bulunuyorsa eksik temel araçları tamamlamak
# için resmi metapaketlerden yararlanılır.
#
# ============================================================

install_kali_meta() {

    [[ "$OS_ID" == "kali" ]] || return 0

    printf '\n'
    printf '%b[11] Kali metapaketleri kontrol ediliyor...%b\n\n' \
        "$MAGENTA" "$NC"

    # Çok büyük "kali-linux-everything" bilinçli olarak
    # kullanılmıyor. Aşağıdaki gruplar daha kontrollü.
    #
    # Mevcutsa kurulur, yoksa atlanır.

    if package_available kali-tools-web; then
        install_one kali-tools-web
    fi

    if package_available kali-tools-reverse-engineering; then
        install_one kali-tools-reverse-engineering
    fi

    if package_available kali-tools-windows-resources; then
        install_one kali-tools-windows-resources
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

    ok "Kali metapaketleri kontrol edildi."
}

# ============================================================
# SON KONTROL
# ============================================================

finalize_system() {

    printf '\n'
    printf '%bSistem son kontrolleri yapılıyor...%b\n' \
        "$CYAN" "$NC"

    dpkg --configure -a >/dev/null 2>&1 || true

    apt-get -f install -y >/dev/null 2>&1 || true

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi

    ok "Son kontroller tamamlandı."
}

# ============================================================
# ÖZET
# ============================================================

show_summary() {

    printf '\n\n'

    printf '%b╔══════════════════════════════════════════════════════════╗%b\n' \
        "$GREEN" "$NC"

    printf '%b║                 KURULUM TAMAMLANDI                     ║%b\n' \
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

    printf '%bPAKET DURUMU%b\n' \
        "$CYAN" "$NC"

    printf '  Kontrol edilen : %s\n' "$TOTAL"
    printf '  Yeni kurulan   : %s\n' "$INSTALLED"
    printf '  Zaten kurulu   : %s\n' "$ALREADY"
    printf '  Depoda yok     : %s\n' "$SKIPPED"
    printf '  Kurulum hatası : %s\n' "$FAILED"

    if [[ -n "$BACKUP_DIR" ]]; then

        printf '\n'
        printf '%bYedek:%b %s\n' \
            "$CYAN" "$NC" "$BACKUP_DIR"
    fi

    printf '\n'

    printf '%bÖNERİLEN:%b Oturumu kapatıp tekrar açın veya sistemi yeniden başlatın.\n' \
        "$YELLOW" "$NC"

    if package_installed gvm; then

        printf '\n'
        printf '%bGVM / OPENVAS İLK KURULUM:%b\n' \
            "$MAGENTA" "$NC"

        printf '  sudo gvm-setup\n'
        printf '  sudo gvm-check-setup\n'
        printf '  sudo gvm-start\n'
    fi

    printf '\n'

    ok "Türkçeleştirme + pentest araçları işlemi bitti."
}

# ============================================================
# TEK SEFERDE HER ŞEY
# ============================================================

install_everything() {

    clear

    printf '%b╔══════════════════════════════════════════════════════════╗%b\n' \
        "$CYAN" "$NC"

    printf '%b║     LINUX TÜRKÇELEŞTİRME + PENTEST KURULUMU           ║%b\n' \
        "$CYAN" "$NC"

    printf '%b║                         v%-25s║%b\n' \
        "$CYAN" "$VERSION" "$NC"

    printf '%b╚══════════════════════════════════════════════════════════╝%b\n' \
        "$CYAN" "$NC"

    # --------------------------------------------------------
    # TEK SORU
    # --------------------------------------------------------

    ask_install

    # --------------------------------------------------------
    # BACKUP
    # --------------------------------------------------------

    printf '\n'
    printf '%bYedekleme...%b\n' "$CYAN" "$NC"

    create_backup

    # --------------------------------------------------------
    # APT
    # --------------------------------------------------------

    if ! apt_update; then

        err "APT güncellenemedi."
        err "Güvenli şekilde kurulum durduruluyor."

        exit 1
    fi

    # --------------------------------------------------------
    # TÜRKÇELEŞTİRME
    # --------------------------------------------------------

    configure_locale

    configure_keyboard

    configure_desktop

    install_fonts

    install_app_languages

    install_manpages

    # --------------------------------------------------------
    # PENTEST
    # --------------------------------------------------------

    install_pentest_tools

    install_gvm

    install_utilities

    install_kali_meta

    # --------------------------------------------------------
    # SON
    # --------------------------------------------------------

    finalize_system

    show_summary
}

# ============================================================
# MAIN
# ============================================================

main() {

    init_log

    check_root

    load_system

    detect_target_user

    detect_desktop

    log "=============================================="
    log "Linux Türkçeleştirme + Pentest başlatıldı"
    log "Version: $VERSION"
    log "OS: $OS_NAME"
    log "OS_ID: $OS_ID"
    log "User: $TARGET_USER"
    log "Desktop: $DESKTOP"
    log "=============================================="

    install_everything
}

main "$@"
