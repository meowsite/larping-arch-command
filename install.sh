#!/usr/bin/env bash

# ==============================================================================
# ARCH LINUX AUTOMATED INSTALLER (HUNGARIAN QWERTZ / INTEL + RTX 3060)
# ==============================================================================

set -e 

# --- CONFIGURATION VARIABLES ---
TARGET_DISK="/dev/nvme0n1"       # A lemez neve (lsblk paranccsal ellenőrizd!)
TIMEZONE="Europe/Budapest"       # Magyar időzóna
LOCALE="hu_HU.UTF-8"             # Magyar rendszer nyelv
KEYMAP="hu"                      # Magyar QWERTZ billentyűzet (Konzol)
X11_KEYMAP="hu"                  # Magyar QWERTZ billentyűzet (X11/Grafikus felület)
HOSTNAME="xby"                   # Kért gépnév
USERNAME="xby"                   # Kért felhasználónév
PASSWORD=" "                     # Jelszó: EGYETLEN SZÓKÖZ CARACTER

echo "=================================================================="
echo " Arch Linux telepítése indul: Intel + RTX 3060 [HU QWERTZ]"
echo " Célterület: $TARGET_DISK"
echo "=================================================================="

echo "--> Óra szinkronizálása..."
timedatectl set-ntp true

echo "--> Tükörszerverek optimalizálása (Reflector)..."
pacman -Sy --noconfirm reflector
reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# ==============================================================================
# DISK PARTITIONING & FORMATTING
# ==============================================================================

echo "--> Létező partíciók törlése a következő lemezen: $TARGET_DISK..."
sgdisk --zap-all "$TARGET_DISK"

echo "--> Új GPT partíciók létrehozása..."
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$TARGET_DISK"
sgdisk -n 2:0:+8G -t 2:8200 -c 2:"SWAP" "$TARGET_DISK"
sgdisk -n 3:0:0   -t 3:8300 -c 3:"ROOT" "$TARGET_DISK"

if [[ "$TARGET_DISK" == *"nvme"* || "$TARGET_DISK" == *"mmcblk"* ]]; then
    PART_EFI="${TARGET_DISK}p1"
    PART_SWAP="${TARGET_DISK}p2"
    PART_ROOT="${TARGET_DISK}p3"
else
    PART_EFI="${TARGET_DISK}1"
    PART_SWAP="${TARGET_DISK}2"
    PART_ROOT="${TARGET_DISK}3"
fi

echo "--> Formázás..."
mkfs.vfat -F 32 "$PART_EFI"
mkswap "$PART_SWAP"
mkfs.ext4 -F "$PART_ROOT"

echo "--> Csatolás (Mount)..."
mount "$PART_ROOT" /mnt
mkdir -p /mnt/boot
mount "$PART_EFI" /mnt/boot
swapon "$PART_SWAP"

# ==============================================================================
# BASE SYSTEM PACSTRAP
# ==============================================================================

echo "--> Alaprendszer és Intel mikrokód telepítése..."
pacstrap /mnt base base-devel linux linux-firmware intel-ucode nano git networkmanager sudo

echo "--> fstab generálása..."
genfstab -U /mnt >> /mnt/etc/fstab

# ==============================================================================
# CHROOT CONFIGURATION SCRIPT
# ==============================================================================

echo "--> Belső chroot beállító script legenerálása..."
cat <<EOF > /mnt/root/chroot_setup.sh
#!/bin/bash
set -e

echo "--> Időzóna beállítása..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "--> Magyar lokalizáció és QWERTZ billentyűzet beállítása..."
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "--> Hálózat konfigurálása..."
echo "$HOSTNAME" > /etc/hostname
cat <<EOT >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT

echo "--> Jelszavak beállítása (szóköz)..."
echo "root:$PASSWORD" | chpasswd

echo "--> '$USERNAME' felhasználó létrehozása..."
useradd -m -g users -G wheel,storage,power -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/10-installer

# ==============================================================================
# HARDWARE DRIVERS & AUDIO SETUP
# ==============================================================================

echo "--> Multilib tároló bekapcsolása (32-bit/Steam kompatibilitás)..."
cat <<EOT >> /etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist
EOT

pacman -Sy --noconfirm

echo "--> NVIDIA illesztőprogramok telepítése az RTX 3060-hoz..."
pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils nvidia-settings

echo "--> NVIDIA Early KMS bekapcsolása (Fekete képernyő ellen bootoláskor)..."
sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
echo "options nvidia_drm modeset=1" > /etc/modprobe.d/nvidia.conf
mkinitcpio -P

echo "--> PipeWire Audio rendszer telepítése..."
pacman -S --noconfirm pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber

# ==============================================================================
# BOOTLOADER SETUP
# ==============================================================================

echo "--> GRUB Bootloader telepítése..."
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# NVIDIA paraméterek átadása a kernelnek
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# ==============================================================================
# DESKTOP ENVIRONMENT & SERVICES SETUP
# ==============================================================================

echo "--> KDE Plasma asztali környezet és magyar nyelvi csomagok telepítése..."
pacman -S --noconfirm xorg plasma-desktop sddm konsole dolphin kde-l10n-hu

echo "--> Grafikus felület billentyűzetének beállítása magyarra..."
mkdir -p /etc/X11/xorg.conf.d
cat <<EOT > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "$X11_KEYMAP"
EndSection
EOT

echo "--> Rendszerszolgáltatások bekapcsolása..."
systemctl enable NetworkManager
systemctl enable sddm

echo "--> Takarítás..."
rm /root/chroot_setup.sh
EOF

# ==============================================================================
# EXECUTION
# ==============================================================================

echo "--> Belépés a Chroot környezetbe a beállítások elvégzéséhez..."
chmod +x /mnt/root/chroot_setup.sh
arch-chroot /mnt /root/chroot_setup.sh

echo "=================================================================="
echo " A telepítés sikeresen befejeződött!"
echo " Partíciók lecsatolása..."
echo "=================================================================="

umount -R /mnt
echo "Most már biztonságosan beírhatod a 'reboot' parancsot az újraindításhoz!"
