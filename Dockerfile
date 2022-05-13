FROM ubuntu:18.04

# Set apk sourse and install some tools
RUN sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list \
    && sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list \
    && export DEBIAN_FRONTEND=noninteractive \
    && ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && apt-get update \
    && apt-get install -y python3 python3-pip git vim htop tmux curl wget cmake openssh-server libssl-dev libelf-dev ninja-build ncurses-dev software-properties-common cpio \
    && ln /usr/bin/python3 /usr/bin/python

# Install gcc-11
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && apt-get install -y build-essential manpages-dev \
    && apt-get update && apt-get install -y gcc-11 g++-11 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 60 --slave /usr/bin/g++ g++ /usr/bin/g++-11

# Install qemu
RUN apt-get -y install autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev \
              gawk build-essential bison flex texinfo gperf libtool patchutils bc \
              zlib1g-dev libexpat-dev pkg-config libglib2.0-dev libpixman-1-dev git tmux \
    && wget https://download.qemu.org/qemu-6.2.0.tar.xz \
    && tar xvJf qemu-6.2.0.tar.xz \
    && rm qemu-6.2.0.tar.xz \
    && cd qemu-6.2.0 \
    && ./configure --target-list=x86_64-softmmu,x86_64-linux-user \
    && make -j \
    && make install

# Install binutils
RUN wget https://mirrors.tuna.tsinghua.edu.cn/gnu/binutils/binutils-2.38.tar.bz2 \
    && tar -jxf binutils-2.38.tar.bz2 \
    && cd binutils-2.38 \
    && ./configure \
    && make -j \
    && make install

# Add user and set sshd
RUN adduser --disabled-password username && echo "username:enter-your-password" | chpasswd && ssh-keygen -A && mkdir /run/sshd && chmod 4755 /usr/bin/passwd

CMD chown -R username:username /home/username && /usr/sbin/sshd -D

EXPOSE 22
