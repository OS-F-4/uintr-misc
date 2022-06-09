FROM ubuntu:22.04

# Set apk sourse and install some tools
RUN sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list \
    && sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y git vim wget cmake ninja-build ncurses-dev build-essential autoconf automake pkg-config libglib2.0-dev libpixman-1-dev texinfo libssl-dev libelf-dev cpio flex bison bc

# Build qemu
RUN git clone https://github.com/OS-F-4/qemu-uintr.git \
    && cd qemu-uintr \
    && mkdir build \
    && cd build \
    && ../configure --target-list=x86_64-softmmu --enable-debug --enable-trace-backends=log \
    && make -j \
    && make install \
    && rm -rf /qemu-uintr

# Build busybox
RUN wget https://busybox.net/downloads/busybox-1.35.0.tar.bz2 \
    && tar -jxf busybox-1.35.0.tar.bz2 \
    && rm busybox-1.35.0.tar.bz2 \
    && cd busybox-1.35.0 \
    && mkdir build \
    && make O=build defconfig \
    && sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/g' build/.config \
    && cd build \
    && make -j \
    && make install \
    && cd / \
    && mkdir -p initramfs/x86_64_busybox \
    && cd initramfs/x86_64_busybox \
    && mkdir -p bin sbin etc proc sys usr/bin usr/sbin \
    && cp -a ../../busybox-1.35.0/build/_install/* . \
    && rm -rf /busybox-1.35.0

# Build ipc-bench
RUN git clone -b linux-rfc-v1 https://github.com/OS-F-4/ipc-bench.git \
    && cd ipc-bench \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make

# Build linux kernel and filesystem
RUN git clone https://github.com/Xiang-cd/uintr-linux-kernel.git \
    && cd uintr-linux-kernel \
    && make O=build x86_64_defconfig \
    && sed -i 's/# CONFIG_X86_USER_INTERRUPTS is not set/CONFIG_X86_USER_INTERRUPTS=y/g' build/.config \
    && sed -i 's/# CONFIG_BLK_DEV_RAM is not set/CONFIG_BLK_DEV_RAM=y\nCONFIG_BLK_DEV_RAM_COUNT=16\nCONFIG_BLK_DEV_RAM_SIZE=65536/g' build/.config \
    && make O=build bzImage -j8 \
    && cp build/arch/x86_64/boot/bzImage /opt \
    && cd /uintr-linux-kernel/tools/uintr/sample && make \
    && cd /uintr-linux-kernel/tools/testing/selftests/uintr && make CFLAGS="-static -g -muintr -mgeneral-regs-only" \
    && cd /initramfs/x86_64_busybox \
    && cp /uintr-linux-kernel/tools/uintr/sample/uipi_sample . \
    && mkdir selftests \
    && cp -a /uintr-linux-kernel/tools/testing/selftests/uintr/* selftests \
    && mkdir ipc-bench \
    && cp -a /ipc-bench/build/source/* ipc-bench \
    && echo "#!/bin/sh" > init \
    && echo "mount -t proc none /proc" >> init \
    && echo "mount -t sysfs none /sys" >> init \
    && echo "mknod -m 666 /dev/ttyS0 c 4 64" >> init \
    && echo "echo -e \"Boot took \$(cut -d' ' -f1 /proc/uptime) seconds\"" >> init \
    && echo "setsid cttyhack sh" >> init \
    && echo "exec /bin/sh" >> init \
    && chmod +x init \
    && find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initramfs-busybox-x86_64.cpio.gz \
    && rm -rf /uintr-linux-kernel

CMD qemu-system-x86_64 -smp 2 -m 1024M -nographic \
    -kernel /opt/bzImage \
    -initrd /initramfs/initramfs-busybox-x86_64.cpio.gz \
    -append "root=/dev/ram0 rw rootfstype=ext4 console=ttyS0"
