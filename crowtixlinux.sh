#!/bin/bash

# Function to format partitions
format_partitions() {
    echo "Formatting partitions..."
    mkfs.fat -F32 "$EFI_PART"
    mkfs.btrfs "$MAIN_PART"
    echo "Partitions formatted."
}

# Function to create Btrfs subvolumes
create_subvolumes() {
    echo "Creating Btrfs subvolumes..."
    mount "$MAIN_PART" /mnt
    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    umount /mnt
    echo "Subvolumes created."
}

# Function to mount partitions
mount_partitions() {
    echo "Mounting partitions..."
    mount -o noatime,compress=zstd,space_cache=v2,subvol=@ "$MAIN_PART" /mnt
    mkdir -p /mnt/{boot,home,.snapshots}
    mount -o noatime,compress=zstd,space_cache=v2,subvol=@home "$MAIN_PART" /mnt/home
    mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots "$MAIN_PART" /mnt/.snapshots
    mount "$EFI_PART" /mnt/boot
    echo "Partitions mounted."
}

# Main script execution
echo "Artix Linux Installation Script"

# Prompt user for partition choices
read -p "Enter the EFI partition (e.g., /dev/sda1): " EFI_PART
read -p "Enter the main system partition (e.g., /dev/sda2): " MAIN_PART

# Prompt user for timezone, hostname, root password, and username details
read -p "Enter your timezone (e.g., Europe/London): " TIMEZONE
read -p "Enter your hostname (e.g., myhostname): " HOSTNAME
read -s -p "Enter root password: " ROOT_PASSWORD
echo ""
read -p "Enter your username (e.g., user): " USERNAME
read -s -p "Enter password for $USERNAME: " USER_PASSWORD
echo ""

# Format partitions
format_partitions

# Create Btrfs subvolumes
create_subvolumes

# Mount partitions
mount_partitions

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

