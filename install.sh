#!/usr/bin/env bash
# ==============================================================================
# ARCH EXTREME [V9] - Ultimate Power-User Arch Linux Installer
# 8-Stage Startup Configurator | Laptop Ultra-Battery Mode | Max Overdrive
# Multi-Kernel Selection | Curated 10-App Suite | Zen/Btrfs/Snapper/Hungarian
# ==============================================================================

set -euo pipefail

SCRIPT_VERSION="V9"

# 1. Pre-flight Checks & Stale Mount Cleanup
if [[ $EUID -ne 0 ]]; then
    echo "[-] Error: Run this script as root from the Arch live ISO." >&2
    exit 1
fi

if [[ ! -d /sys/firmware/efi/efivars ]]; then
    echo "[-] Error: UEFI mode not detected. Enable UEFI in BIOS." >&2
    exit 1
fi

if ! ping -c 1 archlinux.org &>/dev/null; then
    echo "[-] Error: No network connectivity. Run 'iwctl' or connect Ethernet." >&2
    exit 1
fi

echo "[*] Cleaning up potential stale mounts from prior attempts..."
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

clear
cat << "BANNER"
 █████╗ ██████╗  ██████╗██╗  ██╗    ███████╗██╗  ██╗████████╗██████╗ ███████╗███╗   ███╗███████╗    ██╗   ██╗ ██████╗ 
██╔══██╗██╔══██╗██╔════╝██║  ██║    ██╔════╝╚██╗██╔╝╚══██╔══╝██╔══██╗██╔════╝████╗ ████║██╔════╝    ██║   ██║██╔════╝ 
███████║██████╔╝██║     ███████║    █████╗   ╚███╔╝    ██║   ██████╔╝█████╗  ██╔████╔██║█████╗      ██║   ██║╚█████╗  
██╔══██║██╔══██╗██║     ██╔══██║    ██╔══╝   ██╔██╗    ██║   ██╔══██╗██╔══╝  ██║╚██╔╝██║██╔══╝      ╚██╗ ██╔╝ ╚═══██╗ 
██║  ██║██║  ██║╚██████╗██║  ██║    ███████╗██╔╝ ██╗   ██║   ██║  ██║███████╗██║ ╚═╝ ██║███████╗     ╚████╔╝ ██████╔╝ 
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝      ╚═══╝  ╚═════╝  
BANNER
echo "                         === ARCH EXTREME [$SCRIPT_VERSION] ==="
echo "                  Interactive 8-Stage System Configurator       "
echo ""

# ==============================================================================
# 8 STARTUP CHOICES & SYSTEM CONFIGURATION
# ==============================================================================

# --- CHOICE 1: Storage Disk Selection ---
echo "--- [CHOICE 1/8] Storage Disk Selection ---"
lsblk -dpno NAME,SIZE,TYPE,MODEL | grep -E "disk"
echo ""
read -rp "Enter target disk path (e.g., /dev/nvme0n1 or /dev/sda): " DISK
if [[ ! -b "$DISK" ]]; then
    echo "[-] Error: Block device '$DISK' not found." >&2
    exit 1
fi
echo ""
echo "[!] DANGER: ALL PARTITIONS ON $DISK WILL BE PURGED AND OVERWRITTEN."
read -rp "Type 'DESTROY' to proceed: " CONFIRM_DESTROY
if [[ "$CONFIRM_DESTROY" != "DESTROY" ]]; then
    echo "[-] Aborted by user."
    exit 0
fi

# --- CHOICE 2: Linux Kernel Selection ---
echo ""
echo "--- [CHOICE 2/8] Linux Kernel Architecture ---"
echo "  1) linux-zen      (Low latency, responsive desktop scheduler) [Recommended]"
echo "  2) linux          (Standard upstream Arch kernel)"
echo "  3) linux-lts      (Long-Term Support, maximum driver stability)"
read -rp "Select Kernel [1-3, default: 1]: " KERNEL_CHOICE
case "${KERNEL_CHOICE:-1}" in
    2) KERNEL_PKG="linux"; KERNEL_HEADERS="linux-headers" ;;
    3) KERNEL_PKG="linux-lts"; KERNEL_HEADERS="linux-lts-headers" ;;
    *) KERNEL_PKG="linux-zen"; KERNEL_HEADERS="linux-zen-headers" ;;
