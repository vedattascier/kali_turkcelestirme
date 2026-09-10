#!/usr/bin/env bash
#
# Linux Türkçe + Pentest Kurulum Yöneticisi
# Kali Linux / Debian / Ubuntu
# Sürüm: 2026.20
#

VERSION="2026.20"
LOG_FILE="/var/log/linux-turkce.log"
BACKUP_DIR="/var/backups/linux-turkce"
TMP_DIR="/tmp/linux-turkce.$$"
APT_TIMEOUT="180"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

mkdir -p "$TMP_DIR" 2>/dev/null || true

cleanup() {
    rm -rf "$TMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

log() {
    local msg="$*"
    printf '[%s] %s\n' "$(date '+%F %T')" "$msg" | tee -a "$LOG_FILE"
}

info() { log "[BİLGİ] $*"; }
ok()   { log "[ OK ] $*"; }
warn() { log "[UYARI] $*" >&2; }
err()  { log "[HATA] $*" >&2; }

ensure_root() {
    if [[ ${EUID:-999} -ne 0 ]]; then
        err "Bu script root olarak çalıştırılmalı."
        err "Örnek: sudo bash linux-turkce.sh"
        exit 1
    fi
}

prepare_log() {
    touch "$LOG_FILE" 2>/dev/null || {
        LOG_FILE="/tmp/linux-turkce.log"
        touch "$LOG_FILE" 2>/dev/null || true
    }

    chmod 600 "$LOG_FILE" 2>/dev/null || true
}

backup_file() {
    local f="$1"

    [[ -e "$f" ]] || return 0

    mkdir -p "$BACKUP_DIR" 2>/dev/null || return 0

    cp -a "$f" \
        "$BACKUP_DIR/$(basename "$f").$(date +%Y%m%d-%H%M%S).bak" \
        2>/dev/null || true
}

backup_apt_config() {
    mkdir -p "$BACKUP_DIR/apt" 2>/dev/null || true

    backup_file /etc/apt/sources.list
    backup_file /etc/apt/sources.list.d/kali.sources

    if [[ -d /etc/apt/sources.list.d ]]; then
        cp -a /etc/apt/sources.list.d \
            "$BACKUP_DIR/apt/sources.list.d.$(date +%Y%m%d-%H%M%S).bak" \
            2>/dev/null || true
    fi
}

is_kali() {
    grep -qiE '^ID=kali$|^NAME="?Kali Linux"?' \
        /etc/os-release 2>/dev/null
}

is_debian_family() {
    grep -qiE '^ID=(debian|ubuntu|kali)$' \
        /etc/os-release 2>/dev/null
}

wait_for_apt_lock() {
    local max_wait=180
    local waited=0

    local locks=(
        /var/lib/dpkg/lock-frontend
        /var/lib/dpkg/lock
        /var/cache/apt/archives/lock
        /var/lib/apt/lists/lock
    )

    info "APT/dpkg kilitleri kontrol ediliyor..."

    while :; do
        local busy=0
        local f

        for f in "${locks[@]}"; do
            if command -v fuser >/dev/null 2>&1; then
                if fuser "$f" >/dev/null 2>&1; then
                    busy=1
                    break
                fi
            fi
        done

        if ((busy == 0)); then
            ok "APT/dpkg kilidi boş."
            return 0
        fi

        if ((waited >= max_wait)); then
            warn "APT/dpkg kilidi $max_wait saniye içinde boşalmadı."
            return 1
        fi

        sleep 2
        waited=$((waited + 2))
    done
}

dpkg_state() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true
}

package_installed() {
    [[ "$(dpkg_state "$1")" == "install ok installed" ]]
}

package_available() {
    local pkg="$1"

    apt-cache show "$pkg" >/dev/null 2>&1
}

remove_dpkg_package() {
    local pkg="$1"

    if [[ -z "$(dpkg_state "$pkg")" ]]; then
        return 0
    fi

    info "$pkg kaldırılıyor..."

    dpkg \
        --remove \
        --force-depends \
        --force-remove-reinstreq \
        "$pkg" \
        >>"$LOG_FILE" 2>&1 || true
}

