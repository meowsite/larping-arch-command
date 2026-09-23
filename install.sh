#!/usr/bin/env bash
# ==============================================================================
# Arch Linux Ultimate Power-User Installer
# Zen Kernel | Btrfs + Snapper Rollbacks | NVDEC & QuickSync HW Video | Paru AUR
# Ananicy-CPP | UFW Firewall | Hungarian Stack | Extreme Latency & Desktop Tuning
# ==============================================================================

set -euo pipefail

# 1. Pre-flight Checks
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

clear
cat << "BANNER"
 █████╗ ██████╗  ██████╗██╗  ██╗    ███████╗██╗  ██╗████████╗██████╗ ███████╗███╗   ███╗███████╗
██╔══██╗██╔══██╗██╔════╝██║  ██║    ██╔════╝╚██╗██╔╝╚══██╔══╝██╔══██╗██╔════╝████╗ ████║██╔════╝
███████║██████╔╝██║     ███████║    █████╗   ╚███╔╝    ██║   ██████╔╝█████╗  ██╔████╔██║█████╗  
██╔══██║██╔══██╗██║     ██╔══██║    ██╔══╝   ██╔██╗    ██║   ██╔══██╗██╔══╝  ██║╚██╔╝██║██╔══╝  
██║  ██║██║  ██║╚██████╗██║  ██║    ███████╗██╔╝ ██╗   ██║   ██║  ██║███████╗██║ ╚═╝ ██║███████╗
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝
BANNER
echo ""

# 2. Disk Selection
echo "[*] Storage devices detected:"
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

# 3. Credentials & Settings
echo ""
read -rp "System Hostname: " HOSTNAME
read -rp "Username: " USERNAME

while true; do
    read -rsp "Password for $USERNAME: " USER_PASS
    echo ""
    read -rsp "Confirm password for $USERNAME: " USER_PASS_CONFIRM
    echo ""
    [[ "$USER_PASS" == "$USER_PASS_CONFIRM" && -n "$USER_PASS" ]] && break
    echo "[-] Passwords do not match. Try again."
done

while true; do
    read -rsp "Root Password: " ROOT_PASS
    echo ""
    read -rsp "Confirm Root Password: " ROOT_PASS_CONFIRM
    echo ""
    [[ "$ROOT_PASS" == "$ROOT_PASS_CONFIRM" && -n "$ROOT_PASS" ]] && break
    echo "[-] Passwords do not match. Try again."
done

echo ""
echo "Select Language & Locale Setup:"
echo "  1) English UI + Hungarian Formats/Dates + Hungarian Keyboard (Recommended)"
echo "  2) Full Hungarian Environment (Hungarian UI, Formats, Keyboard)"
read -rp "Select [1 or 2, default: 1]: " LOCALE_CHOICE

echo ""
echo "Select Nvidia Driver Variant:"
echo "  1) nvidia-open-dkms (Turing / RTX 2000, GTX 1600 & newer architectures)"
echo "  2) nvidia-dkms      (Pascal / GTX 1000 & older)"
read -rp "Select [1 or 2, default: 1]: " NVIDIA_CHOICE
if [[ "$NVIDIA_CHOICE" == "2" ]]; then
    NVIDIA_PKG="nvidia-dkms"
else
    NVIDIA_PKG="nvidia-open-dkms"
fi

# 4. Partitioning & Subvolumes (Snapper-Compliant Btrfs Tree)
echo ""
echo "[*] Creating GPT tables and partitions..."
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

mkfs.fat -F32 -n "EFI" "$BOOT_PART"
mkfs.btrfs -f -L "ARCH_ROOT" "$ROOT_PART"

# Create canonical Btrfs subvolumes for Snapper rollback compatibility
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

# 5. Package Installation
echo "[*] Initializing pacman and pulling base package tree..."
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf

BASE_PKGS=(
    base base-devel linux-zen linux-zen-headers linux-firmware intel-ucode
    btrfs-progs dosfstools e2fsprogs git nano bash-completion curl wget
    networkmanager grub efibootmgr grub-btrfs inotify-tools snapper snap-pac
    zram-generator pacman-contrib ufw thermald irqbalance power-profiles-daemon
    gamemode lib32-gamemode
)

