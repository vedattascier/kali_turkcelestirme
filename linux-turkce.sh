```bash
#!/usr/bin/env bash

# ============================================================
# LINUX TÜRKÇELEŞTİRME + PENTEST KURULUM ARACI
# v2026.9
#
# DESTEK:
#   Kali Linux
#   Debian
#   Ubuntu
#   Debian/Ubuntu tabanlı sistemler
#
# KURULUM AKIŞI:
#
#   1) APT kaynaklarını kontrol et
#   2) APT update
#   3) "Linux Türkçe yapılsın mı?"
#   4) "Pentest araçları kurulsun mu?"
#   5) Seçilenleri otomatik kur
#   6) Son kontrol
#   7) Özet
#
# ÇALIŞTIRMA:
#
#   sudo bash linux-turkce.sh
#
# GITHUB:
#
#   curl -fsSL https://raw.githubusercontent.com/vedattascier/kali_turkcelestirme/main/linux-turkce.sh | sudo bash
#
# ============================================================

set -u
set -o pipefail

VERSION="2026.9"
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

TOTAL_REQUESTED=0
TOTAL_AVAILABLE=0
TOTAL_INSTALLED=0
TOTAL_ALREADY=0
TOTAL_MISSING=0
TOTAL_FAILED=0

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
# SİSTEM
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
        error_msg "Debian/Kali/Ubuntu tabanlı bir sistem gereklidir."
        exit 1
    fi
}

# ============================================================
# KULLANICI
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
# TTY INPUT
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

        case "${answer,,}" in

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
# KALI APT KAYNAĞI
# ============================================================
#
# Kali 2026.2 ile modern kaynak dosyası:
#
# /etc/apt/sources.list.d/kali.sources
#
# Resmi içerik:
#
# Types: deb
# URIs: http://http.kali.org/kali/
# Suites: kali-rolling
# Components: main contrib non-free non-free-firmware
# Signed-By: /usr/share/keyrings/kali-archive-keyring.gpg
#
# ============================================================

ensure_kali_sources() {

    [[ "$OS_ID" == "kali" ]] || return 0

    local source_file="/etc/apt/sources.list.d/kali.sources"
    local keyring="/usr/share/keyrings/kali-archive-keyring.gpg"

    mkdir -p /etc/apt/sources.list.d

    # Önceden çalışan Kali kaynağı var mı?
    if [[ -f "$source_file" ]] &&
       grep -Eq '^[[:space:]]*Types:[[:space:]]*deb' "$source_file" &&
       grep -Eq '^[[:space:]]*URIs:[[:space:]]*https?://http\.kali\.org/kali/?' "$source_file" &&
       grep -Eq '^[[:space:]]*Suites:[[:space:]]*kali-' "$source_file"; then

        success "Kali APT kaynağı zaten yapılandırılmış."
        return 0
    fi

    # Eski sources.list kullanılabiliyorsa dönüştürmeye dokunma.
    if [[ -f /etc/apt/sources.list ]] &&
       grep -Eq '^[[:space:]]*deb[[:space:]]+https?://http\.kali\.org/kali[[:space:]]+kali-' \
           /etc/apt/sources.list 2>/dev/null; then

        info "Eski Kali sources.list bulundu."

        if command -v apt-modernize-sources >/dev/null 2>&1; then
            apt-modernize-sources >/dev/null 2>&1 || true
        elif command -v apt >/dev/null 2>&1 &&
             apt modernize-sources --help >/dev/null 2>&1; then
            apt modernize-sources >/dev/null 2>&1 || true
        fi

        if [[ -f "$source_file" ]]; then
            success "Kali APT kaynağı modern biçime taşındı."
            return 0
        fi
    fi

    # Hiçbir Kali network kaynağı yoksa resmi kaynağı oluştur.
    if [[ ! -f "$keyring" ]]; then

        error_msg "Kali archive keyring bulunamadı:"
        error_msg "$keyring"

        warning "Kali kurulumunuz eksik veya bozuk olabilir."

        return 1
    fi

    local backup="/root/kali-apt-backup-$(date '+%Y%m%d_%H%M%S')"

    mkdir -p "$backup" 2>/dev/null || true

    if [[ -f "$source_file" ]]; then
        cp -a "$source_file" "$backup/" 2>/dev/null || true
    fi

    if [[ -f /etc/apt/sources.list ]]; then
        cp -a /etc/apt/sources.list "$backup/" 2>/dev/null || true
    fi

    cat > "$source_file" <<'EOF'
# Kali Linux network repository
# https://www.kali.org/docs/general-use/kali-apt-sources/

Types: deb
URIs: http://http.kali.org/kali/
Suites: kali-rolling
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/kali-archive-keyring.gpg
EOF

    chmod 644 "$source_file"

    success "Kali APT kaynağı oluşturuldu."

    if [[ -n "$backup" ]]; then
        info "APT yedeği: $backup"
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

            return 1
        fi

        printf '\r%bAPT kilidi bekleniyor... %2ds%b' \
            "$YELLOW" "$waited" "$NC"

        sleep 1
        ((waited++))
    done
}

# ============================================================
# DPKG ONAR
# ============================================================

repair_dpkg() {

    info "dpkg durumu kontrol ediliyor..."

    if dpkg --audit >/dev/null 2>&1; then
        :
    fi

    if dpkg --configure -a; then

        success "dpkg yapılandırması tamam."

    else

        warning "dpkg --configure -a hata verdi."

        if apt-get -f install -y; then

            success "Bağımlılık sorunları düzeltildi."

        else

            error_msg "dpkg/apt onarılamadı."
            return 1
        fi
    fi

    return 0
}

# ============================================================
# APT UPDATE
# ============================================================

apt_update() {

    printf '\n'
    printf '%b============================================%b\n' \
        "$CYAN" "$NC"

    printf '%bAPT PAKET LİSTELERİ GÜNCELLENİYOR%b\n' \
        "$CYAN" "$NC"

    printf '%b============================================%b\n\n' \
        "$CYAN" "$NC"

    ensure_kali_sources || exit 1

    if ! wait_for_apt_lock; then
        exit 1
    fi

    if ! repair_dpkg; then
        exit 1
    fi

    if apt-get update; then

        success "APT paket listeleri güncel."

    else

        error_msg "apt-get update başarısız."

        if [[ "$OS_ID" == "kali" ]]; then

            printf '\n'
            warning "Kali APT kaynağını kontrol edin:"
            printf '  cat /etc/apt/sources.list.d/kali.sources\n'
            printf '\n'
        fi

        exit 1
    fi
}

# ============================================================
# PAKET TESTİ
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
# PAKET LİSTESİ HAZIRLA
# ============================================================

build_package_list() {

    REQUESTED_PACKAGES=()

    # --------------------------------------------------------
    # TÜRKÇELEŞTİRME
    # --------------------------------------------------------

    if [[ "$DO_TURKISH" -eq 1 ]]; then

        REQUESTED_PACKAGES+=(
            locales
            keyboard-configuration
            console-setup
            fonts-dejavu
            fonts-liberation
            fonts-noto-core
            fonts-noto-cjk
            fonts-noto-mono
        )

        if package_available firefox-esr-l10n-tr; then
            REQUESTED_PACKAGES+=(firefox-esr-l10n-tr)
        elif package_available firefox-l10n-tr; then
            REQUESTED_PACKAGES+=(firefox-l10n-tr)
        fi

        if package_available chromium-l10n; then
            REQUESTED_PACKAGES+=(chromium-l10n)
        fi

        if package_available libreoffice-l10n-tr; then
            REQUESTED_PACKAGES+=(libreoffice-l10n-tr)
        fi

        if package_available manpages-tr; then
            REQUESTED_PACKAGES+=(manpages-tr)
        fi

        if package_available manpages-tr-dev; then
            REQUESTED_PACKAGES+=(manpages-tr-dev)
        fi
    fi

    # --------------------------------------------------------
    # PENTEST
    # --------------------------------------------------------

    if [[ "$DO_PENTEST" -eq 1 ]]; then

        # WEB / RECON
        REQUESTED_PACKAGES+=(
            nmap
            ncat
            ndiff
            nikto
            sqlmap
            gobuster
            dirsearch
            ffuf
            feroxbuster
            nuclei
            whatweb
            wafw00f
            dnsenum
            dnsrecon
            fierce
            amass
            burpsuite
            mitmproxy
            zaproxy
        )

        # REVERSE ENGINEERING
        REQUESTED_PACKAGES+=(
            ghex
            ghidra
            jadx
            rizin
            radare2
            rizin-cutter
            rz-ghidra
            apktool
            dex2jar
            bytecode-viewer
            jd-gui
            ropper
            edb-debugger
            binwalk
            yara
            gdb
            strace
            ltrace
            binutils
        )

        # WINDOWS / AD / SMB
        REQUESTED_PACKAGES+=(
            evil-winrm
            samba
            smbclient
            cifs-utils
            ldap-utils
            enum4linux
            enum4linux-ng
            impacket-scripts
            netexec
            responder
            bloodyad
        )

        # STEGO / FORENSICS
        REQUESTED_PACKAGES+=(
            steghide
            stegsnow
            outguess
            exiftool
            foremost
            sleuthkit
            autopsy
            testdisk
            dc3dd
            scalpel
        )

        # NETWORK
        REQUESTED_PACKAGES+=(
            wireshark
            tshark
            tcpdump
            netcat-openbsd
            socat
            bettercap
            ettercap-graphical
            arp-scan
            traceroute
            iperf3
            masscan
        )

        # PASSWORD / HASH
        REQUESTED_PACKAGES+=(
            hashcat
            john
            hashid
            hydra
            medusa
            patator
            crunch
            seclists
            wordlists
        )

        # WIRELESS
        REQUESTED_PACKAGES+=(
            aircrack-ng
            reaver
            bully
            kismet
            hcxdumptool
            hcxpcapngtool
            wifite
            rfkill
            iw
        )

        # VULNERABILITY / GVM
        REQUESTED_PACKAGES+=(
            gvm
        )

        # YARDIMCI ARAÇLAR
        REQUESTED_PACKAGES+=(
            gedit
            plank
            terminator
            kazam
            sonic-visualiser
            fzf
            ripgrep
            tmux
            btop
            jq
            curl
            wget
            unzip
            p7zip-full
            git
            gh
        )

        # İsteğe bağlı mevcutsa:
        if package_available eza; then
            REQUESTED_PACKAGES+=(eza)
        fi

        if package_available bat; then
            REQUESTED_PACKAGES+=(bat)
        fi

        # Arsenal'in güncel Kali paket adı
        if package_available arsenal-ng; then
            REQUESTED_PACKAGES+=(arsenal-ng)
        fi

        # Kali Linux metapaketleri
        if [[ "$OS_ID" == "kali" ]]; then

            if package_available kali-tools-top10; then
                REQUESTED_PACKAGES+=(kali-tools-top10)
            fi

            if package_available kali-tools-reverse-engineering; then
                REQUESTED_PACKAGES+=(kali-tools-reverse-engineering)
            fi

            if package_available kali-tools-forensics; then
                REQUESTED_PACKAGES+=(kali-tools-forensics)
            fi

            if package_available kali-tools-vulnerability; then
                REQUESTED_PACKAGES+=(kali-tools-vulnerability)
            fi

            if package_available kali-tools-crypto-stego; then
                REQUESTED_PACKAGES+=(kali-tools-crypto-stego)
            fi

            if package_available kali-tools-802-11; then
                REQUESTED_PACKAGES+=(kali-tools-802-11)
            fi
        fi
    fi
}

# ============================================================
# DUPLICATE TEMİZLEME
# ============================================================

deduplicate_packages() {

    local package
    local -A seen=()

    UNIQUE_PACKAGES=()

    for package in "${REQUESTED_PACKAGES[@]}"; do

        [[ -n "$package" ]] || continue

        if [[ -z "${seen[$package]+x}" ]]; then

            seen["$package"]=1
            UNIQUE_PACKAGES+=("$package")
        fi
    done
}

# ============================================================
# TOPLU PAKET KURULUMU
# ============================================================

install_selected_packages() {

    deduplicate_packages

    TOTAL_REQUESTED="${#UNIQUE_PACKAGES[@]}"

    local package

    AVAILABLE_PACKAGES=()

    printf '\n'
    printf '%bPaketler kontrol ediliyor...%b\n\n' \
        "$CYAN" "$NC"

    for package in "${UNIQUE_PACKAGES[@]}"; do

        if package_installed "$package"; then

            ((TOTAL_ALREADY++))

            printf '%b[VAR]%b %s\n' \
                "$GREEN" "$NC" "$package"

        elif package_available "$package"; then

            AVAILABLE_PACKAGES+=("$package")

            ((TOTAL_AVAILABLE++))

            printf '%b[HAZIR]%b %s\n' \
                "$CYAN" "$NC" "$package"

        else

            ((TOTAL_MISSING++))

            printf '%b[YOK]%b %s\n' \
                "$YELLOW" "$NC" "$package"
        fi
    done

    if [[ "${#AVAILABLE_PACKAGES[@]}" -eq 0 ]]; then

        success "Yeni kurulacak paket bulunmadı."
        return 0
    fi

    printf '\n'
    printf '%b%s yeni paket kurulacak.%b\n\n' \
        "$CYAN" "${#AVAILABLE_PACKAGES[@]}" "$NC"

    if ! wait_for_apt_lock; then
        return 1
    fi

    if DEBIAN_FRONTEND=noninteractive \
        apt-get install -y \
        --no-install-recommends \
        "${AVAILABLE_PACKAGES[@]}"; then

        TOTAL_INSTALLED="${#AVAILABLE_PACKAGES[@]}"

        success "Paket kurulumu tamamlandı."

    else

        warning "Toplu paket kurulumu tamamen başarılı olmadı."
        warning "Kurulamayan paketler tek tek kontrol ediliyor."

        # İkinci aşamada paketleri tek tek deneyerek
        # gerçek başarısızları ayır.
        TOTAL_INSTALLED=0

        for package in "${AVAILABLE_PACKAGES[@]}"; do

            if package_installed "$package"; then

                ((TOTAL_INSTALLED++))

                continue
            fi

            if DEBIAN_FRONTEND=noninteractive \
                apt-get install -y \
                --no-install-recommends \
                "$package" >/dev/null 2>&1; then

                ((TOTAL_INSTALLED++))

            else

                ((TOTAL_FAILED++))

                warning "Kurulamadı: $package"
            fi
        done
    fi
}

# ============================================================
# TÜRKÇE AYARLARI
# ============================================================

apply_turkish_configuration() {

    [[ "$DO_TURKISH" -eq 1 ]] || return 0

    printf '\n'
    printf '%b===== TÜRKÇELEŞTİRME =====%b\n\n' \
        "$CYAN" "$NC"

    create_turkish_backup

    # --------------------------------------------------------
    # LOCALE
    # --------------------------------------------------------

    if [[ -f /etc/locale.gen ]]; then

        sed -i \
            -E \
            '/^[[:space:]#]*tr_TR\.UTF-8[[:space:]]+UTF-8[[:space:]]*$/d' \
            /etc/locale.gen \
            2>/dev/null || true

        printf '%s\n' \
            'tr_TR.UTF-8 UTF-8' >> /etc/locale.gen

    fi

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
# Linux Turkish locale configuration
export LANG=tr_TR.UTF-8
export LANGUAGE=tr_TR:tr
EOF

    chmod 644 /etc/profile.d/turkish-locale.sh

    # --------------------------------------------------------
    # KLAVYE
    # --------------------------------------------------------

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

    # --------------------------------------------------------
    # FONT
    # --------------------------------------------------------

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi

    success "Türkçe locale, klavye ve font ayarları uygulandı."
}

# ============================================================
# YEDEK
# ============================================================

create_turkish_backup() {

    local timestamp

    timestamp="$(date '+%Y%m%d_%H%M%S')"

    BACKUP_DIR="/root/linux-turkce-backup-$timestamp"

    if ! mkdir -p "$BACKUP_DIR"; then

        warning "Türkçe ayar yedeği oluşturulamadı."
        return 1
    fi

    local file

    for file in \
        /etc/locale.gen \
        /etc/default/locale \
        /etc/default/keyboard \
        /etc/hostname \
        /etc/hosts; do

        if [[ -f "$file" ]]; then

            cp -a "$file" "$BACKUP_DIR/" \
                2>/dev/null || true
        fi
    done

    success "Yedek: $BACKUP_DIR"
}

# ============================================================
# GNOME
# ============================================================

apply_gnome() {

    [[ "${DESKTOP,,}" == *gnome* ]] || return 0

    command -v gsettings >/dev/null 2>&1 ||
        return 0

    [[ "$TARGET_USER" != "root" ]] ||
        return 0

    local uid

    uid="$(id -u "$TARGET_USER" 2>/dev/null || printf '0')"

    [[ -S "/run/user/$uid/bus" ]] ||
        return 0

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
}

# ============================================================
# KDE
# ============================================================

apply_kde() {

    [[ "${DESKTOP,,}" == *kde* ||
       "${DESKTOP,,}" == *plasma* ]] ||
        return 0

    if package_available kde-l10n-tr; then

        # Normalde build list içinde zaten kontrol edilmiş
        install_one_extra kde-l10n-tr
    fi
}

# ============================================================
# EK PAKET
# ============================================================

install_one_extra() {

    local package="$1"

    package_installed "$package" &&
        return 0

    package_available "$package" ||
        return 0

    apt-get install -y \
        --no-install-recommends \
        "$package" >/dev/null 2>&1 || true
}

# ============================================================
# TÜRKÇE AYAR SONRASI
# ============================================================

finish_turkish_configuration() {

    [[ "$DO_TURKISH" -eq 1 ]] || return 0

    apply_gnome
    apply_kde

    success "Türkçe yapılandırma tamamlandı."
}

# ============================================================
# GVM BİLGİSİ
# ============================================================

show_gvm_info() {

    [[ "$DO_PENTEST" -eq 1 ]] || return 0

    if ! package_installed gvm; then
        return 0
    fi

    printf '\n'
    printf '%bGVM / OPENVAS KURULDU%b\n\n' \
        "$MAGENTA" "$NC"

    printf 'İlk kurulum:\n'
    printf '  sudo gvm-setup\n\n'

    printf 'Kontrol:\n'
    printf '  sudo gvm-check-setup\n\n'

    printf 'Başlatma:\n'
    printf '  sudo gvm-start\n'
}

# ============================================================
# SON KONTROL
# ============================================================

final_system_check() {

    printf '\n'
    printf '%bSon sistem kontrolleri...%b\n' \
        "$CYAN" "$NC"

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

    printf '\n'
    printf '%b====================================================%b\n' \
        "$GREEN" "$NC"

    printf '%b                 KURULUM TAMAMLANDI%b\n' \
        "$GREEN" "$NC"

    printf '%b====================================================%b\n' \
        "$GREEN" "$NC"

    printf '\n'

    printf '%bSistem:%b %s\n' \
        "$WHITE" "$NC" "$OS_NAME"

    printf '%bKullanıcı:%b %s\n' \
        "$WHITE" "$NC" "$TARGET_USER"

    printf '%bMasaüstü:%b %s\n' \
        "$WHITE" "$NC" "$DESKTOP"

    printf '\n'

    printf '%bTürkçeleştirme:%b %s\n' \
        "$WHITE" "$NC" \
        "$(
            if [[ "$DO_TURKISH" -eq 1 ]]; then
                printf 'EVET'
            else
                printf 'HAYIR'
            fi
        )"

    printf '%bPentest:%b %s\n' \
        "$WHITE" "$NC" \
        "$(
            if [[ "$DO_PENTEST" -eq 1 ]]; then
                printf 'EVET'
            else
                printf 'HAYIR'
            fi
        )"

    printf '\n'

    printf '%bPAKET ÖZETİ%b\n' \
        "$CYAN" "$NC"

    printf '  Kontrol edilen : %s\n' "$TOTAL_REQUESTED"
    printf '  Yeni kurulan   : %s\n' "$TOTAL_INSTALLED"
    printf '  Zaten kurulu   : %s\n' "$TOTAL_ALREADY"
    printf '  Depoda yok     : %s\n' "$TOTAL_MISSING"
    printf '  Kurulum hatası : %s\n' "$TOTAL_FAILED"

    if [[ -n "$BACKUP_DIR" ]]; then

        printf '\n'
        printf '%bYedek:%b %s\n' \
            "$CYAN" "$NC" "$BACKUP_DIR"
    fi

    show_gvm_info

    printf '\n'

    warning "Dil ve masaüstü değişikliklerinin tamamı için yeniden başlatma önerilir."

    printf '\n'

    success "Script başarıyla tamamlandı."
}

# ============================================================
# ANA
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

    printf '%bLinux Türkçeleştirme + Pentest Kurulum Aracı v%s%b\n\n' \
        "$CYAN" "$VERSION" "$NC"

    printf '%bSistem:%b %s\n' \
        "$WHITE" "$NC" "$OS_NAME"

    printf '%bMasaüstü:%b %s\n' \
        "$WHITE" "$NC" "$DESKTOP"

    printf '\n'

    if ask_yes_no "Linux Türkçe yapılsın mı?"; then
        DO_TURKISH=1
    fi

    if ask_yes_no "Pentest araçları kurulsun mu?"; then
        DO_PENTEST=1
    fi

    if [[ "$DO_TURKISH" -eq 0 &&
          "$DO_PENTEST" -eq 0 ]]; then

        info "Hiçbir kurulum seçilmedi."
        exit 0
    fi

    # --------------------------------------------------------
    # APT
    # --------------------------------------------------------

    apt_update

    # --------------------------------------------------------
    # PAKETLER
    # --------------------------------------------------------

    build_package_list

    install_selected_packages

    # --------------------------------------------------------
    # TÜRKÇE AYARLARI
    # --------------------------------------------------------

    if [[ "$DO_TURKISH" -eq 1 ]]; then

        apply_turkish_configuration
        finish_turkish_configuration
    fi

    # --------------------------------------------------------
    # SON
    # --------------------------------------------------------

    final_system_check

    show_summary
}

main "$@"
```