esac

# --- CHOICE 3: Optimization & Power Profile ---
echo ""
echo "--- [CHOICE 3/8] Performance & Battery Profile ---"
echo "  1) MAX OVERDRIVE        (Desktop/AC: Uncapped CPU, mitigations=off, ultra-low audio latency)"
echo "  2) BALANCED             (Standard responsive desktop tuning with safe security)"
echo "  3) LAPTOP ULTRA ECO     (Max Battery: No Turbo spikes, Intel EPP power-save, Powertop autotune,"
echo "                           PCIe ASPM, audio/wifi sleep, and Nvidia 0W idle RTD3 power-gating)"
read -rp "Select Profile [1-3, default: 1]: " OPT_CHOICE
OPT_TIER="${OPT_CHOICE:-1}"

# --- CHOICE 4: GPU Driver Stack ---
echo ""
echo "--- [CHOICE 4/8] Graphics Driver Architecture ---"
echo "  1) nvidia-open-dkms (Turing / RTX 2000, GTX 1600 & newer architectures) [Recommended]"
echo "  2) nvidia-dkms      (Pascal / GTX 1000, GTX 900 & legacy cards)"
echo "  3) Intel iGPU Only  (Pure Intel QuickSync, no Nvidia modules loaded)"
read -rp "Select GPU Driver [1-3, default: 1]: " NVIDIA_CHOICE
case "${NVIDIA_CHOICE:-1}" in
    2) GPU_PROFILE="nvidia-legacy" ;;
    3) GPU_PROFILE="intel-only" ;;
    *) GPU_PROFILE="nvidia-open" ;;
esac

# --- CHOICE 5: Language, Locales & Keyboard ---
echo ""
echo "--- [CHOICE 5/8] Language & Regional Localization ---"
echo "  1) English UI + Hungarian Formats/Dates + Hungarian 105-key Keyboard (Recommended)"
echo "  2) Full Hungarian Environment (Hungarian UI, Formats, Keyboard)"
read -rp "Select Locale [1 or 2, default: 1]: " LOCALE_CHOICE
LOCALE_PROFILE="${LOCALE_CHOICE:-1}"

# --- CHOICE 6: SDDM Login Screen Theme ---
echo ""
echo "--- [CHOICE 6/8] SDDM Login Greeter Theme ---"
echo "  1) Astronaut Theme (Modern frosted glass, animated card, custom typography) [Recommended]"
echo "  2) Breeze Theme    (Stock KDE display manager)"
read -rp "Select Theme [1 or 2, default: 1]: " SDDM_THEME_CHOICE
SDDM_THEME="${SDDM_THEME_CHOICE:-1}"

# --- CHOICE 7: SDDM Auto-Login ---
echo ""
echo "--- [CHOICE 7/8] SDDM Session Auto-Login ---"
echo "  1) Require Password (Standard display manager lock)"
echo "  2) Enable Auto-Login (Bypass login screen, instant desktop boot)"
read -rp "Select Option [1 or 2, default: 1]: " AUTOLOGIN_CHOICE
SDDM_AUTOLOGIN="${AUTOLOGIN_CHOICE:-1}"

# --- CHOICE 8: Preinstalled Application Suite ---
echo ""
echo "--- [CHOICE 8/8] Curated Preinstalled Application Suite ---"
echo "  [1]  Firefox          (Hardened browser with VA-API hardware decode)"
echo "  [2]  Steam            (Vulkan & 32-bit gaming libraries ready)"
echo "  [3]  Lutris + Wine    (Wine-Staging + winetricks for non-Steam games)"
echo "  [4]  Discord          (Preconfigured for native Wayland execution)"
echo "  [5]  VS Code (OSS)    (Code - OSS binary with development tools)"
echo "  [6]  Spotify          (Official native desktop launcher)"
echo "  [7]  OBS Studio       (Screen recording with NVENC / QuickSync support)"
echo "  [8]  qBittorrent      (Fast torrent client without adware)"
echo "  [9]  LibreOffice      (Full office suite - Fresh release)"
echo "  [10] GIMP             (Image manipulation and photo editing)"
echo ""
echo "Enter app numbers separated by spaces (e.g., '1 2 4 5 7'), 'all', or 'none'."
read -rp "Select Apps [Default: 1 2 4]: " SELECTED_APPS
SELECTED_APPS="${SELECTED_APPS:-1 2 4}"