INTEL_NVIDIA_VIDEO=(
    mesa vulkan-intel intel-media-driver libva-intel-driver libva-utils
    "$NVIDIA_PKG" nvidia-utils lib32-nvidia-utils nvidia-settings nvidia-prime
    libva-nvidia-driver vdpauinfo
)

MULTIMEDIA_CODECS=(
    pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
    ffmpeg mpv yt-dlp gst-plugins-base gst-plugins-good gst-plugins-bad
    gst-plugins-ugly gst-libav ffmpegthumbs kdegraphics-thumbnailers
)

# Stripped-down KDE Plasma: Zero telemetry, zero PIM/Akonadi bloat
KDE_LEAN=(
    plasma-desktop plasma-nm plasma-pa powerdevil kscreen bluedevil
    breeze breeze-gtk kde-gtk-config polkit-kde-agent
    sddm sddm-kcm konsole dolphin ark kate spectacle
)

POWER_TOOLS_AND_FONTS=(
    btop fastfetch fzf zoxide ripgrep bat eza
    noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd hunspell-hu
)

pacstrap -K /mnt \
    "${BASE_PKGS[@]}" \
    "${INTEL_NVIDIA_VIDEO[@]}" \
    "${MULTIMEDIA_CODECS[@]}" \
    "${KDE_LEAN[@]}" \
    "${POWER_TOOLS_AND_FONTS[@]}"

genfstab -U /mnt >> /mnt/etc/fstab

# 6. Target Chroot Execution Script
cat <<EOF > /mnt/root/setup_chroot.sh
#!/usr/bin/env bash
set -euo pipefail

# Timezone & Hardware Clock
ln -sf /usr/share/zoneinfo/Europe/Budapest /etc/localtime
hwclock --systohc

# Hungarian & English Locales
sed -i 's/^#hu_HU.UTF-8 UTF-8/hu_HU.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

if [[ "$LOCALE_CHOICE" == "2" ]]; then
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

# Hungarian Console Font and Keymap
cat <<VCON > /etc/vconsole.conf
KEYMAP=hu
FONT=lat2-16
FONT_MAP=8859-2
VCON

# Hostname & Loopback
echo "$HOSTNAME" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# Enable Multilib & Pacman Quality-of-Life
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf

# Makepkg Optimizations: All CPU cores & max-threaded zstd packaging
sed -i 's/^#MAKEFLAGS="-j2"/MAKEFLAGS="-j\$(nproc)"/' /etc/makepkg.conf
sed -i 's/^COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -z -q --threads=0 -)/' /etc/makepkg.conf

# Users & Sudo Setup (Temporary NOPASSWD for automated Paru installation)
echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel,video,audio,storage,gamemode -s /bin/bash "$USERNAME"
echo "$USERNAME:$USER_PASS" | chpasswd
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel_temp

# Kill Baloo file indexer in KDE to save I/O and CPU
sudo -u "$USERNAME" kwriteconfig6 --file baloofilerc --group "Basic Settings" --key "Indexing-Enabled" false || true

# ==============================================================================
# AUR HELPER (PARU-BIN) & ANANICY-CPP INSTALLATION
# ==============================================================================
echo "[*] Building and installing Paru AUR Helper..."
sudo -u "$USERNAME" bash -c '
    cd /tmp
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
    rm -rf /tmp/paru-bin
'

echo "[*] Installing Ananicy-CPP & community rules for automatic game/thread priority..."
sudo -u "$USERNAME" paru -S --noconfirm ananicy-cpp ananicy-rules-git

# Restore strict sudo password check
rm -f /etc/sudoers.d/wheel_temp
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# ==============================================================================
# SNAPPER AUTOMATION & BOOTABLE ROLLBACKS VIA GRUB
# ==============================================================================
echo "[*] Initializing Snapper configuration..."
umount /.snapshots || true
rm -rf /.snapshots
snapper --no-dbus -c root create-config /
btrfs subvolume delete /.snapshots
mkdir -p /.snapshots
mount -o "$BTRFS_OPTS,subvol=@snapshots" "$ROOT_PART" /.snapshots
chmod 750 /.snapshots
chown :wheel /.snapshots

# Adjust Snapper retention limits (keep it lean: 5 hourly, 7 daily)
sed -i 's/^TIMELINE_MIN_AGE="1800"/TIMELINE_MIN_AGE="1800"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_WEEKLY="0"/TIMELINE_LIMIT_WEEKLY="0"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
sed -i 's/^TIMELINE_LIMIT_YEARLY="0"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
systemctl enable grub-btrfsd.service

