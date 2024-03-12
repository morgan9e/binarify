#!/bin/bash

echo $0 $@ $(pwd)
cd "$(dirname "$0")"

./busybox sh -c "mkdir -p rootfs upper squash usr app"
./busybox sh -c "mkdir -p ./rootfs/{app,dev,proc,tmp,sys,home,usr,lib,lib64,bin,etc,sbin,var}"
./busybox sh -c "mkdir -p ./rootfs/{home/user,var/tmp}"
./busybox sh -c "mkdir -p ./rootfs/sys/{block,bus,class,dev,devices}"

./busybox tar xzf utils.tar.gz
./busybox tar xf usr.tar -C ./usr
./busybox tar xf app.tar -C ./app
./busybox sh -c "cp utils/busybox ./usr/bin/"

# ./busybox sh -c "utils/squashfuse ./root.sqsh ./squash"
# ./busybox sh -c "utils/unionfs -o cow upper=RW:squash=RO rootfs"

# --bind ./rootfs / \

# ./busybox sh
./busybox sh -c "utils/bwrap \
  --dev-bind /dev /dev \
  --proc /proc \
  --tmpfs /tmp \
  --ro-bind /sys /sys \
  --dir /var/tmp \
  --ro-bind ./usr /usr \
  --ro-bind ./app /app \
  --symlink usr/bin bin \
  --symlink usr/lib lib \
  --symlink usr/lib64 lib64 \
  --symlink usr/sbin sbin \
  --bind /home/$USER/ /home/user/ \
  --ro-bind /sys/block /sys/block \
  --ro-bind /sys/bus /sys/bus \
  --ro-bind /sys/class /sys/class \
  --ro-bind /sys/dev /sys/dev \
  --ro-bind /sys/devices /sys/devices \
  --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --unshare-net \
  --unshare-ipc \
  --unshare-pid \
  --unshare-uts \
  --unshare-cgroup \
  --unshare-all \
  --hostname virt \
  --setenv HOME /home/user \
  --setenv USER user \
  --setenv LD_LIBRARY_PATH /app/lib \
  --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/app/bin \
  --dir /run/user/$(id -u) \
  /usr/bin/busybox sh"

# ./busybox sh -c "umount ./rootfs"
# ./busybox sh -c "umount ./squash"
