#!/bin/bash

#runs the last line of the file
#eval $(cat install-parabola.sh |& tail -1)

set -e

if [ "$1" == "1" ]; then
	echo "set -o vi" >> .bashrc
	echo "set -o vi" >> .zshrc
	setxkbmap -option "caps:escape"

	#echo "##########################################"
	#echo "Which disk?"
	#echo
	#lsblk
	#echo
	#echo -n "I choose the disk (e.g. sda): "
	#read NAZOV_DISKU
	#echo "##########################################"

	NAZOV_DISKU=$(lsblk | grep disk | sort -k3h | awk '{ print $1 } ' | head -n 1)

	if echo $@ | grep uefi; then
		parted /dev/$NAZOV_DISKU -s -- mklabel gpt mkpart ESP fat32 1MiB 513MiB set 1 boot on mkpart primary ext2 513MiB 100%
		mkfs.fat -F32 /dev/${NAZOV_DISKU}1
	  if echo $@ | grep crypt; then
		echo -n cryptsetup | cryptsetup -v --cipher twofish-xts-plain64 --key-size 512 --hash whirlpool --use-random -q luksFormat /dev/${NAZOV_DISKU}2 -d -
		echo -n cryptsetup | cryptsetup luksOpen /dev/${NAZOV_DISKU}2 lvm -d -
          fi
	else
		parted /dev/$NAZOV_DISKU -s -- mklabel msdos mkpart primary ext2 1MiB 100%
	  if echo $@ | grep crypt; then
		echo -n cryptsetup | cryptsetup -v --cipher serpent-xts-plain64 --key-size 512 --hash whirlpool --use-random -q luksFormat /dev/${NAZOV_DISKU}1 -d -
		echo -n cryptsetup | cryptsetup luksOpen /dev/${NAZOV_DISKU}1 lvm -d -
          fi
	fi
	pvcreate /dev/mapper/lvm
	vgcreate matrix /dev/mapper/lvm
	lvcreate -L 4G matrix -n swap
	lvcreate -l +100%FREE matrix -n root
	mkswap /dev/mapper/matrix-swap
	swapon /dev/matrix/swap
	mkfs.ext4 /dev/mapper/matrix-root
	mount /dev/matrix/root /mnt
	mkdir -p /mnt/boot
	if echo $@ | grep uefi; then
		mkdir -p /mnt/boot/efi
		mount /dev/${NAZOV_DISKU}1 /mnt/boot/efi
	fi

	pacman -Syy
	#pacman -Syu --noconfirm || (pacman -Rsn --noconfirm $(pacman -Qqm | grep video) && pacman -Syu --noconfirm)
	#pacman -S --noconfirm pacman
	#pacman -Syy
	#pacman -Syu --noconfirm 

	#pacman -S --noconfirm reflector
	#reflector --sort rate --save /etc/pacman.d/mirrorlist
   	pacman -S --noconfirm parabola-keyring
	pacman-key --refresh-keys
	pacstrap /mnt base
	genfstab -U -p /mnt >> /mnt/etc/fstab
	cp "$(readlink -f $0)" "/mnt"
	arch-chroot /mnt /bin/bash

