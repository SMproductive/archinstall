#!/bin/bash

                        ######
#    # ###### #    #    #     #  ####   ####  #####
##   # #      #    #    #     # #    # #    #   #
# #  # #####  #    #    ######  #    # #    #   #
#  # # #      # ## #    #   #   #    # #    #   #
#   ## #      ##  ##    #    #  #    # #    #   #
#    # ###### #    #    #     #  ####   ####    #

UEFI=1
BIOS=2

DELL=1
OTHER=2

I3=1
XFCE=2
GNOME=3

INTEL=1
NVIDIA=2
NOUVEAU=3

LIGHTDM=1
XDMARCHLINUX=2

#disk
DISK=$(cat disk.txt)
#bootlayout
BOOTLAYOUT=$(cat bootlayout.txt)
#efi folder name
EFI=$(cat efi.txt)

#Austian time zone time
ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime
hwclock --systohc

#Generating locales
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "de_AT.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

#network configuration
echo Enter the hostname here:
read HOSTNAME
echo $HOSTNAME >/etc/hostname
echo -e "127.0.0.1 \tlocalhost \n::1 \t\tlocalhost \n127.0.1.1 \t$HOSTNAME.localdomain $HOSTNAME" >>/etc/hosts
#initramfs
mkinitcpio -P
#pacman update database
pacman -Syu

#GRUB
pacman -S grub os-prober
os-prober
#bootloader for UEFI with GPT
if [ $BOOTLAYOUT = $UEFI ]; then
    pacman -S efibootmgr
    clear
    #which pc
    echo -e "1: UEFI for Dell \n2: UEFI for other"
    read BRAND
    #dell pc
    if [ $BRAND = $DELL ]; then
        grub-install --target=x86_64-efi --efi-directory=/$EFI --removable
    #other pc
    elif [ $BRAND = $OTHER ]; then
        grub-install --target=x86_64-efi --efi-directory=/$EFI --bootloader-id=GRUB
    fi
#bootloader for BIOS with MBR
elif [ $BOOTLAYOUT = $BIOS ]; then
    grub-install --target=i386-pc $DISK
fi
#grub main configuration
grub-mkconfig -o /boot/grub/grub.cfg
clear

echo "Now the installation of the bootable system is done!
So let's move on the user configuration."
echo Enter password for root:
passwd
clear
#new user
echo new username:
read USERNAME
useradd -m $USERNAME -G users,wheel,audio,video,power
#passwor for new user
echo Enter password for new user:
passwd $USERNAME
clear

echo "After that let's move on the environment!"
#choice desktop / windowmanager
echo "1: Tiling Windowmanager I3wm
2: xfce
3: Gnome
Skip with any key for doing everything yourself"
read GUI

echo install some essential packages
pacman -S dhcpcd iwctl
systemctl enable dhcpcd
clear
case $GUI in
$I3)
    pacman -S i3 dmenu terminator
    pacman -S sudo vim man linux-headers
    echo "exec i3" >/home/$USERNAME/.xsession
    ;;
$XFCE)
    pacman -S xfce4 xfce4-goodies
    pacman -S sudo vim man linux-headers
    echo "startxfce4" >/home/$USERNAME/.xsession
    ;;
$GNOME)
    pacman -S gnome gdm
    systemctl enable gdm
    systemctl enable NetworkManager
    ;;
*)
    echo Do it yourself!!
    sleep 5
    exit
    ;;
esac

pacman -S xorg xorg-xinit
clear

if [ $GUI != $GNOME ]; then
    #packages
    pacman -S nautilus
    #login Service
    echo "1: Lightdm
  2: xdm-archlinux "
    read LOGINSERVICE
    if [ $LOGINSERVICE = $LIGHTDM ]; then
        pacman -S lightdm lightdm-gtk-greeter
        systemctl enable lightdm
        rm /home/$USERNAME/.xsession
    elif [ $LOGINSERVICE = $XDMARCHLINUX ]; then
        pacman -S xdm-archlinux
        systemctl enable xdm-archlinux
        chmod +x /home/$USERNAME/.xsession
    fi
fi
clear
#grafics driver
echo Your grafic driver:
lspci -v | grep -A1 -e VGA -e 3D
echo Enter selection
echo "1: Intel
2: normal nVidia
3: nVidia nouveau
skip with any key for just the basic driver"
read DRIVER
case $DRIVER in
  $INTEL)
    pacman -S xf86-video-intel
    ;;
    $NVIDIA)
    pacman -S nvidia
    ;;
    $NOUVEAU)
    pacman -S xf86-video-nouveau
    ;;
    *)
    ;;
  esac
  #audio
  pacman -S pavucontrol pulseaudio alsa-utils

exit
