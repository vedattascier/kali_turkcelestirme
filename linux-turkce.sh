
#!/usr/bin/env bash

set -u
set -o pipefail

VERSION="2026.10"
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
# GLOBAL
# ============================================================

OS_NAME="Bilinmiyor"
OS_ID="unknown"
OS_VERSION="unknown"
OS_LIKE=""

TARGET_USER="root"
TARGET_HOME="/root"
DESKTOP="Bilinmiyor"

DO_TURKISH=0
DO_PENTEST=0

BACKUP_DIR=""

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
        printf '  sudo bash linux-turkce.sh\n'
        printf '\n'
        exit 1
    fi
}

# ============================================================
# SİSTEM BİLGİSİ
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

ensure_kali_sources() {

    [[ "$OS_ID" == "kali" ]] || return 0

    local source_file="/etc/apt/sources.list.d/kali.sources"
    local keyring="/usr/share/keyrings/kali-archive-keyring.gpg"

    mkdir -p /etc/apt/sources.list.d

    # --------------------------------------------------------
    # Modern kali.sources zaten doğruysa hiçbir şeyi değiştirme
    # --------------------------------------------------------

    if [[ -f "$source_file" ]] &&
       grep -Eq '^[[:space:]]*Types:[[:space:]]*deb([[:space:]]|$)' "$source_file" &&
       grep -Eq '^[[:space:]]*URIs:[[:space:]]*https?://http\.kali\.org/kali/?' "$source_file" &&
       grep -Eq '^[[:space:]]*Suites:[[:space:]]*kali-' "$source_file"; then

        success "Kali APT kaynağı hazır."
        return 0
    fi

    # --------------------------------------------------------
    # Eski sources.list varsa önce modernize etmeyi dene
    # --------------------------------------------------------

    if [[ -f /etc/apt/sources.list ]] &&
       grep -Eq '^[[:space:]]*deb[[:space:]]+https?://http\.kali\.org/kali[[:space:]]+kali-' \
       /etc/apt/sources.list 2>/dev/null; then

        if command -v apt-modernize-sources >/dev/null 2>&1; then

            apt-modernize-sources >/dev/null 2>&1 || true

        elif apt modernize-sources --help >/dev/null 2>&1; then

            apt modernize-sources >/dev/null 2>&1 || true
        fi

        if [[ -f "$source_file" ]]; then

            success "Kali APT kaynağı modernize edildi."
            return 0
        fi
    fi

    # --------------------------------------------------------
    # Keyring kontrolü
    # --------------------------------------------------------

    if [[ ! -f "$keyring" ]]; then

        error_msg "Kali archive keyring bulunamadı:"
        error_msg "$keyring"
        error_msg "Kali kurulumunuz eksik olabilir."

        return 1
    fi

    # --------------------------------------------------------
    # Eski dosyaların yedeği
    # --------------------------------------------------------

    local backup_dir
    backup_dir="/root/kali-apt-backup-$(date '+%Y%m%d_%H%M%S')"

    mkdir -p "$backup_dir" 2>/dev/null || true

    if [[ -f "$source_file" ]]; then
        cp -a "$source_file" "$backup_dir/" 2>/dev/null || true
    fi

    if [[ -f /etc/apt/sources.list ]]; then
        cp -a /etc/apt/sources.list "$backup_dir/" 2>/dev/null || true
    fi

    # --------------------------------------------------------
    # Resmi Kali kaynağı
    # --------------------------------------------------------

    cat > "$source_file" <<'EOF'
# Kali Linux official network repository
# https://www.kali.org/docs/general-use/kali-apt-sources/

Types: deb
URIs: http://http.kali.org/kali/
Suites: kali-rolling
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/kali-archive-keyring.gpg
EOF

    chmod 644 "$source_file"

    success "Kali APT kaynağı oluşturuldu."
}

# ============================================================
# APT KİLİT
# ============================================================

wait_for_apt_lock() {

    local waited=0
    local max_wait=120

    while true; do

        if ! fuser \
            /var/lib/dpkg/lock-frontend \
            /var/lib/dpkg/lock \
            /var/lib/apt/lists/lock \
            >/dev/null 2>&1; then

            return 0
        fi

        if (( waited >= max_wait )); then

            error_msg "APT kilidi $max_wait saniye içinde açılmadı."
            return 1
        fi

        printf '\r%bAPT başka bir işlem tarafından kullanılıyor... %3ds%b' \
            "$YELLOW" "$waited" "$NC"

        sleep 1
        ((waited++))
    done
}