APP_PKGS=()

if [[ "$SELECTED_APPS" == "all" ]]; then
    SELECTED_APPS="1 2 3 4 5 6 7 8 9 10"
fi

if [[ "$SELECTED_APPS" != "none" ]]; then
    for item in $SELECTED_APPS; do
        case "$item" in
            1) APP_PKGS+=(firefox) ;;
            2) APP_PKGS+=(steam) ;;
            3) APP_PKGS+=(lutris wine-staging winetricks giflib) ;;
            4) APP_PKGS+=(discord) ;;
            5) APP_PKGS+=(code) ;;
            6) APP_PKGS+=(spotify-launcher) ;;
            7) APP_PKGS+=(obs-studio) ;;
            8) APP_PKGS+=(qbittorrent) ;;
            9) APP_PKGS+=(libreoffice-fresh) ;;
            10) APP_PKGS+=(gimp) ;;
        esac
    done
fi

# Credentials & Hostname
echo ""
echo "--- User & System Credentials ---"
read -rp "System Hostname: " HOSTNAME
read -rp "Username: " USERNAME

while true; do
    IFS= read -rsp "Password for $USERNAME: " USER_PASS
    echo ""
    IFS= read -rsp "Confirm password for $USERNAME: " USER_PASS_CONFIRM
    echo ""
    [[ "$USER_PASS" == "$USER_PASS_CONFIRM" && -n "$USER_PASS" ]] && break
    echo "[-] Passwords do not match or are empty. Try again."
done

while true; do
    IFS= read -rsp "Root Password: " ROOT_PASS
    echo ""
    IFS= read -rsp "Confirm Root Password: " ROOT_PASS_CONFIRM
    echo ""
    [[ "$ROOT_PASS" == "$ROOT_PASS_CONFIRM" && -n "$ROOT_PASS" ]] && break
    echo "[-] Passwords do not match or are empty. Try again."
done

# ==============================================================================
# DISK PARTITIONING & BTRFS SUBVOLUMES
# ==============================================================================
echo ""
echo "[*] Creating GPT tables and partitioning $DISK..."
wipefs -af "$DISK"
sgdisk -Zo "$DISK"

sgdisk -n 1:0:+1G -t 1:ef00 "$DISK" # EFI Boot
sgdisk -n 2:0:0 -t 2:8300 "$DISK"   # Btrfs Root

if [[ "$DISK" =~ [0-9]$ ]]; then
    BOOT_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
else
    BOOT_PART="${DISK}1"
    ROOT_PART="${DISK}2"
fi

partprobe "$DISK"
sleep 2

echo "[*] Formatting partitions..."
mkfs.fat -F32 -n "EFI" "$BOOT_PART"
mkfs.btrfs -f -L "ARCH_ROOT" "$ROOT_PART"

# Create Btrfs subvolumes
mount "$ROOT_PART" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache
btrfs subvolume create /mnt/@var_tmp
umount /mnt

BTRFS_OPTS="rw,noatime,compress=zstd:2,space_cache=v2,discard=async"

mount -o "$BTRFS_OPTS,subvol=@" "$ROOT_PART" /mnt
mkdir -p /mnt/{boot,home,.snapshots,var/log,var/cache,var/tmp}
mount -o "$BTRFS_OPTS,subvol=@home" "$ROOT_PART" /mnt/home
mount -o "$BTRFS_OPTS,subvol=@snapshots" "$ROOT_PART" /mnt/.snapshots
mount -o "$BTRFS_OPTS,subvol=@var_log" "$ROOT_PART" /mnt/var/log
mount -o "$BTRFS_OPTS,subvol=@var_cache" "$ROOT_PART" /mnt/var/cache
mount -o "$BTRFS_OPTS,subvol=@var_tmp" "$ROOT_PART" /mnt/var/tmp
mount "$BOOT_PART" /mnt/boot

