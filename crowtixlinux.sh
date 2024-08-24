#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root." 
  exit 1
fi

# List available disks
lsblk

# Ask the user to select a disk to partition
read -p "Enter the disk to partition (e.g., /dev/sda): " disk

# Confirm the selected disk
echo "You have chosen $disk. Make sure this is correct!"
read -p "Do you want to proceed with partitioning $disk? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo "Exiting script."
  exit 1
fi

# Prompt the user to choose between ext4 and btrfs for the root partition
read -p "Choose the filesystem for the root partition (ext4/btrfs): " fs_choice

if [[ "$fs_choice" != "ext4" && "$fs_choice" != "btrfs" ]]; then
  echo "Invalid choice. Please run the script again and choose either ext4 or btrfs."
  exit 1
fi

# Start fdisk to create new partitions
echo "Starting fdisk on $disk..."
fdisk $disk <<EOF
g
n
1

+512M
t
1
n
2


w
EOF

echo "Partitions created on $disk."

# Inform the user of the changes
partprobe $disk
lsblk $disk

echo "Partitioning complete. Available partitions on $disk:"
lsblk $disk

# Ask user where to mount the partitions
read -p "Enter the EFI partition (e.g., /dev/sda1): " EFI_PART
read -p "Enter the main system partition (e.g., /dev/sda2): " MAIN_PART

# Optional swap creation
read -p "Do you want to create a swap partition? (yes/no): " create_swap

if [[ "$create_swap" == "yes" ]]; then
  read -p "Enter the swap partition (e.g., /dev/sda3): " SWAP_PARTITION

    # Create swap
    mkswap $SWAP_PARTITION
    swapon $SWAP_PARTITION
    echo "Swap created and activated on $SWAP_PARTITION."
fi

# Format the EFI partition
mkfs.fat -F32 $EFI_PART

# Format the root partition based on user choice
if [[ "$fs_choice" == "ext4" ]]; then
  mkfs.ext4 $MAIN_PART
elif [[ "$fs_choice" == "btrfs" ]]; then
  mkfs.btrfs $MAIN_PART

    # Create Btrfs subvolumes if btrfs is chosen
    echo "Creating Btrfs subvolumes..."
    mount $MAIN_PART /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    umount /mnt
    echo "Subvolumes created."
    fi

# Mount partitions
echo "Mounting partitions..."
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ $MAIN_PART /mnt
mkdir -p /mnt/{boot,home,.snapshots}
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home $MAIN_PART /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots $MAIN_PART /mnt/.snapshots
mount $EFI_PART /mnt/boot

echo "Partitions mounted and ready "

# Install base system and essential packages
echo "Installing base system and essential packages..."
basestrap -i /mnt base base-devel openrc elogind-openrc linux linux-firmware grub efibootmgr os-prober lvm2 lvm2-openrc cryptsetup networkmanager networkmanager-openrc btrfs-progs dosfstools mtools git neovim zoxide fish rsync

# Generate the filesystem table
echo "Generating fstab..."
fstabgen -U /mnt >> /mnt/etc/fstab

# Chroot into the new system and configure it
echo "Chrooting into the new system and configuring it..."
artix-chroot /mnt /bin/bash <<EOF

# Set up timezone
echo "Setting up timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set up localization
echo "Setting up localization..."
echo -e "ar_SA.UTF-8 UTF-8\nen_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "Setting hostname..."
echo "$HOSTNAME" > /etc/hostname

# Set root password
echo "Setting root password..."
echo "root:$ROOT_PASSWORD" | chpasswd

# Create a new user
echo "Creating a new user..."
useradd -g users -G wheel,audio,video -m $USERNAME
echo "$USERNAME:$USER_PASSWORD" | chpasswd

# Configure sudoers
echo "Configuring sudoers..."
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install additional packages
echo "Installing additional packages..."
pacman -S --noconfirm dhcpcd wpa_supplicant network-manager-applet bluez bluez-utils bluez-openrc blueberry pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber pavucontrol playerctl openssh openssh-openrc noto-fonts-extra adobe-source-han-sans-jp-fonts noto-fonts-cjk ttf-bitstream-vera ttf-cascadia-code tlp mpv tmux thunar snapper ntfs-3g xorg xorg-xinit xorg-xmodmap xorg-server webkit2gtk xf86-video-intel intel-ucode pamixer brightnessctl

# Mount Windows EFI partition
echo "Mounting Windows EFI partition for os-prober..."
mount /dev/sda1 /mnt

# Install and configure GRUB
echo "Installing and configuring GRUB..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

# Install and configure Fish shell with Oh My Fish (OMF)
echo "Installing and configuring Fish shell with OMF..."
su - $USERNAME -c "curl -L https://get.oh-my.fish | fish"
su - $USERNAME -c "fish -c 'omf install bobthefish'"

# Set Fish as the default shell
echo "Setting Fish as the default shell..."
chsh -s /usr/bin/fish $USERNAME

# Add Fish shell configurations and aliases
echo "Configuring Fish shell..."
cat <<EOL >> /home/$USERNAME/.config/fish/config.fish
alias c='clear'
alias rcp='rsync -av --progress -h M '
alias rmv='rsync -av --progress -h M --remove-source-files '
alias nv='nvim'
alias ls='lsd'
alias ll='lsd -lA'
alias lt='lsd --tree'
alias t='tmux'
alias build_suckless='rm -rf config.h; sudo make clean install'
zoxide init fish | source
fish_vi_key_bindings
set -Ux MANPAGER "sh -c 'col -bx | bat -l man -p'"
EOL

# Change ownership of the Fish config file to the new user
chown $USERNAME:$USERNAME /home/$USERNAME/.config/fish/config.fish

# Configure Tmux to use Ctrl-a instead of Ctrl-b
echo "Configuring Tmux..."
echo "unbind C-b" >> /home/$USERNAME/.tmux.conf
echo "set-option -g prefix C-a" >> /home/$USERNAME/.tmux.conf
echo "bind C-a send-prefix" >> /home/$USERNAME/.tmux.conf
chown $USERNAME:$USERNAME /home/$USERNAME/.tmux.conf

# Install lsd from source
echo "Installing lsd from source..."
pacman -S --noconfirm rust
git clone https://github.com/lsd-rs/lsd.git /tmp/lsd
cd /tmp/lsd
cargo install --path .
EOF

echo "crowtix Linux installation complete!"