# ============================================================
# BOZUK DPKG KONTROLÜ
# ============================================================

repair_dpkg() {

    info "Paket yöneticisi kontrol ediliyor..."

    if dpkg --configure -a >/dev/null 2>&1; then

        success "dpkg hazır."
        return 0
    fi

    warning "dpkg içinde yarım kalmış paket yapılandırması bulundu."

    # --------------------------------------------------------
    # Özellikle bozuk rkhunter yapılandırmasını kontrol et.
    # rkhunter'ın postinst hatası nedeniyle bütün dpkg zinciri
    # kilitlenebiliyor.
    # --------------------------------------------------------

    if dpkg-query -W -f='${Status}\n' rkhunter 2>/dev/null |
       grep -Eq '^(install ok half-configured|install reinstreq half-configured|deinstall ok half-configured)$'; then

        warning "Bozuk rkhunter yapılandırması algılandı."

        if dpkg --remove --force-remove-reinstreq rkhunter \
            >/dev/null 2>&1; then

            success "Bozuk rkhunter paketi kaldırıldı."

        else

            warning "rkhunter doğrudan kaldırılamadı."
        fi
    fi

    # --------------------------------------------------------
    # Genel bağımlılık onarımı
    # --------------------------------------------------------

    if dpkg --configure -a; then

        success "dpkg düzeltildi."
        return 0
    fi

    if apt-get -f install -y; then

        if dpkg --configure -a; then

            success "Paket yöneticisi düzeltildi."
            return 0
        fi
    fi

    error_msg "dpkg onarılamadı."
    return 1
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

    ensure_kali_sources || return 1

    wait_for_apt_lock || return 1

    repair_dpkg || return 1

    if apt-get update; then

        success "APT paket listeleri güncellendi."
        return 0

    fi

    error_msg "apt-get update başarısız oldu."

    if [[ "$OS_ID" == "kali" ]]; then

        printf '\n'
        warning "Kali APT kaynağı:"
        printf '  /etc/apt/sources.list.d/kali.sources\n'
        printf '\n'
    fi

    return 1
}

# ============================================================
# PAKET KONTROLÜ
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
# PAKET LİSTESİ
# ============================================================

