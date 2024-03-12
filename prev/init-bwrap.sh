#!/bin/bash

echo $0 $@ $(pwd)
cd "$(dirname "$0")"

mkdir -p rootfs upper squash

./busybox tar xf utils.tar
./busybox sh -c "utils/squashfuse ./root.sqsh ./squash"
./busybox sh -c "utils/unionfs -o cow upper=RW:squash=RO rootfs"
./busybox sh -c "mkdir ./app ./rootfs/app"

./busybox sh -c "utils/bwrap \
  --bind ./rootfs / \
  --dev-bind /dev /dev \
  --proc /proc \
  --tmpfs /tmp \
  --ro-bind /sys /sys \
  --dir /var/tmp \
  --ro-bind ./app /app \
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
  --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/app \
  --dir /run/user/$(id -u) \
  /bin/bash"

./busybox sh -c "umount ./rootfs"
./busybox sh -c "umount ./squash"
