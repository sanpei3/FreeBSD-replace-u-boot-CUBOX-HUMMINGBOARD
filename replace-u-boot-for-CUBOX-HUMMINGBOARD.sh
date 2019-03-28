#!/bin/sh -x

## 1. download image

##################
#
# Target image
#
# For 13-current
TARGET_IMAGE="FreeBSD-13.0-CURRENT-arm-armv7-CUBOX-HUMMINGBOARD-20190314-r345110"
fetch ftp://ftp.jp.freebsd.org/pub/FreeBSD/snapshots/arm/armv7/ISO-IMAGES/13.0/${TARGET_IMAGE}.img.xz

# For 12-RELEASE
#TARGET_IMAGE="FreeBSD-12.0-RELEASE-arm-armv7-CUBOX-HUMMINGBOARD"
#fetch ftp://ftp.jp.freebsd.org/pub/FreeBSD/releases/arm/armv7/ISO-IMAGES/12.0/${TARGET_IMAGE}.img.xz


##################
#
# base image(11.0-RELEASE)
#
OLD_IMAGE="FreeBSD-11.0-RELEASE-arm-armv6-CUBOX-HUMMINGBOARD"
fetch ftp://ftp.jp.freebsd.org/pub/FreeBSD/releases/arm/armv6/ISO-IMAGES/11.0/${OLD_IMAGE}.img.xz
##################
#
# NEW image
#
NEW_IMAGE="${TARGET_IMAGE}_with_11.0-U-BOOT"
MOUNT_POINT=/mnt

#################

## 2. decompress image file.

xz -d ${OLD_IMAGE}.img.xz
xz -d ${TARGET_IMAGE}.img.xz

##3. copy current image to new.img

cp ${TARGET_IMAGE}.img ${NEW_IMAGE}.img

##4. mdconfig those image files

MD_TARGET=`mdconfig ${TARGET_IMAGE}.img`
MD_OLD=`mdconfig ${OLD_IMAGE}.img`
MD_NEW=`mdconfig ${NEW_IMAGE}.img`

##5. copy 11.0-RELEASE image to new.img(copy u-boot files)

dd if=/dev/${MD_OLD} of=/dev/${MD_NEW} bs=1M conv=sync

#(If I know the partition size of u-boot, maybe I only copy u-boot part)

##6. recreate md2s2a partition
gpart delete -i 2 ${MD_NEW}

# sysctl kern.geom.debugflags=16

gpart add -t freebsd ${MD_NEW}
gpart create -s BSD ${MD_NEW}s2
# destroy bsd partition table
dd if=/dev/zero of=/dev/${MD_NEW}s2 bs=1M count=100
gpart create -s BSD ${MD_NEW}s2
gpart add -t freebsd-ufs -a 64k ${MD_NEW}s2

NEW_UFS_DEVICE="/dev/${MD_NEW}s2a"
newfs -U -L rootfs ${NEW_UFS_DEVICE}
# Turn on Softupdates
tunefs -n enable ${NEW_UFS_DEVICE}
# Turn on SUJ with a minimally-sized journal.
# This makes reboots tolerable if you just pull power
# Note:  A slow SDHC reads about 1MB/s, so a 30MB
# journal can delay boot by 30s.
tunefs -j enable -S 4194304 ${NEW_UFS_DEVICE}
# Turn on NFSv4 ACLs
tunefs -N enable ${NEW_UFS_DEVICE}

##7. dump CURRENT '/' 

dump -0uaLC 32 -f ${TARGET_IMAGE}.dump /dev/${MD_TARGET}s2a

##8 restore 12-CURRENT dump image

CURRENT_DIR=`pwd`

mkdir -p ${MOUNT_POINT}
mount ${NEW_UFS_DEVICE} ${MOUNT_POINT}
cd ${MOUNT_POINT}
restore -rf ${CURRENT_DIR}/${TARGET_IMAGE}.dump

##9. unmount md and delete md

LOADER_CONF_LOCAL="boot/loader.conf.local"

echo "hw.regulator.disable_unused=0" > ${LOADER_CONF_LOCAL}
echo "sdma-imx6q-to1.fwo_load=\"YES\"" >> ${LOADER_CONF_LOCAL}
echo "sdma-imx6q-to1.fwo_type=\"firmware\"" >> ${LOADER_CONF_LOCAL}

##10. unmount md and delete md

cd ${CURRENT_DIR}
umount ${MOUNT_POINT}

mdconfig -d -u ${MD_NEW}
mdconfig -d -u ${MD_TARGET} 
mdconfig -d -u ${MD_OLD}