chattr +C /mnt/var/log 2>/dev/null || true
chattr +C /mnt/var/cache 2>/dev/null || true
chattr +C /mnt/var/tmp 2>/dev/null || true

# ==============================================================================
# PACMAN MIRRORS & PACKAGE STRAPPING
# ==============================================================================
echo "[*] Initializing live pacman keyring & multilib..."
pacman-key --init 2>/dev/null || true
pacman-key --populate archlinux 2>/dev/null || true
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
pacman -Sy --noconfirm archlinux-keyring

echo "[*] Running pacstrap for selected kernel ($KERNEL_PKG) & base system..."
BASE_PKGS=(
    base base-devel "$KERNEL_PKG" "$KERNEL_HEADERS" linux-firmware intel-ucode
    btrfs-progs dosfstools e2fsprogs git nano bash-completion curl wget
    networkmanager grub efibootmgr grub-btrfs inotify-tools snapper snap-pac
    zram-generator pacman-contrib ufw thermald irqbalance power-profiles-daemon
    gamemode lib32-gamemode bluez bluez-utils xdg-user-dirs powertop
)

GRAPHICS_PKGS=(mesa vulkan-intel intel-media-driver libva-intel-driver libva-utils)
if [[ "$GPU_PROFILE" == "nvidia-open" ]]; then
    GRAPHICS_PKGS+=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings nvidia-prime libva-nvidia-driver vdpauinfo)
elif [[ "$GPU_PROFILE" == "nvidia-legacy" ]]; then
    GRAPHICS_PKGS+=(nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings nvidia-prime libva-nvidia-driver vdpauinfo)
fi

MULTIMEDIA_CODECS=(
    pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
    ffmpeg mpv yt-dlp gst-plugins-base gst-plugins-good gst-plugins-bad
    gst-plugins-ugly gst-libav ffmpegthumbs kdegraphics-thumbnailers
)

KDE_LEAN=(
    plasma-desktop plasma-workspace plasma-nm plasma-pa powerdevil kscreen bluedevil
    breeze breeze-gtk kde-gtk-config polkit-kde-agent qt6-wayland qt5-wayland
    qt6-5compat qt6-declarative qt6-svg qt6-multimedia
    sddm sddm-kcm konsole dolphin ark kate spectacle
)

POWER_TOOLS_AND_FONTS=(
    btop fastfetch fzf zoxide ripgrep bat eza
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd hunspell-hu
)

pacstrap -K /mnt \
    "${BASE_PKGS[@]}" \
    "${GRAPHICS_PKGS[@]}" \
    "${MULTIMEDIA_CODECS[@]}" \
    "${KDE_LEAN[@]}" \
    "${POWER_TOOLS_AND_FONTS[@]}" \
    "${APP_PKGS[@]}"

genfstab -U /mnt >> /mnt/etc/fstab

mkdir -p /mnt/etc
cp -L /etc/resolv.conf /mnt/etc/resolv.conf 2>/dev/null || true

# ==============================================================================
# CHROOT POST-INSTALL CONFIGURATION
# ==============================================================================
cat << 'CHROOT_SCRIPT' > /mnt/root/setup_chroot.sh
#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="$1"
USERNAME="$2"
LOCALE_PROFILE="$3"
GPU_PROFILE="$4"
KERNEL_PKG="$5"
OPT_TIER="$6"
SDDM_THEME="$7"
SDDM_AUTOLOGIN="$8"

# Timezone & Hardware Clock
ln -sf /usr/share/zoneinfo/Europe/Budapest /etc/localtime
hwclock --systohc

# Localization
sed -i 's/^#hu_HU.UTF-8 UTF-8/hu_HU.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