build_package_list() {

    REQUESTED_PACKAGES=()

    # ========================================================
    # TÜRKÇELEŞTİRME
    # ========================================================

    if [[ "$DO_TURKISH" -eq 1 ]]; then

        REQUESTED_PACKAGES+=(
            locales
            keyboard-configuration
            console-setup
            console-setup-linux

            fonts-dejavu
            fonts-liberation
            fonts-noto-core
            fonts-noto-mono
            fonts-noto-cjk

            firefox-esr-l10n-tr
            firefox-l10n-tr
            chromium-l10n
            libreoffice-l10n-tr

            manpages-tr
            manpages-tr-dev
        )
    fi

    # ========================================================
    # PENTEST
    # ========================================================

    if [[ "$DO_PENTEST" -eq 1 ]]; then

        # ----------------------------------------------------
        # WEB / RECON
        # ----------------------------------------------------

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

        # ----------------------------------------------------
        # REVERSE ENGINEERING
        # ----------------------------------------------------

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

        # ----------------------------------------------------
        # WINDOWS / AD / SMB
        # ----------------------------------------------------

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

        # ----------------------------------------------------
        # STEGANOGRAPHY / FORENSICS
        #
        # rkhunter burada özellikle YOK.
        # kali-tools-forensics metapackage de kullanılmıyor.
        # ----------------------------------------------------

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

        # ----------------------------------------------------
        # NETWORK / TRAFFIC
        # ----------------------------------------------------

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

        # ----------------------------------------------------
        # PASSWORD / HASH
        # ----------------------------------------------------

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

        # ----------------------------------------------------
        # WIRELESS
        # ----------------------------------------------------

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

        # ----------------------------------------------------
        # GVM / OPENVAS
        # ----------------------------------------------------

        REQUESTED_PACKAGES+=(
            gvm
        )

        # ----------------------------------------------------
        # YARDIMCI ARAÇLAR
        # ----------------------------------------------------

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
# PAKETLERİ TOPLU KUR
# ============================================================

install_selected_packages() {

    deduplicate_packages

    TOTAL_REQUESTED="${#UNIQUE_PACKAGES[@]}"

    AVAILABLE_PACKAGES=()

    printf '\n'
    printf '%bPaketler kontrol ediliyor...%b\n\n' \
        "$CYAN" "$NC"

    local package

    for package in "${UNIQUE_PACKAGES[@]}"; do

        if package_installed "$package"; then

            ((TOTAL_ALREADY++))

            printf '%b[VAR]%b       %s\n' \
                "$GREEN" "$NC" "$package"

            continue
        fi

        if package_available "$package"; then

            AVAILABLE_PACKAGES+=("$package")

            ((TOTAL_AVAILABLE++))

            printf '%b[HAZIR]%b     %s\n' \
                "$CYAN" "$NC" "$package"

        else

            ((TOTAL_MISSING++))

            printf '%b[YOK]%b       %s\n' \
                "$YELLOW" "$NC" "$package"
        fi
    done

    if [[ "${#AVAILABLE_PACKAGES[@]}" -eq 0 ]]; then

        success "Yeni kurulacak paket bulunamadı."
        return 0
    fi

    printf '\n'
    info "${#AVAILABLE_PACKAGES[@]} paket kurulacak."

    wait_for_apt_lock || return 1

    printf '\n'

    # --------------------------------------------------------
    # Önce toplu kurulum
    # --------------------------------------------------------

    if DEBIAN_FRONTEND=noninteractive \
        apt-get install -y \
        --no-install-recommends \
        "${AVAILABLE_PACKAGES[@]}"; then

        TOTAL_INSTALLED="${#AVAILABLE_PACKAGES[@]}"

        success "Toplu paket kurulumu tamamlandı."
        return 0
    fi

    # --------------------------------------------------------
    # Toplu kurulum bazı paketler yüzünden başarısızsa,
    # paketleri tek tek deneyerek geri kalanları kurtar.
    # --------------------------------------------------------

    warning "Toplu kurulum tamamen başarılı olmadı."
    warning "Paketler tek tek deneniyor."

    local installed_now=0

    for package in "${AVAILABLE_PACKAGES[@]}"; do

        if package_installed "$package"; then

            ((installed_now++))
            continue
        fi

        printf '%b[%s]%b %s\n' \
            "$CYAN" "DENENİYOR" "$NC" "$package"

        if DEBIAN_FRONTEND=noninteractive \
            apt-get install -y \
            --no-install-recommends \
            "$package" >/dev/null 2>&1; then

            ((installed_now++))

        else

            ((TOTAL_FAILED++))

            warning "Kurulamadı: $package"
        fi
    done

    TOTAL_INSTALLED="$installed_now"
}

# ============================================================
# TÜRKÇE KONFİGÜRASYONU
# ============================================================

configure_turkish() {

    [[ "$DO_TURKISH" -eq 1 ]] || return 0

    printf '\n'
    printf '%b============================================%b\n' \
        "$CYAN" "$NC"

    printf '%bTÜRKÇELEŞTİRME UYGULANIYOR%b\n' \
        "$CYAN" "$NC"

    printf '%b============================================%b\n\n' \
        "$CYAN" "$NC"

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

        setxkbmap tr >/dev/null 2>&1 || true
    fi

    # --------------------------------------------------------
    # FONT CACHE
    # --------------------------------------------------------

    if command -v fc-cache >/dev/null 2>&1; then

        fc-cache -f >/dev/null 2>&1 || true
    fi

    # --------------------------------------------------------
    # GNOME
    # --------------------------------------------------------

    if [[ "${DESKTOP,,}" == *gnome* ]] &&
       [[ "$TARGET_USER" != "root" ]] &&
       command -v gsettings >/dev/null 2>&1; then

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

    success "Türkçe locale ve klavye ayarları uygulandı."

    warning "Tam uygulanması için oturumu kapatıp açmanız önerilir."
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

    success "Sistem ayarları yedeklendi: $BACKUP_DIR"
}

# ============================================================
# KURULUM ÖZETİ
# ============================================================

show_summary() {

    printf '\n'
    printf '%b====================================================%b\n' \
        "$GREEN" "$NC"

    printf '%b              KURULUM TAMAMLANDI%b\n' \
        "$GREEN" "$NC"

    printf '%b====================================================%b\n' \
        "$GREEN" "$NC"

    printf '\n'

    printf 'Sistem       : %s\n' "$OS_NAME"
    printf 'Masaüstü     : %s\n' "$DESKTOP"
    printf 'Kullanıcı    : %s\n' "$TARGET_USER"

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

    printf '%bPAKETLER%b\n' \
        "$CYAN" "$NC"

    printf '  Kontrol edilen : %s\n' "$TOTAL_REQUESTED"
    printf '  Yeni kurulan   : %s\n' "$TOTAL_INSTALLED"
    printf '  Zaten kurulu   : %s\n' "$TOTAL_ALREADY"
    printf '  Depoda yok     : %s\n' "$TOTAL_MISSING"
    printf '  Kurulum hatası : %s\n' "$TOTAL_FAILED"

    if [[ -n "$BACKUP_DIR" ]]; then

        printf '\n'
        printf 'Yedek          : %s\n' "$BACKUP_DIR"
    fi

    if package_installed gvm; then

        printf '\n'
        printf '%bGVM / OPENVAS KURULU%b\n' \
            "$MAGENTA" "$NC"

        printf '\n'
        printf 'İlk yapılandırma:\n'
        printf '  sudo gvm-setup\n'
        printf '\n'
        printf 'Kontrol:\n'
        printf '  sudo gvm-check-setup\n'
        printf '\n'
        printf 'Başlatma:\n'
        printf '  sudo gvm-start\n'
    fi

    printf '\n'

    warning "Değişikliklerin tamamen uygulanması için:"
    printf '  sudo reboot\n'

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

    printf '\n'
    printf '%bLinux Türkçeleştirme + Pentest Kurulum Aracı%b\n' \
        "$CYAN" "$NC"
    printf '%bSürüm: %s%b\n\n' \
        "$GRAY" "$VERSION" "$NC"

    printf 'Sistem   : %s\n' "$OS_NAME"
    printf 'Masaüstü : %s\n' "$DESKTOP"
    printf 'Kullanıcı: %s\n' "$TARGET_USER"

    printf '\n'

    # ========================================================
    # SADECE 2 SORU
    # ========================================================

    if ask_yes_no "Linux Türkçe yapılsın mı?"; then
        DO_TURKISH=1
    else
        DO_TURKISH=0
    fi

    if ask_yes_no "Pentest araçları kurulsun mu?"; then
        DO_PENTEST=1
    else
        DO_PENTEST=0
    fi

    if [[ "$DO_TURKISH" -eq 0 &&
          "$DO_PENTEST" -eq 0 ]]; then

        info "Hiçbir işlem seçilmedi."
        exit 0
    fi

    # ========================================================
    # APT
    # ========================================================

    if ! apt_update; then

        error_msg "APT hazırlanamadığı için kurulum durduruldu."
        exit 1
    fi

    # ========================================================
    # YEDEK
    # ========================================================

    if [[ "$DO_TURKISH" -eq 1 ]]; then
        create_backup
    fi

    # ========================================================
    # PAKET LİSTESİ
    # ========================================================

    build_package_list

    # ========================================================
    # PAKET KURULUMU
    # ========================================================

    install_selected_packages

    # ========================================================
    # TÜRKÇELEŞTİRME
    # ========================================================

    configure_turkish

    # ========================================================
    # SON KONTROL
    # ========================================================

    final_system_check() {

        printf '\n'
        info "Son sistem kontrolleri yapılıyor..."

        dpkg --configure -a >/dev/null 2>&1 || true

        if command -v fc-cache >/dev/null 2>&1; then
            fc-cache -f >/dev/null 2>&1 || true
        fi

        success "Son kontroller tamamlandı."
    }

    final_system_check

    # ========================================================
    # ÖZET
    # ========================================================

    show_summary
}

main "$@"
