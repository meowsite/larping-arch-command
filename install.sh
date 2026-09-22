#!/bin/bash

# Arch Linux Install Script
# RTX 3060 + Intel + KDE Plasma + Hungarian Localization
# Hostname: xby | Username: xby | Password: (space)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# ===== DISK SETUP =====
print_status "Arch Linux Installation Starting..."
print_status "Press ENTER to continue, or Ctrl+C to cancel"
read

# Display available disks
print_status "Available disks:"
lsblk -d -n -l -o NAME,SIZE,TYPE

print_status "Enter the disk to install to (e.g., sda, nvme0n1, vda):"
read DISK

if [ -z "$DISK" ]; then
    print_error "No disk selected"
    exit 1
fi

DISK_PATH="/dev/$DISK"

if [ ! -b "$DISK_PATH" ]; then
    print_error "Disk $DISK_PATH does not exist"
    exit 1
fi

print_warning "WARNING: All data on $DISK_PATH will be erased!"
print_status "Type 'yes' to continue:"
read CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_error "Installation cancelled"
    exit 1
fi

print_status "Wiping $DISK_PATH..."
wipefs -af "$DISK_PATH"

# Create partitions
print_status "Creating partitions..."
parted -s "$DISK_PATH" mklabel gpt
parted -s "$DISK_PATH" mkpart ESP fat32 1MiB 551MiB
parted -s "$DISK_PATH" set 1 esp on
parted -s "$DISK_PATH" mkpart primary ext4 551MiB 100%

# Determine partition names
if [[ "$DISK_PATH" =~ "nvme" ]]; then
    BOOT="${DISK_PATH}p1"
    ROOT="${DISK_PATH}p2"
else
    BOOT="${DISK_PATH}1"
    ROOT="${DISK_PATH}2"
fi

print_status "Formatting partitions..."
mkfs.fat -F 32 "$BOOT"
mkfs.ext4 -F "$ROOT"

print_success "Disk setup complete"

# ===== MOUNT & INSTALL =====
print_status "Mounting filesystems..."
mount "$ROOT" /mnt
mkdir -p /mnt/boot
mount "$BOOT" /mnt/boot

print_status "Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware intel-ucode

print_success "Base system installed"

# ===== CHROOT SETUP =====
print_status "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Create chroot installation script
CHROOT_SCRIPT="/mnt/chroot_install.sh"

cat > "$CHROOT_SCRIPT" << 'CHROOT_EOF'
#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# ===== LOCALIZATION =====
print_status "Configuring localization..."

# Set timezone
ln -sf /usr/share/zoneinfo/Europe/Budapest /etc/localtime
hwclock --systohc

# Generate Hungarian locales
sed -i 's/^#hu_HU.UTF-8/hu_HU.UTF-8/' /etc/locale.gen
sed -i 's/^#hu_HU.ISO8859-2/hu_HU.ISO8859-2/' /etc/locale.gen
locale-gen

# Set default locale
cat > /etc/locale.conf << EOF
LANG=hu_HU.UTF-8
LC_TIME=hu_HU.UTF-8
LC_COLLATE=C.UTF-8
EOF

# Set keyboard layout to QWERTZ (Hungarian)
cat > /etc/vconsole.conf << EOF
KEYMAP=hu
FONT=lat2-Terminus16
EOF

print_success "Localization configured"

# ===== HOSTNAME & USERS =====
print_status "Configuring hostname and users..."

echo "xby" > /etc/hostname

cat >> /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   xby.localdomain xby
EOF

# Set root password (space)
echo -e " " | passwd root

# Create user xby
useradd -m -G wheel,video,audio -s /bin/bash xby

# Set user password (space)
echo -e "xby: " | chpasswd

# Configure sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

print_success "Hostname and users configured"

# ===== BOOTLOADER =====
print_status "Installing bootloader..."

pacman -S --noconfirm grub efibootmgr