if [[ "$LOCALE_PROFILE" == "2" ]]; then
    cat <<LOC > /etc/locale.conf
LANG=hu_HU.UTF-8
LC_COLLATE=C
LOC
else
    cat <<LOC > /etc/locale.conf
LANG=en_US.UTF-8
LC_TIME=hu_HU.UTF-8
LC_NUMERIC=hu_HU.UTF-8
LC_MONETARY=hu_HU.UTF-8
LC_PAPER=hu_HU.UTF-8
LC_MEASUREMENT=hu_HU.UTF-8
LOC
fi

# Hungarian Keyboards: TTY, X11, Display Manager
cat <<VCON > /etc/vconsole.conf
KEYMAP=hu
FONT=lat2-16
FONT_MAP=8859-2
VCON

mkdir -p /etc/X11/xorg.conf.d
cat <<XKB > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "hu,us"
        Option "XkbModel" "pc105"
        Option "XkbVariant" "qwertz,"
        Option "XkbOptions" "grp:alt_shift_toggle"
EndSection
XKB

mkdir -p /etc/default
cat <<KBD > /etc/default/keyboard
XKBLAYOUT="hu,us"
XKBMODEL="pc105"
XKBVARIANT="qwertz,"
XKBOPTIONS="grp:alt_shift_toggle"
KBD

echo "$HOSTNAME" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# Multilib & Pacman Visuals
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
pacman -Sy --noconfirm
ldconfig

# Makepkg Optimizations
sed -i 's/^#MAKEFLAGS="-j2"/MAKEFLAGS="-j\$(nproc)"/' /etc/makepkg.conf
sed -i 's/^COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -z -q --threads=0 -)/' /etc/makepkg.conf

if [[ "$OPT_TIER" == "1" ]]; then
    sed -i 's/-march=x86-64 -mtune=generic/-march=native -O3 -pipe -fno-plt -fexceptions/' /etc/makepkg.conf
fi

# User & Sudo Setup
useradd -m -G wheel,video,audio,storage,gamemode -s /bin/bash "$USERNAME"
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel_temp

sudo -u "$USERNAME" xdg-user-dirs-update || true
sudo -u "$USERNAME" kwriteconfig6 --file baloofilerc --group "Basic Settings" --key "Indexing-Enabled" false || true

# User KDE Keyboard (Hungarian default + US secondary with Alt+Shift)
sudo -u "$USERNAME" kwriteconfig6 --file kxkbrc --group "Layout" --key "Use" "true"
sudo -u "$USERNAME" kwriteconfig6 --file kxkbrc --group "Layout" --key "LayoutList" "hu,us"
sudo -u "$USERNAME" kwriteconfig6 --file kxkbrc --group "Layout" --key "LayoutLooping" "true"
sudo -u "$USERNAME" kwriteconfig6 --file kxkbrc --group "Layout" --key "Model" "pc105"
sudo -u "$USERNAME" kwriteconfig6 --file kxkbrc --group "Layout" --key "Options" "grp:alt_shift_toggle"
sudo -u "$USERNAME" kwriteconfig6 --file kxkbrc --group "Layout" --key "DisplayNames" "HU,US"

# AUR Helper Setup
echo "[*] Building and configuring AUR helper..."
AUR_TOOL=""
if sudo -u "$USERNAME" bash -c '
    cd /tmp
    rm -rf paru-bin
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
    rm -rf /tmp/paru-bin
'; then
    if sudo -u "$USERNAME" paru --version &>/dev/null; then
        AUR_TOOL="paru"
    else
        ACTIVE_ALPM=$(ls -1 /usr/lib/libalpm.so.* 2>/dev/null | grep -E 'libalpm\.so\.[0-9]+$' | head -n 1)
        if [[ -n "$ACTIVE_ALPM" ]]; then
            ln -sf "$ACTIVE_ALPM" /usr/lib/libalpm.so.15
            ln -sf "$ACTIVE_ALPM" /usr/lib/libalpm.so.14
            ldconfig
        fi
        [[ $(sudo -u "$USERNAME" paru --version 2>/dev/null) ]] && AUR_TOOL="paru"
    fi