repair_dpkg() {
    info "dpkg/bağımlılık durumu kontrol ediliyor..."

    local rkh_status
    rkh_status="$(dpkg_state rkhunter)"

    #
    # Özel kurtarma:
    #
    # kali-tools-forensics -> rkhunter
    #
    # rkhunter postinst bozulduğunda metapackage dpkg'nin
    # toparlanmasını engelleyebilir. Metapackage kaldırılır,
    # bağımsız adli araçlar silinmez.
    #

    if [[ "$rkh_status" == *"half-configured"* ||
          "$rkh_status" == *"half-installed"* ||
          "$rkh_status" == *"reinstreq"* ]]; then

        warn "Bozuk rkhunter durumu tespit edildi:"
        warn "$rkh_status"

        local forensic_status
        forensic_status="$(dpkg_state kali-tools-forensics)"

        if [[ "$forensic_status" == *"install ok"* ||
              "$forensic_status" == *"half-configured"* ||
              "$forensic_status" == *"half-installed"* ||
              "$forensic_status" == *"reinstreq"* ]]; then

            warn "kali-tools-forensics metapackage'i kaldırılıyor..."

            dpkg \
                --remove \
                --force-depends \
                --force-remove-reinstreq \
                kali-tools-forensics \
                >>"$LOG_FILE" 2>&1 || true
        fi

        warn "Bozuk rkhunter paketi kaldırılıyor..."

        dpkg \
            --remove \
            --force-depends \
            --force-remove-reinstreq \
            rkhunter \
            >>"$LOG_FILE" 2>&1 || true
    fi

    #
    # İlk normal dpkg toparlama
    #

    if ! dpkg --configure -a >>"$LOG_FILE" 2>&1; then
        warn "dpkg --configure -a ilk denemede başarısız."
    fi

    #
    # Bağımlılık onarımı
    #

    if ! apt-get -f install -y >>"$LOG_FILE" 2>&1; then
        warn "apt-get -f install başarısız oldu."
    fi

    #
    # İkinci dpkg toparlama
    #

    if ! dpkg --configure -a >>"$LOG_FILE" 2>&1; then
        warn "dpkg --configure -a ikinci denemede de başarısız."
        dpkg --audit >>"$LOG_FILE" 2>&1 || true
    fi

    #
    # Son bağımlılık onarımı
    #

    if apt-get -f install -y >>"$LOG_FILE" 2>&1; then
        if dpkg --configure -a >>"$LOG_FILE" 2>&1; then
            ok "dpkg/bağımlılık onarımı tamamlandı."
            return 0
        fi
    fi

    warn "APT/dpkg tamamen temizlenemedi."
    dpkg --audit >>"$LOG_FILE" 2>&1 || true

    return 1
}

ensure_kali_sources() {
    is_kali || return 0

    local keyring="/usr/share/keyrings/kali-archive-keyring.gpg"
    local source_file="/etc/apt/sources.list.d/kali.sources"

    local expected
    expected=$'Types: deb\nURIs: http://http.kali.org/kali/\nSuites: kali-rolling\nComponents: main contrib non-free non-free-firmware\nSigned-By: /usr/share/keyrings/kali-archive-keyring.gpg\n'

    mkdir -p /etc/apt/sources.list.d

    #
    # Keyring yoksa güvenlik açısından rastgele indirme yapılmaz.
    #

    if [[ ! -f "$keyring" ]]; then
        err "Kali archive keyring bulunamadı:"
        err "$keyring"
        err "APT kaynağı güvenli şekilde otomatik düzeltilemiyor."
        return 1
    fi

    #
    # kali.sources yoksa oluştur
    #

    if [[ ! -f "$source_file" ]]; then
        info "Kali APT kaynağı oluşturuluyor..."
        backup_apt_config
        printf '%s' "$expected" > "$source_file"
    else

        #
        # Mevcut dosya hatalıysa yedekle ve düzelt
        #

        if ! grep -q \
            '^URIs:[[:space:]]*http://http\.kali\.org/kali/?[[:space:]]*$' \
            "$source_file" || \
           ! grep -q \
            '^Suites:[[:space:]]*kali-rolling[[:space:]]*$' \
            "$source_file" || \
           ! grep -q \
            '^Components:[[:space:]]*main contrib non-free non-free-firmware[[:space:]]*$' \
            "$source_file" || \
           ! grep -q \
            '^Signed-By:[[:space:]]*/usr/share/keyrings/kali-archive-keyring\.gpg[[:space:]]*$' \
            "$source_file"; then

            warn "kali.sources hatalı görünüyor."
            warn "Yedek alınıp standart Kali rolling kaynağı yazılıyor."

            backup_apt_config

            printf '%s' "$expected" > "$source_file"
        fi
    fi

    #
    # Eski sources.list içindeki aynı Kali kaynağını kaldır.
    # Kullanıcının diğer kaynaklarına dokunulmaz.
    #

    if [[ -f /etc/apt/sources.list ]]; then
        sed -i \
            '/^[[:space:]]*deb[[:space:]]\+http:\/\/http\.kali\.org\/kali[[:space:]]\+kali-rolling[[:space:]]/d' \
            /etc/apt/sources.list \
            2>/dev/null || true
    fi

    ok "Kali APT kaynağı doğrulandı."
}