# Determine disk from mount
ROOT_DEV=$(df /boot | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

grub-mkconfig -o /boot/grub/grub.cfg

print_success "Bootloader installed"

# ===== NVIDIA DRIVERS =====
print_status "Installing NVIDIA drivers for RTX 3060..."

pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils

# Create modprobe config for NVIDIA
cat > /etc/modprobe.d/nvidia.conf << EOF
options nvidia-drm modeset=1
EOF

print_success "NVIDIA drivers installed"

# ===== INTEL DRIVERS & UTILS =====
print_status "Installing Intel tools..."

pacman -S --noconfirm intel-media-driver hwinfo intel-gpu-tools

print_success "Intel tools installed"

# ===== AUDIO =====
print_status "Installing audio stack..."

pacman -S --noconfirm pipewire pipewire-pulse pipewire-alsa wireplumber alsa-utils pavucontrol

# Enable pipewire socket
mkdir -p /etc/systemd/user/sockets.target.wants
ln -sf /usr/lib/systemd/user/pipewire.socket \
    /etc/systemd/user/sockets.target.wants/pipewire.socket

print_success "Audio system installed"

# ===== NETWORKING =====
print_status "Installing network tools..."

pacman -S --noconfirm networkmanager

systemctl enable NetworkManager

print_success "Networking configured"

# ===== KDE PLASMA =====
print_status "Installing KDE Plasma..."

pacman -S --noconfirm plasma-meta kde-applications sddm

systemctl enable sddm

print_success "KDE Plasma installed"

# ===== ADDITIONAL PACKAGES =====
print_status "Installing additional utilities..."

pacman -S --noconfirm \
    vim nano \
    git \
    wget curl \
    htop \
    neofetch \
    dolphin \
    konsole \
    firefox \
    thunderbird \
    vlc \
    ark \
    okular \
    krita \
    gimp \
    blender \
    steam \
    cuda \
    cudnn \
    python python-pip \
    code \
    keepassxc \
    spectacle \
    kcalc \
    kdeconnect

print_success "Additional packages installed"

# ===== KEYBOARD LAYOUT IN PLASMA =====
print_status "Configuring KDE Plasma keyboard layout..."

mkdir -p /home/xby/.config
cat > /home/xby/.config/kxkbrc << EOF
[General]
CountryList=hu

[Layout]
layoutList=hu
EOF

chown -R xby:xby /home/xby/.config

print_success "KDE Plasma configured"

# ===== SYSTEM TWEAKS =====
print_status "Applying system optimizations..."

# Enable multilib (for 32-bit support)
sed -i '/^\[multilib\]/,/^$/s/^#//' /etc/pacman.conf

# Set NVIDIA as primary GPU in Plasma
mkdir -p /etc/profile.d
cat > /etc/profile.d/nvidia.sh << EOF
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __GL_GSYNC_ALLOWED=0
export __GL_VRR_ALLOWED=0
EOF

print_success "System optimizations applied"

# ===== FINAL SETUP =====
print_status "Finalizing installation..."

# Update database
pacman -Sy

print_success "Arch Linux installation complete!"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Summary:${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Hostname: xby"
echo "Username: xby"
echo "Password: (space)"
echo "Desktop: KDE Plasma"
echo "GPU: NVIDIA RTX 3060"
echo "CPU: Intel"
echo "Localization: Hungarian (hu_HU.UTF-8)"
echo "Keyboard: QWERTZ (Hungarian)"
echo ""
echo "Next steps:"
echo "1. Exit chroot and reboot"
echo "2. Select xby from login screen"
echo "3. Configure system settings in Plasma"
echo -e "${GREEN}========================================${NC}"

CHROOT_EOF

chmod +x "$CHROOT_SCRIPT"

print_status "Running chroot installation..."
arch-chroot /mnt /chroot_install.sh

# Cleanup
rm "$CHROOT_SCRIPT"

print_success "Installation complete!"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Arch Linux is ready to reboot!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Unmounting and rebooting in 10 seconds..."
echo "Press Ctrl+C to skip reboot"
sleep 10

umount -R /mnt
reboot