fi

if [[ -z "$AUR_TOOL" ]]; then
    echo "[-] Deploying yay-bin (standalone fallback)..."
    pacman -Rns --noconfirm paru-bin 2>/dev/null || true
    sudo -u "$USERNAME" bash -c '
        cd /tmp
        rm -rf yay-bin
        git clone https://aur.archlinux.org/yay-bin.git
        cd yay-bin
        makepkg -si --noconfirm
        rm -rf /tmp/yay-bin
    '
    AUR_TOOL="yay"
fi

# Ananicy-CPP + CachyOS Community Rules
echo "[*] Installing Ananicy-CPP via $AUR_TOOL..."
sudo -u "$USERNAME" "$AUR_TOOL" -S --noconfirm ananicy-cpp || true

if command -v ananicy-cpp &>/dev/null; then
    mkdir -p /etc/ananicy.d
    if git clone --depth=1 https://github.com/CachyOS/ananicy-rules.git /tmp/cachyos-rules 2>/dev/null; then
        cp -rn /tmp/cachyos-rules/* /etc/ananicy.d/ 2>/dev/null || true
        rm -rf /tmp/cachyos-rules
    fi
    systemctl enable ananicy-cpp.service
fi

rm -f /etc/sudoers.d/wheel_temp
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Snapper & Grub-Btrfs Integration
echo "[*] Initializing Snapper & Grub-Btrfs..."
umount /.snapshots 2>/dev/null || true
rm -rf /.snapshots
snapper --no-dbus -c root create-config /
btrfs subvolume delete /.snapshots
mkdir -p /.snapshots
mount /.snapshots
chmod 750 /.snapshots
chown :wheel /.snapshots

sed -i 's/^TIMELINE_MIN_AGE="1800"/TIMELINE_MIN_AGE="1800"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_WEEKLY="0"/TIMELINE_LIMIT_WEEKLY="0"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_YEARLY="0"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

snapper --no-dbus -c root create -d "ARCH_EXTREME_V9_BASE" || true

systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable grub-btrfsd.service

# GPU & Early KMS Configuration
if [[ "$GPU_PROFILE" != "intel-only" ]]; then
    cat <<MODPROBE > /etc/modprobe.d/nvidia.conf
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
options nvidia NVreg_DynamicPowerManagement=0x02
options nvidia-drm modeset=1 fbdev=1
MODPROBE

    mkdir -p /etc/pacman.d/hooks
    cat <<HOOK > /etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia*
Target=$KERNEL_PKG

[Action]
Description=Rebuilding initramfs after Nvidia or Kernel update...
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/usr/bin/mkinitcpio -P
HOOK

    sed -i 's/^MODULES=()/MODULES=(btrfs i915 xe nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    systemctl enable nvidia-suspend.service
    systemctl enable nvidia-hibernate.service
    systemctl enable nvidia-resume.service
    systemctl enable nvidia-persistenced.service

    cat <<ENV >> /etc/environment
LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
MOZ_DISABLE_RDD_SANDBOX=1
__GLX_VENDOR_LIBRARY_NAME=nvidia
GBM_BACKEND=nvidia-drm
ENV
else
    sed -i 's/^MODULES=()/MODULES=(btrfs i915 xe)/' /etc/mkinitcpio.conf
fi

mkinitcpio -P

cat <<ENV >> /etc/environment
ELECTRON_OZONE_PLATFORM_HINT=auto
QT_QPA_PLATFORM=wayland;xcb
ENV

# SDDM Theme & Auto-Login Configuration
mkdir -p /etc/sddm.conf.d
if [[ "$SDDM_THEME" == "1" ]]; then
    echo "[*] Installing Astronaut SDDM Theme..."
    mkdir -p /usr/share/sddm/themes
    if git clone --depth=1 https://github.com/Keyitdev/sddm-astronaut-theme.git /usr/share/sddm/themes/astronaut 2>/dev/null; then
        mkdir -p /usr/share/fonts/TTF
        cp -rn /usr/share/sddm/themes/astronaut/Fonts/* /usr/share/fonts/TTF/ 2>/dev/null || true
        fc-cache -f 2>/dev/null || true
        cat <<THEME_CONF > /etc/sddm.conf.d/theme.conf
[Theme]
Current=astronaut
CursorTheme=breeze_cursors
Font="JetBrainsMono Nerd Font"
THEME_CONF
    fi
fi

cat <<SDDM > /etc/sddm.conf.d/wayland.conf
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
InputMethod=
SDDM

if [[ "$SDDM_AUTOLOGIN" == "2" ]]; then
    cat <<AUTOLOGIN > /etc/sddm.conf.d/autologin.conf
[Autologin]
User=$USERNAME
Session=plasma
AUTOLOGIN
fi

# MPV Player Hardware Acceleration
mkdir -p /etc/mpv
cat <<MPV > /etc/mpv/mpv.conf
hwdec=auto-safe
vo=gpu-next
gpu-api=vulkan
profile=fast
cache=yes
demuxer-max-bytes=200MiB
ytdl-format=bestvideo[height<=?1080]+bestaudio/best
MPV

# ==============================================================================
# [V9 PATCH] LAPTOP ULTRA-BATTERY & POWER PROFILES CONFIGURATION
# ==============================================================================
if [[ "$OPT_TIER" == "3" ]]; then
    echo "[*] Configuring Laptop Ultra-Battery optimization suite..."

    # 1. Disable CPU Turbo Boost spikes on battery via dynamic udev power rule
    cat << 'UDEV_POWER' > /etc/udev/rules.d/99-battery-powersave.rules
# Battery detected: Disable aggressive CPU turbo boost & switch to power saving EPP
SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="/usr/bin/bash -c 'echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null; for i in /sys/devices/system/cpu/cpu*/power/energy_performance_preference; do echo power > \"$i\" 2>/dev/null; done'"

