#!/bin/bash
#partition variables
UEFI=1
BIOS=2
ERASE=1

#efi partition UEFI
uefiEfiFunktion() {
    parted $1 print
    echo "partition number of efi partition: "
    local efiPartNbr
    read efiPartNbr
    echo "Tip: Take the end of previous partition"
    echo "partition start: "
    local efiStart
    read efiStart
    echo "partition end(minimum size 260M): "
    local efiEnd
    read efiEnd
    local efiPart="$1""$efiPartNbr"
    parted $1 mkpart efi fat32 $efiStart $efiEnd
    #flags
    parted $1 set $efiPartNbr esp on  #<----
    parted $1 set $efiPartNbr boot on #<----
    #format
    mkfs.fat -F32 $efiPart
    clear
    eval $2="'$efiPart'"
}

#root partition UEFI
uefiRootFunction() {
    parted $1 print
    echo "partition number of root partition: "
    local rootPartNbr
    read rootPartNbr
    echo "Tip: Take the end of previous partition "
    echo "partition start: "
    local rootStart
    read rootStart
    echo "partition end: "
    local rootEnd
    read rootEnd
    local rootPart="$1""$rootPartNbr"
    parted $1 mkpart root ext4 $rootStart $rootEnd
    #format
    mkfs.ext4 $rootPart
    clear
    eval $2="'$rootPart'"
}

#swap partition UEFI
uefiSwapFunktion() {
    parted $1 print
    echo "partition number of swap partition: "
    local swapPartNbr
    read swapPartNbr
    echo "Tip: Take the end of previous partition "
    echo "partition start: "
    local swapStart
    read swapStart
    echo "partition end(minimum size 512M): "
    local swapEnd
    read swapEnd
    local swapPart="$1""$swapPartNbr"
    parted $1 mkpart swap linux-swap $swapStart $swapEnd
    #flags
    parted $1 set $swapPartNbr swap on #<----
    #format
    mkswap $swapPart
    clear
    eval $2="'$swapPart'"
}

#swap partition BIOS
biosSwapFunktion() {
    parted $1 print
    echo "partition number of swap partition: "
    local swapPartNbr
    read swapPartNbr
    echo "Tip: Take the end of previous partition "
    echo "partition start: "
    local swapStart
    read swapStart
    echo "partition end(recommended size over 512M): "
    local swapEnd
    read swapEnd
    local swapPart="$1""$swapPartNbr"
    #swap partition
    parted $1 mkpart primary linux-swap $swapStart $swapEnd
    #format & mount
    mkswap $swapPart
    clear
    eval $2="'$swapPart'"
}

#root partition BIOS
biosRootFunktion() {
    parted $1 print
    echo "partition number of root partition: "
    local rootPartNbr
    read rootPartNbr
    echo "Tip: Take the end of previous partition"
    echo "partition start: "
    local rootStart
    read rootStart
    echo "partition end: "
    local rootEnd
    read rootEnd
    local rootPart="$1""$rootPartNbr"
    #root partition
    parted $1 mkpart primary ext4 $rootStart $rootEnd
    #format & mount
    mkfs.ext4 $rootPart
    clear
    eval $2="'$rootPart'"
}
###############################################################################
         #####
       #      # #####   ##   #####  #####
       #         #    #  #  #    #   #
        #####    #   #    # #    #   #
             #   #   ###### #####    #
       #     #   #   #    # #   #    #
        #####    #   #    # #    #   #

###############################################################################

#time synchronization
timedatectl set-ntp true
sleep 5
clear
#nice startup
cat heading.txt
echo press enter to continue or ctrl-c to cancel
read
clear

#BOOTLAYOUT choice
echo Which bootlayout do you want?
echo "1: UEFI with GPT
2: BIOS with MBR"
read BOOTLAYOUT

#disk choice
clear
lsblk
echo disk name:
read DISK
DISK=/dev/"$DISK"

#userdefined or full disk?
echo Do you want to create a new partition Table?
echo "1: erase disk
anything else if not"
read PARTITIONINGSTYLE
clear

#for whole disk (erasing)
if [ $ERASE = $PARTITIONINGSTYLE ]; then
    if [ $BOOTLAYOUT = $UEFI ]; then
        parted $DISK mklabel gpt
    elif [ $BOOTLAYOUT = $BIOS ]; then
        parted $DISK mklabel msdos
    fi
fi
clear
#UEFI
if [ $BOOTLAYOUT = $UEFI ]; then
    #mount & partitioning
    uefiEfiFunktion $DISK EFIPART
    uefiRootFunction $DISK ROOTPART
    uefiSwapFunktion $DISK SWAPPART
    echo Enter the name of the efi folder
    read EFI
    mount $ROOTPART /mnt
    mkdir /mnt/$EFI
    mount $EFIPART /mnt/$EFI
    swapon $SWAPPART

#BIOS
elif [ $BOOTLAYOUT = $BIOS ]; then
    #mount & partitioning
    biosSwapFunktion $DISK SWAPPART
    biosRootFunktion $DISK ROOTPART
    swapon $SWAPPART
    mount $ROOTPART /mnt
fi

#installation
pacstrap /mnt base base-devel linux linux-firmware

#fstab
genfstab -U /mnt >>/mnt/etc/fstab

#####################################################################
#root on installed linux
#chrootscript
echo $DISK >/mnt/disk.txt
echo $BOOTLAYOUT >/mnt/bootlayout.txt
echo $EFI >/mnt/efi.txt
cp chroot.sh /mnt/chroot.sh
clear
arch-chroot /mnt ./chroot.sh

#remove files afterwards
rm /mnt/*.txt
rm /mnt/chroot.sh
echo Press enter to shutdown ctrl-c for cancel the shutdown and do manual changes
read
shutdown now