# ==============================================================================
# NVIDIA POWER & WAYLAND STACK + HARDWARE DECODING
# ==============================================================================
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
Target=linux-zen

[Action]
Description=Auto-rebuilding initramfs after Nvidia or Zen kernel transaction...
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/usr/bin/mkinitcpio -P
HOOK

sed -i 's/^MODULES=()/MODULES=(btrfs i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
mkinitcpio -P

cat <<ENV >> /etc/environment
# Video Hardware Acceleration (NVDEC + QuickSync)
LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
MOZ_DISABLE_RDD_SANDBOX=1

# Native Wayland flags for apps (Electron, Qt, Firefox)
ELECTRON_OZONE_PLATFORM_HINT=auto
__GLX_VENDOR_LIBRARY_NAME=nvidia
GBM_BACKEND=nvidia-drm
QT_QPA_PLATFORM=wayland;xcb
ENV

# Optimized MPV Player Configuration (GPU Next + Direct Vulkan decoding)
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
# BOOTLOADER WITH LATENCY & SPLIT-LOCK MITIGATION TWEAKS
# ==============================================================================
# split_lock_mitigate=0: Eliminates severe FPS stutter in Steam/Wine games
# transparent_hugepage=madvise: Avoids background memory compaction spikes
GRUB_CMD="loglevel=3 quiet nvidia-drm.modeset=1 nvidia_drm.fbdev=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1 nowatchdog split_lock_mitigate=0 transparent_hugepage=madvise cpufreq.default_governor=schedutil"
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"\$GRUB_CMD\"|" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchLinux
grub-mkconfig -o /boot/grub/grub.cfg

# ==============================================================================
# AUDIO, KERNEL & NETWORK LATENCY TUNING
# ==============================================================================
# PipeWire Low Latency Config (128 buffer, 48kHz for low-latency desktop audio)
mkdir -p /etc/pipewire/pipewire.conf.d
cat <<PW > /etc/pipewire/pipewire.conf.d/99-lowlatency.conf
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 128
    default.clock.min-quantum = 64
    default.clock.max-quantum = 1024
}
PW

# ZRAM: 100% of RAM with ZSTD Compression
cat <<ZRAM > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
ZRAM

# Sysctl Performance Profiles
cat <<SYSCTL > /etc/sysctl.d/99-performance.conf
# Virtual Memory tuning
vm.swappiness = 150
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.page-cluster = 0

# Network: BBR + CAKE (Bufferbloat mitigation)
net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192

# File handles
fs.file-max = 2097152
SYSCTL

# Dynamic I/O Scheduler Rules (none for NVMe, BFQ for mechanical/SATA)
cat <<UDEV > /etc/udev/rules.d/60-ioschedulers.rules
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
UDEV

# Firewall Configuration (Strict incoming block, open outgoing)
ufw default deny incoming
ufw default allow outgoing

# User shell aliases (Fastfetch, eza, bat)
cat <<'BASHRC' >> "/home/$USERNAME/.bashrc"
alias ls='eza --icons'
alias ll='eza -lh --icons --git'
alias la='eza -lha --icons --git'
alias cat='bat --style=plain'
alias fetch='fastfetch'
BASHRC
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.bashrc"

# Enable Services
systemctl enable sddm.service
systemctl enable NetworkManager.service
systemctl enable fstrim.timer
systemctl enable power-profiles-daemon.service
systemctl enable thermald.service
systemctl enable irqbalance.service
systemctl enable paccache.timer
systemctl enable ananicy-cpp.service
systemctl enable ufw.service
systemctl enable nvidia-suspend.service
systemctl enable nvidia-hibernate.service
systemctl enable nvidia-resume.service
systemctl enable nvidia-persistenced.service
EOF

chmod +x /mnt/root/setup_chroot.sh
arch-chroot /mnt /root/setup_chroot.sh
rm /mnt/root/setup_chroot.sh

# 7. Unmount & Finalize
echo "[*] Syncing buffers and unmounting subvolumes..."
umount -R /mnt

echo ""
echo "===================================================================="
echo " Architecture deployed. Paru, Snapper, and Zen optimizations ready! "
echo " Reboot, unplug the installation USB, and enjoy your setup.         "
echo "===================================================================="
