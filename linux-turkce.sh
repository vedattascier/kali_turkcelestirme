#!/usr/bin/env bash
#
# Linux Türkçe + Pentest Kurulum Yöneticisi
# Kali Linux / Debian / Ubuntu
# Sürüm: 2026.31
#
# Özellikler:
# - Yalnızca 2 soru sorar
# - Kali 2026.x kali.sources desteği
# - APT/dpkg durumunu güvenli biçimde toparlar
# - Türkçe locale + Türkçe Q klavye
# - Geniş pentest araç seti (Benzersizleştirilmiş)

VERSION="2026.31"
LOG_FILE="/var/log/linux-turkce.log"
BACKUP_DIR="/var/backups/linux-turkce"
TMP_DIR="/tmp/linux-turkce.$$"
APT_TIMEOUT=300

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

INSTALLED=()
FAILED=()
SKIPPED=()

cleanup() {
    rm -rf "$TMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
prepare_log() {
    if ! mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null; then
        LOG_FILE="/tmp/linux-turkce.log"
    fi
    touch "$LOG_FILE" 2>/dev/null || true
    chmod 600 "$LOG_FILE" 2>/dev/null || true
}

log() {
    local level="$1"
    shift
    local message="$*"
    printf '[%s] [%s] %s\n' "$(date '+%F %T')" "$level" "$message" | tee -a "$LOG_FILE"
}

info() { log "BİLGİ" "$*"; }
ok()   { log " OK " "$*"; }
warn() { log "UYARI" "$*" >&2; }
err()  { log "HATA" "$*" >&2; }

# -----------------------------------------------------------------------------
# Basic checks
# -----------------------------------------------------------------------------
ensure_root() {
    if [[ ${EUID:-999} -ne 0 ]]; then
        err "Script root olarak çalıştırılmalı."
        exit 1
    fi
}

load_os_release() {
    if [[ ! -r /etc/os-release ]]; then
        err "/etc/os-release bulunamadı."
        exit 1
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
}

is_kali() {
    [[ "${ID:-}" == "kali" ]]
}

is_supported_os() {
    case "${ID:-}" in
        kali|debian|ubuntu) return 0 ;;
        *) return 1 ;;
    esac
}

# -----------------------------------------------------------------------------
# Arrays helpers
# -----------------------------------------------------------------------------
record_unique() {
    local array_name="$1"
    local value="$2"
    local item

    case "$array_name" in
        INSTALLED)
            for item in "${INSTALLED[@]}"; do [[ "$item" == "$value" ]] && return 0; done
            INSTALLED+=("$value") ;;
        FAILED)
            for item in "${FAILED[@]}"; do [[ "$item" == "$value" ]] && return 0; done
            FAILED+=("$value") ;;
        SKIPPED)
            for item in "${SKIPPED[@]}"; do [[ "$item" == "$value" ]] && return 0; done
            SKIPPED+=("$value") ;;
    esac
}

record_installed() { record_unique INSTALLED "$1"; }
record_failed()    { record_unique FAILED "$1"; }
record_skipped()   { record_unique SKIPPED "$1"; }

# -----------------------------------------------------------------------------
# Backup
# -----------------------------------------------------------------------------
create_backup_root() {
    mkdir -p "$BACKUP_DIR" 2>/dev/null || true
    chmod 700 "$BACKUP_DIR" 2>/dev/null || true
}

backup_file() {
    local file="$1"
    [[ -e "$file" ]] || return 0
    create_backup_root
    cp -a "$file" "$BACKUP_DIR/$(basename "$file").$(date '+%Y%m%d-%H%M%S').bak" 2>/dev/null || true
}