apt_update() {
    wait_for_apt_lock || return 1

    if is_kali; then
        ensure_kali_sources || return 1
    fi

    #
    # Önce bozuk dpkg durumunu düzelt
    #

    if ! repair_dpkg; then
        warn "dpkg tamamen toparlanamadı."
        warn "Yine de APT update deneniyor."
    fi

    info "APT paket listeleri güncelleniyor..."

    if timeout "$APT_TIMEOUT" apt-get update; then
        ok "APT update başarılı."
        return 0
    fi

    #
    # İkinci deneme
    #

    warn "APT update ilk denemede başarısız."

    if is_kali; then
        ensure_kali_sources || return 1
    fi

    timeout "$APT_TIMEOUT" apt-get update
}

safe_apt_install() {
    local pkg="$1"
    shift

    local extra=("$@")

    if package_installed "$pkg"; then
        ok "$pkg zaten kurulu."
        return 0
    fi

    if ! package_available "$pkg"; then
        warn "$pkg APT kaynaklarında bulunamadı; atlanıyor."
        SKIPPED+=("$pkg")
        return 0
    fi

    info "$pkg kuruluyor..."

    #
    # İlk deneme loga
    #

    if apt-get install \
        -y \
        "${extra[@]}" \
        "$pkg" \
        >>"$LOG_FILE" 2>&1; then

        ok "$pkg kuruldu."
        INSTALLED+=("$pkg")
        return 0
    fi

    #
    # Tekil kurtarma denemesi
    #

    warn "$pkg grup kurulumunda başarısız."
    warn "Tekil kurtarma kurulumu deneniyor..."

    if apt-get install \
        -y \
        "${extra[@]}" \
        "$pkg"; then

        ok "$pkg kuruldu (kurtarma denemesi)."
        INSTALLED+=("$pkg")
        return 0
    fi

    warn "$pkg kurulamadı; devam ediliyor."
    FAILED+=("$pkg")

    #
    # Paket yüzünden dpkg bozulmuşsa hemen toparlamayı dene
    #

    apt-get -f install -y >>"$LOG_FILE" 2>&1 || true
    dpkg --configure -a >>"$LOG_FILE" 2>&1 || true

    return 0
}