# AC adapter plugged in: Restore turbo boost and switch to balance_performance
SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="/usr/bin/bash -c 'echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null; for i in /sys/devices/system/cpu/cpu*/power/energy_performance_preference; do echo balance_performance > \"$i\" 2>/dev/null; done'"
UDEV_POWER

    # 2. Nvidia RTD3 Runtime PM: Fully cut power to discrete Nvidia GPU when idle (0 Watts draw)
    if [[ "$GPU_PROFILE" != "intel-only" ]]; then
        cat <<UDEV_NV > /etc/udev/rules.d/80-nvidia-pm.rules
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto"
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto"
UDEV_NV
    fi

    # 3. Audio Codec Power-Down after 1 second of silence
    mkdir -p /etc/modprobe.d
    cat <<AUDIO_PM > /etc/modprobe.d/audio_powersave.conf
options snd_hda_intel power_save=1 power_save_controller=Y
AUDIO_PM

    # 4. NetworkManager: Enable 802.11 Power Saving
    mkdir -p /etc/NetworkManager/conf.d
    cat <<WIFI_PM > /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
[connection]
wifi.powersave = 3
WIFI_PM

    # 5. Powertop Auto-Tune Systemd Service (PCIe ASPM, SATA Link Power, USB Autosuspend)
    cat <<POWERTOP_SVC > /etc/systemd/system/powertop.service
[Unit]
Description=Powertop tunings on boot
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/powertop --auto-tune

[Install]
WantedBy=multi-user.target
POWERTOP_SVC
    systemctl enable powertop.service
fi

# Bootloader (GRUB)
sed -i 's/^#GRUB_SAVEDEFAULT="true"/GRUB_SAVEDEFAULT="false"/' /etc/default/grub
sed -i 's/^#GRUB_PRELOAD_MODULES=".*"/GRUB_PRELOAD_MODULES="btrfs"/' /etc/default/grub

BASE_CMDLINE="loglevel=3 quiet nowatchdog transparent_hugepage=madvise cpufreq.default_governor=schedutil"
if [[ "$GPU_PROFILE" != "intel-only" ]]; then
    BASE_CMDLINE="$BASE_CMDLINE nvidia-drm.modeset=1 nvidia_drm.fbdev=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"