backup_apt_config() {
    local stamp
    stamp="$(date '+%Y%m%d-%H%M%S')"
    create_backup_root
    mkdir -p "$BACKUP_DIR/apt-$stamp" 2>/dev/null || true

    [[ -e /etc/apt/sources.list ]] && cp -a /etc/apt/sources.list "$BACKUP_DIR/apt-$stamp/" 2>/dev/null || true
    [[ -e /etc/apt/sources.list.d/kali.sources ]] && cp -a /etc/apt/sources.list.d/kali.sources "$BACKUP_DIR/apt-$stamp/" 2>/dev/null || true
}

backup_user_configs() {
    local target_user="${SUDO_USER:-}"
    local home_dir=""
    local stamp

    if [[ -n "$target_user" ]] && command -v getent >/dev/null 2>&1; then
        home_dir="$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6 || true)"
    fi
    [[ -n "$home_dir" && -d "$home_dir" ]] || home_dir="/root"

    stamp="$(date '+%Y%m%d-%H%M%S')"
    mkdir -p "$BACKUP_DIR/user-$stamp" 2>/dev/null || true

    local path
    for path in \
        "$home_dir/.config/gtk-3.0/settings.ini" \
        "$home_dir/.config/gtk-4.0/settings.ini" \
        "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml" \
        "$home_dir/.config/plank"; do
        [[ -e "$path" ]] && cp -a "$path" "$BACKUP_DIR/user-$stamp/" 2>/dev/null || true
    done
}

# -----------------------------------------------------------------------------
# APT locks
# -----------------------------------------------------------------------------
wait_for_apt_lock() {
    local max_wait=180
    local waited=0
    local busy
    local lock
    local locks=(
        /var/lib/dpkg/lock-frontend
        /var/lib/dpkg/lock
        /var/cache/apt/archives/lock
        /var/lib/apt/lists/lock
    )

    info "APT/dpkg kilitleri kontrol ediliyor..."

    while :; do
        busy=0
        for lock in "${locks[@]}"; do
            if command -v fuser >/dev/null 2>&1 && fuser "$lock" >/dev/null 2>&1; then
                busy=1
                break
            fi
        done

        if ((busy == 0)); then
            ok "APT/dpkg kilidi boş."
            return 0
        fi

        if ((waited >= max_wait)); then
            warn "APT/dpkg kilidi ${max_wait}s içinde boşalmadı."
            return 1
        fi

        sleep 2
        waited=$((waited + 2))
    done
}

# -----------------------------------------------------------------------------
# Package state
# -----------------------------------------------------------------------------
dpkg_state() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true
}

package_installed() {
    [[ "$(dpkg_state "$1")" == "install ok installed" ]]
}

remove_broken_package() {
    local pkg="$1"
    local state
    state="$(dpkg_state "$pkg")"
    [[ -n "$state" ]] || return 0

    warn "$pkg bozuk durumda; hedefli kaldırma uygulanıyor."
    dpkg --remove --force-depends --force-remove-reinstreq "$pkg" >>"$LOG_FILE" 2>&1 || true
}

# -----------------------------------------------------------------------------
# Dpkg repair
# -----------------------------------------------------------------------------
repair_dpkg() {
    info "dpkg/bağımlılık durumu kontrol ediliyor..."

    local rkh_status forensic_status
    rkh_status="$(dpkg_state rkhunter)"
    forensic_status="$(dpkg_state kali-tools-forensics)"

    if [[ "$rkh_status" == *"half-configured" ||
          "$rkh_status" == *"half-installed" ||
          "$rkh_status" == *"reinstreq" ]]; then

        if [[ "$forensic_status" == *"install ok" ||
              "$forensic_status" == *"half-configured" ||
              "$forensic_status" == *"half-installed" ||
              "$forensic_status" == *"reinstreq" ]]; then
            warn "kali-tools-forensics -> rkhunter bağımlılık zinciri tespit edildi."
            remove_broken_package kali-tools-forensics
        fi

        remove_broken_package rkhunter
    fi

    if ! dpkg --configure -a >>"$LOG_FILE" 2>&1; then
        warn "dpkg --configure -a ilk denemede başarısız; apt -f deneniyor."
    fi

    if ! apt-get -f install -y >>"$LOG_FILE" 2>&1; then
        warn "apt-get -f install başarısız."
    fi

    if ! dpkg --configure -a >>"$LOG_FILE" 2>&1; then
        warn "dpkg --configure -a ikinci denemede de başarısız."
    fi

    if ! dpkg --audit 2>/dev/null | grep -q .; then
        ok "dpkg/bağımlılık onarımı tamamlandı."
        return 0
    fi

    warn "dpkg hâlâ işlem bekleyen paket gösteriyor."
    dpkg --audit >>"$LOG_FILE" 2>&1 || true
    return 1
}