elif [ "$1" == "2" ]; then
	#echo -n "Hostname? "
	#read HOSTNAME
	#echo -n "Username? "
	#read USERNAME
        HOSTNAME=pc123
        USERNAME=myname
	echo "set -o vi" >> .bashrc
	sed -i -- 's/#  en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
	locale-gen
	echo LANG=en_US.UTF-8 > /etc/locale.conf
	export LANG=en_US.UTF-8 
	rm /etc/localtime
	ln -s /usr/share/zoneinfo/Europe/Bratislava /etc/localtime
	hwclock --systohc --utc
	echo $HOSTNAME > /etc/hostname
	sed -i -- "/^127/ s/$/ $HOSTNAME/g" /etc/hosts
	sed -i -- "/^::1/ s/$/ $HOSTNAME/g" /etc/hosts
	sed -i "s/block filesystems keyboard fsck/block keyboard keymap consolefont encrypt lvm2 filesystems fsck shutdown/g" /etc/mkinitcpio.conf
	sed -i 's/MODULES=""/MODULES="i915"/g' /etc/mkinitcpio.conf
	dd bs=512 count=4 if=/dev/urandom of=/etc/mykeyfile iflag=fullblock
	NAZOV_DISKU=$(lsblk | grep disk | sort -k3h | awk '{ print $1 } ' | head -n 1)
	if echo $@ | grep uefi; then
		echo -n cryptsetup | cryptsetup luksAddKey /dev/${NAZOV_DISKU}2 /etc/mykeyfile -d -
	else
		echo -n cryptsetup | cryptsetup luksAddKey /dev/${NAZOV_DISKU}1 /etc/mykeyfile -d -
	fi
	sed -i 's/FILES=""/FILES="\/etc\/mykeyfile"/g' /etc/mkinitcpio.conf
	mkinitcpio -p linux-libre
	chmod 000 /etc/mykeyfile
	chmod 700 /boot /etc/iptables
	echo "root:root" | chpasswd

	pacman -Syu --noconfirm 
        useradd -m -G wheel -s /bin/bash $USERNAME
	echo "$USERNAME:$USERNAME" | chpasswd
	pacman -S --noconfirm git sudo mutt vim syncthing python-pip make gcc dosfstools grub colordiff openssh zip unzip
	if echo $@ | grep uefi; then
		pacman -S --noconfirm efibootmgr
	fi
	if echo $@ | grep lb; then
		pacman -S --noconfirm flashrom dmidecode 
	fi
	if echo $@ | grep gui; then
		pacman -S --noconfirm xorg-server iceweasel gimp libreoffice-still evince bc apache php-apache neovim pmount udisks2 
          if echo $@ | grep wmutils; then
                  pacman -S --noconfirm xorg-xinit rxvt-unicode sxhkd dmenu dunst slock xorg-xrandr xsel xorg-xsetroot xcb-util-wm xorg-xev scrot autocutsel
                  cd /tmp
                  git clone https://github.com/wmutils/core
                  git clone https://github.com/wmutils/opt
                  git clone https://github.com/wmutils/contrib
                  cd core
                  make
                  make install
                  cd ..
                  cd opt
                  make
                  make install
                  cd ..
                  cd contrib/killwa
                  make
                  make install
                  cd /
          fi
          if echo $@ | grep budgie; then
                  pacman -S --noconfirm budgie-desktop gnome-terminal nautilus gnome-control-center lightdm lightdm-gtk-greeter meson val pkg-config libpeas gobject-introspection ninja
                  systemctl enable lightdm
                  cd /tmp
                  git clone https://github.com/ilgarmehmetali/budgie-brightness-control-applet
                  cd budgie-brightness-control-applet/
                  mkdir build
                  cd build
                  meson --prefix /usr --buildtype=plain ..
                  ninja
                  ninja install
                  cd /
          fi
          if echo $@ | grep wayland; then
                  pacman -S --noconfirm wayland xorg-server-xwayland lightdm lightdm-gtk-greeter
                  systemctl enable lightdm
          fi
          if echo $@ | grep intel; then
                  pacman -S --noconfirm xf86-video-intel
          fi
          if echo $@ | grep gnome; then
                  pacman -S --noconfirm gnome-shell gnome-terminal nautilus gnome-control-center gdm
                  systemctl enable gdm
	fi
	if echo $@ | grep alsa; then
		pacman -S --noconfirm alsa-utils mpv youtube-dl mps-youtube 
	fi
	if echo $@ | grep wifi; then
		pacman -S --noconfirm wpa_supplicant dialog wpa_actiond
	fi
        sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers
        echo "set -o vi" >> /root/.bashrc
        echo "set -o vi" >> /home/$USERNAME/.bashrc
        pip3 install syncthingmanager
        systemctl enable syncthing@$USERNAME.service
        #chmod u+s /usr/bin/Xorg
	if echo $@ | grep uefi; then
		sed -i '1s/^/GRUB_ENABLE_CRYPTODISK=y\n/' /etc/default/grub
		sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="root=\/dev\/matrix\/root cryptdevice=\/dev\/sda1:root"/g' /etc/default/grub
		grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
		grub-mkconfig -o /boot/grub/grub.cfg
	fi
	echo HOTOVO!!!
elif [ "$1" == "3" ]; then
        stman configure
elif [ "$1" == "4" ]; then
        ~/Coco/bin/prepoj.sh
elif [ "$1" == "5" ]; then
        iptables.sh
        systemctl enable iptables
        cp ~/Coco/slash/usr/local/bin/kernecust.sh /usr/local/bin/
        cp ~/Coco/slash/etc/systemd/system/firecust.service /etc/systemd/system/
        systemctl start firecust
        systemctl enable firecust
fi