install_group() {
    local group_name="$1"
    shift

    info "============================================================"
    info "$group_name"
    info "============================================================"

    local valid=()
    local pkg

    #
    # Ön filtre
    #

    for pkg in "$@"; do

        if package_installed "$pkg"; then
            ok "$pkg zaten kurulu."
            continue
        fi

        if package_available "$pkg"; then
            valid+=("$pkg")
        else
            warn "$pkg bulunamadı; atlanıyor."
            SKIPPED+=("$pkg")
        fi
    done

    if ((${#valid[@]} == 0)); then
        return 0
    fi

    #
    # Önce grup halinde kur
    #

    if apt-get install \
        -y \
        "${valid[@]}" \
        >>"$LOG_FILE" 2>&1; then

        for pkg in "${valid[@]}"; do
            if package_installed "$pkg"; then
                ok "$pkg kuruldu."
                INSTALLED+=("$pkg")
            else
                safe_apt_install "$pkg"
            fi
        done

        return 0
    fi

    #
    # Grup başarısızsa tek tek kur
    #

    warn "$group_name toplu kurulumda hata verdi."
    warn "Paketler tek tek deneniyor..."

    for pkg in "${valid[@]}"; do
        safe_apt_install "$pkg"
    done
}

setup_locale() {
    info "Türkçe locale hazırlanıyor..."

    backup_file /etc/default/locale
    backup_file /etc/locale.gen

    if [[ -f /etc/locale.gen ]]; then
        if ! grep -qE '^tr_TR\.UTF-8[[:space:]]+UTF-8$' /etc/locale.gen; then
            printf '%s\n' 'tr_TR.UTF-8 UTF-8' >> /etc/locale.gen
        fi
    else
        printf '%s\n' 'tr_TR.UTF-8 UTF-8' > /etc/locale.gen
    fi

    if command -v locale-gen >/dev/null 2>&1; then
        locale-gen tr_TR.UTF-8 >>"$LOG_FILE" 2>&1 || true
    fi

    if command -v update-locale >/dev/null 2>&1; then
        update-locale \
            LANG=tr_TR.UTF-8 \
            LANGUAGE=tr_TR:tr \
            LC_ALL=tr_TR.UTF-8 \
            >>"$LOG_FILE" 2>&1 || true
    else
        cat > /etc/default/locale <<'EOF_LOCALE'
LANG=tr_TR.UTF-8
LANGUAGE=tr_TR:tr
LC_ALL=tr_TR.UTF-8
EOF_LOCALE
    fi

    export LANG=tr_TR.UTF-8
    export LANGUAGE=tr_TR:tr
    export LC_ALL=tr_TR.UTF-8

    ok "Türkçe locale ayarlandı."
}

setup_keyboard() {
    info "Türkçe Q klavye ayarlanıyor..."

    backup_file /etc/default/keyboard

    cat > /etc/default/keyboard <<'EOF_KEYBOARD'
XKBMODEL="pc105"
XKBLAYOUT="tr"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF_KEYBOARD

    #
    # Debian keyboard-config debconf
    #

    if command -v debconf-set-selections >/dev/null 2>&1; then

        printf '%s\n' \
            'keyboard-configuration keyboard-configuration/layoutcode string tr' \
            'keyboard-configuration keyboard-configuration/modelcode string pc105' \
            'keyboard-configuration keyboard-configuration/variant select Turkish' \
            | debconf-set-selections 2>/dev/null || true
    fi

    #
    # Konsol
    #

    if command -v setupcon >/dev/null 2>&1; then
        setupcon -k --save 2>/dev/null || true
    fi

    #
    # Systemd/localectl mevcutsa X11
    #

    if command -v localectl >/dev/null 2>&1; then
        localectl set-keymap tr 2>/dev/null || true
        localectl set-x11-keymap tr pc105 2>/dev/null || true
    fi

    ok "Türkçe Q klavye ayarı yazıldı."
}

install_language_packages() {
    local firefox_pkg=""
    local chromium_pkg=""
    local office_pkg=""
    local man_pkg=""

    #
    # Firefox
    #

    if package_available firefox-esr-l10n-tr; then
        firefox_pkg="firefox-esr-l10n-tr"
    elif package_available firefox-l10n-tr; then
        firefox_pkg="firefox-l10n-tr"
    fi

    #
    # Chromium
    #

    if package_available chromium-l10n; then
        chromium_pkg="chromium-l10n"
    fi

    #
    # LibreOffice
    #

    if package_available libreoffice-l10n-tr; then
        office_pkg="libreoffice-l10n-tr"
    fi

    #
    # Türkçe man pages
    #

    if package_available manpages-tr; then
        man_pkg="manpages-tr"
    fi

    [[ -n "$firefox_pkg" ]] && safe_apt_install "$firefox_pkg"
    [[ -n "$chromium_pkg" ]] && safe_apt_install "$chromium_pkg"
    [[ -n "$office_pkg" ]] && safe_apt_install "$office_pkg"
    [[ -n "$man_pkg" ]] && safe_apt_install "$man_pkg"
}

backup_user_configs() {
    local target_user="${SUDO_USER:-${USER:-root}}"
    local home_dir

    home_dir="$(
        getent passwd "$target_user" 2>/dev/null |
        cut -d: -f6
    )"

    if [[ -z "$home_dir" || ! -d "$home_dir" ]]; then
        home_dir="/root"
    fi

    mkdir -p "$BACKUP_DIR/user" 2>/dev/null || true

    local path

    for path in \
        "$home_dir/.config/gtk-3.0/settings.ini" \
        "$home_dir/.config/gtk-4.0/settings.ini" \
        "$home_dir/.config/plank"; do

        if [[ -e "$path" ]]; then
            cp -a "$path" "$BACKUP_DIR/user/" \
                2>/dev/null || true
        fi
    done
}

build_general_tools() {
    GENERAL_TOOLS=(
        curl
        wget
        git
        gh
        unzip
        p7zip-full
        xz-utils
        zip
        jq
        rsync
        ca-certificates

        fzf
        ripgrep
        tmux
        btop
        eza
        bat

        neofetch

        gedit
        kate
        vim
        nano

        terminator
        plank
        kazam
        flameshot
        arandr
        lxappearance
        feh
        picom
        unclutter-xfixes

        sonic-visualiser
        ghex

        samba
        smbclient
        cifs-utils
        ldap-utils

        net-tools
        iproute2
        traceroute
        iperf3
        socat
        netcat-openbsd
    )
}

build_network_tools() {
    NETWORK_TOOLS=(
        nmap
        ncat
        ndiff
        masscan
        arp-scan
        tcpdump
        tshark
        wireshark
        bettercap
        ettercap-graphical
        mitmproxy

        aircrack-ng
        reaver
        bully
        kismet
        wifite
        hcxdumptool
        hcxpcapngtool

        rfkill
        iw
    )
}

build_web_tools() {
    WEB_TOOLS=(
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
        zaproxy
    )
}

build_reverse_tools() {
    REVERSE_TOOLS=(
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

        cutter
        ghex
    )
}

build_windows_tools() {
    WINDOWS_TOOLS=(
        evil-winrm
        enum4linux
        enum4linux-ng
        impacket-scripts
        netexec
        responder
        bloodyad

        samba
        smbclient
        cifs-utils
        ldap-utils
    )
}

build_stego_forensic_tools() {
    FORENSIC_TOOLS=(
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
        ssdeep
        unhide
    )
}

build_password_tools() {
    PASSWORD_TOOLS=(
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
}

build_vuln_tools() {
    VULN_TOOLS=(
        gvm
    )
}

build_optional_named_tools() {
    OPTIONAL_TOOLS=()

    #
    # Arsenal
    #

    if package_available arsenal-ng; then
        OPTIONAL_TOOLS+=("arsenal-ng")
    elif package_available arsenal; then
        OPTIONAL_TOOLS+=("arsenal")
    fi

    #
    # Sublime Text:
    # Üçüncü taraf repo otomatik eklenmez.
    # Mevcut APT kaynağında varsa kurulur.
    #

    if package_available sublime-text; then
        OPTIONAL_TOOLS+=("sublime-text")
    fi
}

install_pentest_stack() {
    build_general_tools
    build_network_tools
    build_web_tools
    build_reverse_tools
    build_windows_tools
    build_stego_forensic_tools
    build_password_tools
    build_vuln_tools
    build_optional_named_tools

    install_group \
        "Genel / Masaüstü / Yardımcı" \
        "${GENERAL_TOOLS[@]}"

    install_group \
        "Ağ / Kablosuz" \
        "${NETWORK_TOOLS[@]}"

    install_group \
        "Web / Recon" \
        "${WEB_TOOLS[@]}"

    install_group \
        "Reverse Engineering" \
        "${REVERSE_TOOLS[@]}"

    install_group \
        "Windows / AD / SMB" \
        "${WINDOWS_TOOLS[@]}"

    install_group \
        "Stego / Forensics" \
        "${FORENSIC_TOOLS[@]}"

    install_group \
        "Hash / Password" \
        "${PASSWORD_TOOLS[@]}"

    install_group \
        "Vulnerability / GVM" \
        "${VULN_TOOLS[@]}"

    install_group \
        "Özel araçlar" \
        "${OPTIONAL_TOOLS[@]}"

    #
    # JWT Tool
    #
    # Rastgele pip/GitHub kaynağı kullanılmaz.
    #

    if package_available jwt-tool; then
        safe_apt_install jwt-tool
    else
        SKIPPED+=(
            "jwt-tool (APT kaynağında yok; üçüncü taraf kurulum yapılmadı)"
        )
    fi
}

post_install_repair() {
    info "Kurulum sonrası dpkg/bağımlılık kontrolü..."

    wait_for_apt_lock || true

    apt-get -f install -y \
        >>"$LOG_FILE" 2>&1 || \
        warn "Kurulum sonrası apt -f install başarısız."

    dpkg --configure -a \
        >>"$LOG_FILE" 2>&1 || \
        warn "Kurulum sonrası dpkg --configure -a başarısız."

    #
    # Bir kez daha kontrol
    #

    if dpkg --audit 2>/dev/null | grep -q .; then
        warn "Kurulum sonunda hâlâ işlem bekleyen paket var."
    else
        ok "Kurulum sonunda dpkg temiz."
    fi
}

check_core_commands() {
    local cmds=(
        bash
        apt-get
        dpkg
        locale-gen
    )

    local missing=()
    local c

    for c in "${cmds[@]}"; do
        if ! command -v "$c" >/dev/null 2>&1; then
            missing+=("$c")
        fi
    done

    if ((${#missing[@]})); then
        warn "Temel komut eksik: ${missing[*]}"
    fi
}

summary() {
    printf '\n'
    printf '============================================================\n'
    printf '  Linux Türkçe + Pentest Kurulum Özeti v%s\n' "$VERSION"
    printf '============================================================\n'

    printf '  Log      : %s\n' "$LOG_FILE"
    printf '  Yedekler : %s\n' "$BACKUP_DIR"

    printf '\n'

    printf 'Kurulan paket sayısı: %d\n' "${#INSTALLED[@]}"

    if ((${#SKIPPED[@]})); then
        printf '\n'
        printf 'Bulunamadığı için atlananlar:\n'

        printf '  - %s\n' "${SKIPPED[@]}"
    fi

    if ((${#FAILED[@]})); then
        printf '\n'
        printf 'Kurulumu başarısız olup devam edilenler:\n'

        printf '  - %s\n' "${FAILED[@]}"
    fi

    printf '\n'
    printf 'Son dpkg denetimi:\n'

    if dpkg --audit 2>/dev/null | grep -q .; then
        printf '  UYARI: dpkg hâlâ işlem bekleyen paket gösteriyor.\n'
        dpkg --audit 2>/dev/null |
            sed 's/^/  /'
    else
        printf '  OK: dpkg temiz görünüyor.\n'
    fi

    if is_kali &&
       [[ -f /etc/apt/sources.list.d/kali.sources ]]; then

        printf '\n'
        printf 'Kali APT:\n'
        printf '  /etc/apt/sources.list.d/kali.sources doğrulandı.\n'
    fi

    printf '\n'
    printf 'Log dosyası: %s\n' "$LOG_FILE"
    printf 'Yedekler  : %s\n' "$BACKUP_DIR"
    printf '\n'
    printf 'Kurulum tamamlandı.\n'
    printf 'Türkçe locale/klavye için oturumu kapatıp açmanız önerilir.\n'
}

ask_yes_no() {
    local prompt="$1"
    local answer

    while :; do

        read -r -p "$prompt" answer

        answer="${answer:-E}"

        case "$answer" in
            E|e|evet|EVET|Y|y|yes|YES)
                return 0
                ;;

            H|h|hayır|hayir|HAYIR|N|n|no|NO)
                return 1
                ;;

            *)
                printf 'Lütfen E veya H girin.\n'
                ;;
        esac
    done
}

main() {
    ensure_root
    prepare_log
    check_core_commands

    INSTALLED=()
    SKIPPED=()
    FAILED=()

    GENERAL_TOOLS=()
    NETWORK_TOOLS=()
    WEB_TOOLS=()
    REVERSE_TOOLS=()
    WINDOWS_TOOLS=()
    FORENSIC_TOOLS=()
    PASSWORD_TOOLS=()
    VULN_TOOLS=()
    OPTIONAL_TOOLS=()

    printf '\n'
    printf '============================================================\n'
    printf '  LINUX TÜRKÇE + PENTEST KURULUM YÖNETİCİSİ v%s\n' "$VERSION"
    printf '============================================================\n'
    printf '\n'

    #
    # SADECE İKİ SORU
    #

    local do_turkish=0
    local do_pentest=0

    if ask_yes_no 'Linux Türkçe yapılsın mı? [E/h]: '; then
        do_turkish=1
    fi

    if ask_yes_no 'Pentest araçları kurulsun mu? [E/h]: '; then
        do_pentest=1
    fi

    #
    # Distro kontrolü
    #

    if ! is_debian_family; then
        err "Bu script yalnızca Kali/Debian/Ubuntu için tasarlanmıştır."
        exit 1
    fi

    #
    # APT
    #

    info "APT hazırlanıyor..."

    if ! apt_update; then
        err "APT update başarısız."
        err "Ayrıntılı log:"
        err "$LOG_FILE"
        exit 1
    fi

    #
    # Türkçe
    #

    if ((do_turkish)); then

        info "Türkçe yapılandırma başlıyor..."

        backup_user_configs

        setup_locale
        setup_keyboard
        install_language_packages

    fi

    #
    # Pentest
    #

    if ((do_pentest)); then

        info "Pentest araçları kurulumu başlıyor..."

        install_pentest_stack

    fi

    #
    # Son onarım
    #

    post_install_repair

    #
    # Sonuç
    #

    summary
}

main "$@"