# -----------------------------------------------------------------------------
# Kali sources
# -----------------------------------------------------------------------------
ensure_kali_sources() {
    is_kali || return 0

    local keyring="/usr/share/keyrings/kali-archive-keyring.gpg"
    local source_file="/etc/apt/sources.list.d/kali.sources"
    local expected
    local needs_write=0

    expected=$'Types: deb\nURIs: http://http.kali.org/kali/\nSuites: kali-rolling\nComponents: main contrib non-free non-free-firmware\nSigned-By: /usr/share/keyrings/kali-archive-keyring.gpg\n'

    mkdir -p /etc/apt/sources.list.d

    if [[ ! -r "$keyring" ]]; then
        err "Kali archive keyring bulunamadı: $keyring"
        return 1
    fi

    if [[ ! -f "$source_file" ]]; then
        needs_write=1
    else
        grep -qE '^Types:[[:space:]]*deb[[:space:]]*$' "$source_file" || needs_write=1
        grep -qE '^URIs:[[:space:]]*http://http\.kali\.org/kali/?[[:space:]]*$' "$source_file" || needs_write=1
        grep -qE '^Suites:[[:space:]]*kali-rolling[[:space:]]*$' "$source_file" || needs_write=1
        grep -qE '^Components:[[:space:]]*main contrib non-free non-free-firmware[[:space:]]*$' "$source_file" || needs_write=1
        grep -qE '^Signed-By:[[:space:]]*/usr/share/keyrings/kali-archive-keyring\.gpg[[:space:]]*$' "$source_file" || needs_write=1
    fi

    if ((needs_write)); then
        warn "Kali kali.sources eksik veya hatalı."
        backup_apt_config
        printf '%s' "$expected" > "$source_file"
        chmod 644 "$source_file" 2>/dev/null || true
        ok "kali.sources düzeltildi."
    else
        ok "Kali APT kaynağı doğrulandı."
    fi
}

# -----------------------------------------------------------------------------
# APT index validation
# -----------------------------------------------------------------------------
apt_has_candidate() {
    local pkg="$1"
    apt-cache policy "$pkg" 2>/dev/null | grep -Eq '^[[:space:]]*Candidate:[[:space:]]*[^[:space:]({][^[:space:]]*'
}

apt_indexes_present() {
    [[ -d /var/lib/apt/lists ]] || return 1
    find /var/lib/apt/lists -maxdepth 1 -type f \
        \( -name '*_Packages' -o -name '*_Packages.*' \) \
        2>/dev/null | grep -q .
}

apt_index_is_healthy() {
    local pkg
    local count=0

    apt_has_candidate bash || return 1

    for pkg in bash nmap ghex plank gh; do
        if apt_has_candidate "$pkg"; then
            count=$((count + 1))
        fi
    done

    ((count >= 2))
}