fi

if [[ "$OPT_TIER" == "1" ]]; then
    BASE_CMDLINE="$BASE_CMDLINE mitigations=off split_lock_mitigate=0 isolcpus= managed_irq"
elif [[ "$OPT_TIER" == "3" ]]; then
    # LAPTOP ULTRA ECO: Force PCIe ASPM power saving and NMI watchdog sleep
    BASE_CMDLINE="$BASE_CMDLINE split_lock_mitigate=0 pcie_aspm=force pcie_aspm.policy=powersave nmi_watchdog=0"
else
    BASE_CMDLINE="$BASE_CMDLINE split_lock_mitigate=0"
fi

sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$BASE_CMDLINE\"|" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchLinux --removable
grub-mkconfig -o /boot/grub/grub.cfg

# PipeWire Low Latency
mkdir -p /etc/pipewire/pipewire.conf.d
if [[ "$OPT_TIER" == "1" ]]; then
    PW_QUANTUM=64
elif [[ "$OPT_TIER" == "3" ]]; then
    # 256 quantum buffer: reduces CPU wakeups while keeping audio latency unnoticeable
    PW_QUANTUM=256
else
    PW_QUANTUM=128
fi

cat <<PW > /etc/pipewire/pipewire.conf.d/99-lowlatency.conf
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = $PW_QUANTUM
    default.clock.min-quantum = 32
    default.clock.max-quantum = 1024
}
PW

# ZRAM Swap Configuration
cat <<ZRAM > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
ZRAM

# Performance Sysctl Configuration
cat <<SYSCTL > /etc/sysctl.d/99-performance.conf
vm.swappiness = 150
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.page-cluster = 0
net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
fs.file-max = 2097152
SYSCTL

# Extended dirty writeback for Laptop Ultra Eco (avoids spinning disks / waking CPU cores every 5s)
if [[ "$OPT_TIER" == "3" ]]; then
    echo "vm.dirty_writeback_centisecs = 6000" >> /etc/sysctl.d/99-performance.conf
fi

# Dynamic I/O Schedulers
cat <<UDEV > /etc/udev/rules.d/60-ioschedulers.rules
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
UDEV

# Firewall Configuration
ufw default deny incoming
ufw default allow outgoing

# Shell Aliases
cat <<'BASHRC' >> "/home/$USERNAME/.bashrc"
alias ls='eza --icons'
alias ll='eza -lh --icons --git'
alias la='eza -lha --icons --git'
alias cat='bat --style=plain'
alias fetch='fastfetch'
BASHRC
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.bashrc"

# Enable System Services
systemctl enable sddm.service
systemctl enable NetworkManager.service
systemctl enable bluetooth.service
systemctl enable systemd-timesyncd.service
systemctl enable fstrim.timer
systemctl enable power-profiles-daemon.service
systemctl enable thermald.service
systemctl enable irqbalance.service
systemctl enable paccache.timer
systemctl enable ufw.service
systemctl mask NetworkManager-wait-online.service
CHROOT_SCRIPT

chmod +x /mnt/root/setup_chroot.sh
arch-chroot /mnt /root/setup_chroot.sh \
    "$HOSTNAME" "$USERNAME" "$LOCALE_PROFILE" "$GPU_PROFILE" \
    "$KERNEL_PKG" "$OPT_TIER" "$SDDM_THEME" "$SDDM_AUTOLOGIN"
rm /mnt/root/setup_chroot.sh

# Apply passwords safely through chroot stdin
echo "[*] Applying user and root credentials..."
printf "root:%s\n" "$ROOT_PASS" | arch-chroot /mnt chpasswd
printf "%s:%s\n" "$USERNAME" "$USER_PASS" | arch-chroot /mnt chpasswd

# 7. Unmount & Finalize
echo "[*] Syncing buffers and unmounting subvolumes..."
umount -R /mnt

echo ""
echo "===================================================================="
echo "    ARCH EXTREME [$SCRIPT_VERSION] Successfully Installed!         "
echo "    Reboot, unplug the installation USB, and log in.                "
echo "===================================================================="