refresh_apt_indexes() {
    info "APT paket indeksleri güncelleniyor..."

    mkdir -p /var/lib/apt/lists/partial

    local update_ok=0

    if timeout "$APT_TIMEOUT" apt-get update; then
        update_ok=1
    else
        warn "APT update ilk denemede başarısız."
    fi

    if ((update_ok == 1)) && apt_indexes_present && apt_index_is_healthy; then
        ok "APT paket indeksleri doğrulandı."
        return 0
    fi

    warn "APT metadata eksik/bozuk görünüyor. Paket listeleri temizleniyor..."

    rm -rf /var/lib/apt/lists/*
    mkdir -p /var/lib/apt/lists/partial

    if ! timeout "$APT_TIMEOUT" apt-get update; then
        err "APT paket indeksleri yeniden oluşturulamadı."
        return 1
    fi

    if ! apt_indexes_present || ! apt_index_is_healthy; then
        err "APT update tamamlandı ancak paket Candidate bilgileri üretilemiyor."
        return 1
    fi

    ok "APT paket indeksleri temiz şekilde oluşturuldu."
    return 0
}

apt_update() {
    wait_for_apt_lock || return 1

    if is_kali; then
        ensure_kali_sources || return 1
    fi

    repair_dpkg || warn "dpkg tam temizlenemedi; APT yine de doğrulanacak."
    refresh_apt_indexes || return 1

    dpkg --configure -a >>"$LOG_FILE" 2>&1 || true
    return 0
}

# -----------------------------------------------------------------------------
# Package install
# -----------------------------------------------------------------------------
package_available() {
    apt_has_candidate "$1"
}

safe_apt_install() {
    local pkg="$1"

    if package_installed "$pkg"; then
        ok "$pkg zaten kurulu."
        return 0
    fi

    if ! package_available "$pkg"; then
        warn "$pkg APT'te bulunamadı; atlanıyor."
        record_skipped "$pkg"
        return 0
    fi

    info "$pkg kuruluyor..."

    if apt-get install -y "$pkg" >>"$LOG_FILE" 2>&1 && package_installed "$pkg"; then
        ok "$pkg kuruldu."
        record_installed "$pkg"
        return 0
    fi

    warn "$pkg ilk kurulumda başarısız; bağımlılık onarımı + tekrar deneniyor."
    apt-get -f install -y >>"$LOG_FILE" 2>&1 || true
    dpkg --configure -a >>"$LOG_FILE" 2>&1 || true

    if apt-get install -y "$pkg" >>"$LOG_FILE" 2>&1 && package_installed "$pkg"; then
        ok "$pkg kurtarma denemesiyle kuruldu."
        record_installed "$pkg"
        return 0
    fi

    warn "$pkg kurulamadı; devam ediliyor."
    record_failed "$pkg"
    return 0
}

install_group() {
    local title="$1"
    shift

    info "============================================================"
    info "$title"
    info "============================================================"

    local valid=()
    local pkg

    for pkg in "$@"; do
        if package_installed "$pkg"; then
            ok "$pkg zaten kurulu."
        elif package_available "$pkg"; then
            valid+=("$pkg")
        else
            warn "$pkg APT'te bulunamadı; atlanıyor."
            record_skipped "$pkg"
        fi
    done

    if ((${#valid[@]} == 0)); then
        return 0
    fi

    if apt-get install -y "${valid[@]}" >>"$LOG_FILE" 2>&1; then
        for pkg in "${valid[@]}"; do
            if package_installed "$pkg"; then
                ok "$pkg kuruldu."
                record_installed "$pkg"
            else
                safe_apt_install "$pkg"
            fi
        done
        return 0
    fi

    warn "$title toplu kurulumu başarısız; paketler tek tek deneniyor."
    apt-get -f install -y >>"$LOG_FILE" 2>&1 || true
    dpkg --configure -a >>"$LOG_FILE" 2>&1 || true

    for pkg in "${valid[@]}"; do
        safe_apt_install "$pkg"
    done
}

# -----------------------------------------------------------------------------
# Turkish localization
# -----------------------------------------------------------------------------
setup_locale() {
    info "Türkçe locale hazırlanıyor..."

    backup_file /etc/locale.gen
    backup_file /etc/default/locale

    if [[ -f /etc/locale.gen ]]; then
        if grep -qE '^[#[:space:]]*tr_TR\.UTF-8[[:space:]]+UTF-8[[:space:]]*$' /etc/locale.gen; then
            sed -i 's/^[#[:space:]]*tr_TR\.UTF-8[[:space:]]\+UTF-8[[:space:]]*$/tr_TR.UTF-8 UTF-8/' /etc/locale.gen
        else
            printf '%s\n' 'tr_TR.UTF-8 UTF-8' >> /etc/locale.gen
        fi
    else
        printf '%s\n' 'tr_TR.UTF-8 UTF-8' > /etc/locale.gen
    fi

    command -v locale-gen >/dev/null 2>&1 && locale-gen tr_TR.UTF-8 >>"$LOG_FILE" 2>&1 || true

    if command -v update-locale >/dev/null 2>&1; then
        update-locale LANG=tr_TR.UTF-8 LANGUAGE=tr_TR:tr >>"$LOG_FILE" 2>&1 || true
    else
        cat > /etc/default/locale <<'LOCALE'
LANG=tr_TR.UTF-8
LANGUAGE=tr_TR:tr
LOCALE
    fi

    export LANG=tr_TR.UTF-8
    export LANGUAGE=tr_TR:tr
    unset LC_ALL

    ok "Türkçe locale hazırlandı."
}

setup_keyboard() {
    info "Türkçe Q klavye ayarlanıyor..."

    backup_file /etc/default/keyboard

    cat > /etc/default/keyboard <<'KEYBOARD'
XKBMODEL="pc105"
XKBLAYOUT="tr"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KEYBOARD

    if command -v debconf-set-selections >/dev/null 2>&1; then
        printf '%s\n' \
            'keyboard-configuration keyboard-configuration/layoutcode string tr' \
            'keyboard-configuration keyboard-configuration/modelcode string pc105' \
            'keyboard-configuration keyboard-configuration/variant string' \
            'keyboard-configuration keyboard-configuration/options string' \
            | debconf-set-selections 2>/dev/null || true
        # Apply the changes to debconf immediately
        dpkg-reconfigure -f noninteractive keyboard-configuration >>"$LOG_FILE" 2>&1 || true
    fi

    if command -v localectl >/dev/null 2>&1; then
        localectl set-keymap tr 2>/dev/null || true
        localectl set-x11-keymap tr pc105 2>/dev/null || true
    fi

    if command -v setupcon >/dev/null 2>&1; then
        setupcon -k --save 2>/dev/null || true
    fi

    ok "Türkçe Q klavye ayarı yazıldı."
}

install_language_packages() {
    local pkg

    if package_available firefox-esr-l10n-tr; then
        safe_apt_install firefox-esr-l10n-tr
    elif package_available firefox-l10n-tr; then
        safe_apt_install firefox-l10n-tr
    fi

    for pkg in chromium-l10n libreoffice-l10n-tr manpages-tr fonts-dejavu fonts-noto-core fonts-noto-cjk fonts-liberation2; do
        if package_available "$pkg"; then
            safe_apt_install "$pkg"
        fi
    done
}

# -----------------------------------------------------------------------------
# Comprehensive tool inventory
# -----------------------------------------------------------------------------
build_tool_lists() {
    GENERAL_TOOLS=(
        curl wget ca-certificates git gh rsync jq yq
        unzip zip xz-utils p7zip-full rar unrar-free
        fzf ripgrep tmux screen btop eza bat tree htop
        vim nano neovim emacs gedit kate mousepad
        terminator kitty xfce4-terminal
        flameshot kazam arandr lxappearance feh picom plank
        neofetch fastfetch
        openssl gnutls-bin
        usbutils pciutils lshw hwinfo
        net-tools iproute2 traceroute iperf3 socat
        netcat-openbsd netcat-traditional
        samba smbclient cifs-utils ldap-utils
        xclip xsel proxychains4 rlwrap expect sshpass
    )

    INFORMATION_TOOLS=(
        nmap ncat ndiff masscan arp-scan
        theharvester recon-ng maltego spiderfoot
        sherlock subfinder amass assetfinder
        dnsenum dnsrecon fierce dnsmap dnswalk
        whois whatweb wafw00f httpx-toolkit
        sn0int eyewitness gowitness aquatone
    )

    WEB_TOOLS=(
        nikto sqlmap gobuster dirsearch ffuf feroxbuster
        nuclei commix wapiti davtest dotdotpwn
        burpsuite zaproxy mitmproxy
        wpscan joomscan droopescan
        arjun paramspider
        testssl.sh sslscan sslyze corscanner
    )

    EXPLOIT_TOOLS=(
        metasploit-framework exploitdb
        exploitdb-bin-sploits msfpc set
        beef-xss gophish routersploit
        shellnoob termineter
    )

    PASSWORD_TOOLS=(
        hashcat hashcat-utils john johnny
        hydra hydra-gtk medusa patator
        ncrack crowbar crunch cewl
        hashid hash-identifier
        ophcrack ophcrack-cli
        fcrackzip pdfcrack
        chntpw samdump2
        seclists wordlists pack
    )

    WIRELESS_TOOLS=(
        aircrack-ng reaver bully wifite
        kismet fern-wifi-cracker fluxion
        hcxdumptool hcxtools hcxpcapngtool
        pixiewps rfkill iw wireless-tools
        hostapd hostapd-wpe macchanger
    )

    NETWORK_TOOLS=(
        wireshark tshark tcpdump
        ettercap-graphical ettercap-common
        bettercap dsniff
        tcpflow tcpreplay netsniff-ng
        sniffglue ssldump
    )

    AD_WINDOWS_TOOLS=(
        evil-winrm enum4linux enum4linux-ng
        impacket-scripts python3-impacket
        netexec responder bloodyad crackmapexec
        ldapsearch-ad kerbrute certipy-ad
        bloodhound bloodhound.py mitm6
    )

    REVERSE_TOOLS=(
        ghidra ghidra-data
        jadx rizin radare2 rizin-cutter rz-ghidra cutter
        apktool dex2jar bytecode-viewer jd-gui
        ropper ropgadget pwntools
        edb-debugger gdb gdb-multiarch
        binwalk binwalk3
        yara yara-python capa
        strace ltrace binutils nasm
        objdump patchelf checksec
        file osslsigncode upx-ucl
    )

    FORENSIC_TOOLS=(
        steghide stegsnow
        exiftool foremost sleuthkit autopsy
        testdisk dc3dd dcfldd scalpel
        ssdeep hashdeep md5deep
        unhide bulk-extractor
        ewf-tools afflib-tools
        guymager gpart gparted
        ext4magic extundelete recoverjpeg recoverdm
        magicrescue photorec safecopy ddrescue
        forensic-artifacts forensics-colorize
        volatility3 volatility plaso
        rifiuti2 rifiuti
        reglookup regripper sqlitebrowser
        exiv2 cabextract
    )

    MOBILE_TOOLS=(
        adb fastboot scrcpy
        android-sdk-platform-tools
        frida-tools objection apkid qemu-user-static
    )

    SNIFF_SPOOF_TOOLS=(
        arpspoof sslstrip dnschef
    )

    POST_EXPLOIT_TOOLS=(
        chisel ligolo-ng pwncat mimikatz
    )

    CLOUD_CONTAINER_TOOLS=(
        trivy prowler kube-hunter kubeaudit
        docker.io docker-compose podman skopeo
    )

    REPORTING_TOOLS=(
        dradis faraday cherrytree cutycapt
    )

    PRIVESC_TOOLS=(
        linux-exploit-suggester linpeas pspy peass
        unix-privesc-check linux-smart-enumeration
    )

    VULN_TOOLS=(
        gvm lynis
    )

    MALWARE_ANALYSIS_TOOLS=(
        clamav clamav-daemon
    )

    RF_TOOLS=(
        rtl-sdr gqrx-sdr inspectrum gr-osmosdr
        hackrf hackrf-tools sdrangel
    )

    OPTIONAL_TOOLS=(
        arsenal-ng arsenal jwt-tool sublime-text
    )
}

install_pentest_stack() {
    build_tool_lists

    install_group "Genel / Sistem / Terminal" "${GENERAL_TOOLS[@]}"
    install_group "Bilgi Toplama / OSINT / Recon" "${INFORMATION_TOOLS[@]}"
    install_group "Web Güvenliği" "${WEB_TOOLS[@]}"
    install_group "Exploitation / Metasploit" "${EXPLOIT_TOOLS[@]}"
    install_group "Parola / Hash" "${PASSWORD_TOOLS[@]}"
    install_group "Kablosuz" "${WIRELESS_TOOLS[@]}"
    install_group "Ağ / Sniffing" "${NETWORK_TOOLS[@]}"
    install_group "Windows / AD / SMB" "${AD_WINDOWS_TOOLS[@]}"
    install_group "Reverse Engineering / Binary" "${REVERSE_TOOLS[@]}"
    install_group "Forensics / Steganography" "${FORENSIC_TOOLS[@]}"
    install_group "Mobil / Android" "${MOBILE_TOOLS[@]}"
    install_group "Sniffing / Spoofing / MITM" "${SNIFF_SPOOF_TOOLS[@]}"
    install_group "Post-Exploitation" "${POST_EXPLOIT_TOOLS[@]}"
    install_group "Cloud / Container" "${CLOUD_CONTAINER_TOOLS[@]}"
    install_group "Reporting" "${REPORTING_TOOLS[@]}"
    install_group "Privilege Escalation" "${PRIVESC_TOOLS[@]}"
    install_group "Vulnerability Management" "${VULN_TOOLS[@]}"
    install_group "Malware Analysis" "${MALWARE_ANALYSIS_TOOLS[@]}"
    install_group "RF / SDR" "${RF_TOOLS[@]}"
    install_group "Özel / APT'te varsa" "${OPTIONAL_TOOLS[@]}"
}

# -----------------------------------------------------------------------------
# Final repair / checks
# -----------------------------------------------------------------------------
final_repair() {
    info "Kurulum sonrası dpkg/bağımlılık kontrolü..."

    wait_for_apt_lock || true

    apt-get -f install -y >>"$LOG_FILE" 2>&1 || warn "Son apt -f install başarısız."
    dpkg --configure -a >>"$LOG_FILE" 2>&1 || warn "Son dpkg --configure -a başarısız."

    if dpkg --audit 2>/dev/null | grep -q .; then
        warn "Kurulum sonunda dpkg hâlâ işlem bekleyen paket gösteriyor."
        dpkg --audit >>"$LOG_FILE" 2>&1 || true
        return 1
    fi

    ok "Kurulum sonunda dpkg temiz."
    return 0
}

verify_apt() {
    if apt_index_is_healthy; then
        ok "APT Candidate bilgileri kullanılabilir."
        return 0
    fi
    warn "APT Candidate doğrulaması başarısız."
    return 1
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
summary() {
    printf '\n'
    printf '%s\n' '============================================================'
    printf '  Linux Türkçe + Pentest Kurulum Özeti v%s\n' "$VERSION"
    printf '%s\n' '============================================================'
    printf '  OS       : %s\n' "${PRETTY_NAME:-${NAME:-Bilinmiyor}}"
    printf '  Log      : %s\n' "$LOG_FILE"
    printf '  Yedekler : %s\n' "$BACKUP_DIR"
    printf '\n'
    printf 'Kurulan paket sayısı: %d\n' "${#INSTALLED[@]}"

    if ((${#SKIPPED[@]} > 0)); then
        printf '\nAPT kaynağında bulunamadığı için atlananlar:\n'
        printf '  - %s\n' "${SKIPPED[@]}"
    fi

    if ((${#FAILED[@]} > 0)); then
        printf '\nKurulumu başarısız olup devam edilenler:\n'
        printf '  - %s\n' "${FAILED[@]}"
    fi

    printf '\nSon dpkg denetimi:\n'
    if dpkg --audit 2>/dev/null | grep -q .; then
        printf '  UYARI: dpkg hâlâ işlem bekleyen paket gösteriyor.\n'
    else
        printf '  OK: dpkg temiz.\n'
    fi

    printf '\nAPT denetimi:\n'
    if verify_apt >/dev/null 2>&1; then
        printf '  OK: APT paket adayları kullanılabilir.\n'
    else
        printf '  UYARI: APT paket adayları doğrulanamadı.\n'
    fi

    if is_kali && [[ -f /etc/apt/sources.list.d/kali.sources ]]; then
        printf '  OK: /etc/apt/sources.list.d/kali.sources mevcut.\n'
    fi

    printf '\nLog      : %s\n' "$LOG_FILE"
    printf 'Yedekler : %s\n' "$BACKUP_DIR"
    printf '\nTürkçe değişikliklerin tamamı için oturumu kapatıp açın.\n'
    printf 'Kurulum tamamlandı.\n'
}

# -----------------------------------------------------------------------------
# Only two questions
# -----------------------------------------------------------------------------
ask_yes_no() {
    local prompt="$1"
    local answer

    if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
        err "İnteraktif terminal (/dev/tty) bulunamadı."
        err "Soruların cevaplanabilmesi için bir terminal gerekiyor."
        return 2
    fi

    while :; do
        printf "%s" "$prompt" > /dev/tty

        if ! IFS= read -r answer < /dev/tty; then
            err "Terminalden cevap okunamadı."
            return 2
        fi

        answer="${answer:-E}"

        case "$answer" in
            E|e|EVET|evet|Y|y|YES|yes)
                return 0
                ;;
            H|h|HAYIR|hayır|hayir|HAYİR|n|N|NO|no)
                return 1
                ;;
            *)
                printf '%s\n' 'Lütfen E veya H girin.' > /dev/tty
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    ensure_root
    prepare_log
    load_os_release

    printf '\n'
    printf '%s\n' '============================================================'
    printf '  LINUX TÜRKÇE + PENTEST KURULUM YÖNETİCİSİ v%s\n' "$VERSION"
    printf '%s\n\n' '============================================================'

    local do_turkish=0
    local do_pentest=0

    ask_yes_no 'Linux Türkçe yapılsın mı? [E/h]: '
    case $? in
        0) do_turkish=1 ;;
        1) do_turkish=0 ;;
        *) exit 1 ;;
    esac

    ask_yes_no 'Pentest araçları kurulsun mu? [E/h]: '
    case $? in
        0) do_pentest=1 ;;
        1) do_pentest=0 ;;
        *) exit 1 ;;
    esac

    if ! is_supported_os; then
        err "Desteklenmeyen dağıtım: ${ID:-bilinmiyor}"
        err "Destek: Kali Linux, Debian, Ubuntu"
        exit 1
    fi

    if ((do_turkish)); then
        backup_apt_config
        backup_user_configs
    fi

    info "APT hazırlanıyor..."

    if ! apt_update; then
        err "APT güvenilir şekilde hazırlanamadı."
        err "İşlem güvenli olarak durduruldu."
        err "Log: $LOG_FILE"
        exit 1
    fi

    if ((do_turkish)); then
        info "Türkçe yapılandırma başlıyor..."
        setup_locale
        setup_keyboard
        install_language_packages
    fi

    if ((do_pentest)); then
        info "Geniş pentest araç seti kurulumu başlıyor..."
        install_pentest_stack
    fi

    final_repair || true
    verify_apt || true
    summary
}

main "$@"
