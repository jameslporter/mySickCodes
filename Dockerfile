FROM sickcodes/docker-osx

# SHELL ["/bin/bash", "-c"]

# change disk size here or add during build, e.g. --build-arg VERSION=10.14.5 --build-arg SIZE=50G
ARG SIZE=200G

ARG BASEIMAGE="BaseSystem_Monterey.dmg"
ARG IMAGE_PATH="mac_hdd_ng.img"


WORKDIR /home/arch/OSX-KVM
COPY ./baseImages/"${BASEIMAGE}" /home/arch/OSX-KVM
RUN test -f "BaseSystem.img" || qemu-img convert ${BASEIMAGE} -O qcow2 -p -c BaseSystem.img \
    && rm -f ${BASEIMAGE}
RUN test -f ${IMAGE_PATH} || qemu-img create -f qcow2 ${IMAGE_PATH} "${SIZE}"

#### libguestfs versioning

# 5.13+ problem resolved by building the qcow2 against 5.12 using libguestfs-1.44.1-6

ENV SUPERMIN_KERNEL=/boot/vmlinuz-linux
ENV SUPERMIN_MODULES=/lib/modules/5.12.14-arch1-1
ENV SUPERMIN_KERNEL_VERSION=5.12.14-arch1-1
ENV KERNEL_PACKAGE_URL=https://archive.archlinux.org/packages/l/linux/linux-5.12.14.arch1-1-x86_64.pkg.tar.zst
ENV KERNEL_HEADERS_PACKAGE_URL=https://archive.archlinux.org/packages/l/linux/linux-headers-5.12.14.arch1-1-x86_64.pkg.tar.zst
ENV LIBGUESTFS_PACKAGE_URL=https://archive.archlinux.org/packages/l/libguestfs/libguestfs-1.44.1-6-x86_64.pkg.tar.zst

ARG LINUX=true

# required to use libguestfs inside a docker container, to create bootdisks for docker-osx on-the-fly
RUN if [[ "${LINUX}" == true ]]; then \
        sudo pacman -U "${KERNEL_PACKAGE_URL}" --noconfirm \
        ; sudo pacman -U "${LIBGUESTFS_PACKAGE_URL}" --noconfirm \
        ; sudo pacman -U "${KERNEL_HEADERS_PACKAGE_URL}" --noconfirm \
        ; sudo pacman -S mkinitcpio --noconfirm \
        ; sudo libguestfs-test-tool \
        ; sudo rm -rf /var/tmp/.guestfs-* \
    ; fi

####


# optional --build-arg to change branches for testing
ARG BRANCH=master
ARG REPO='https://github.com/sickcodes/Docker-OSX.git'
# RUN git clone --recurse-submodules --depth 1 --branch "${BRANCH}" "${REPO}"
RUN rm -rf ./Docker-OSX \
    && git clone --recurse-submodules --depth 1 --branch "${BRANCH}" "${REPO}"

RUN touch Launch.sh \
    && chmod +x ./Launch.sh \
    && tee -a Launch.sh <<< '#!/bin/bash' \
    && tee -a Launch.sh <<< 'set -eux' \
    && tee -a Launch.sh <<< 'sudo chown    $(id -u):$(id -g) /dev/kvm 2>/dev/null || true' \
    && tee -a Launch.sh <<< 'sudo chown -R $(id -u):$(id -g) /dev/snd 2>/dev/null || true' \
    && tee -a Launch.sh <<< '[[ "${RAM}" = max ]] && export RAM="$(("$(head -n1 /proc/meminfo | tr -dc "[:digit:]") / 1000000"))"' \
    && tee -a Launch.sh <<< '[[ "${RAM}" = half ]] && export RAM="$(("$(head -n1 /proc/meminfo | tr -dc "[:digit:]") / 2000000"))"' \
    && tee -a Launch.sh <<< 'sudo chown -R $(id -u):$(id -g) /dev/snd 2>/dev/null || true' \
    && tee -a Launch.sh <<< 'exec qemu-system-x86_64 -m ${RAM:-2}000 \' \
    && tee -a Launch.sh <<< '-cpu ${CPU:-Penryn},${CPUID_FLAGS:-vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check,}${BOOT_ARGS} \' \
    && tee -a Launch.sh <<< '-machine q35,${KVM-"accel=kvm:tcg"} \' \
    && tee -a Launch.sh <<< '-smp ${CPU_STRING:-${SMP:-1},cores=${CORES:-1}} \' \
    && tee -a Launch.sh <<< '-usb -device usb-kbd -device usb-tablet \' \
    && tee -a Launch.sh <<< '-device isa-applesmc,osk=ourhardworkbythesewordsguardedpleasedontsteal\(c\)AppleComputerInc \' \
    && tee -a Launch.sh <<< '-drive if=pflash,format=raw,readonly=on,file=/home/arch/OSX-KVM/OVMF_CODE.fd \' \
    && tee -a Launch.sh <<< '-drive if=pflash,format=raw,file=/home/arch/OSX-KVM/OVMF_VARS-1024x768.fd \' \
    && tee -a Launch.sh <<< '-smbios type=2 \' \
    && tee -a Launch.sh <<< '-audiodev ${AUDIO_DRIVER:-alsa},id=hda -device ich9-intel-hda -device hda-duplex,audiodev=hda \' \
    && tee -a Launch.sh <<< '-device ich9-ahci,id=sata \' \
    && tee -a Launch.sh <<< '-drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file=${BOOTDISK:-/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2} \' \
    && tee -a Launch.sh <<< '-device ide-hd,bus=sata.2,drive=OpenCoreBoot \' \
    && tee -a Launch.sh <<< '-device ide-hd,bus=sata.3,drive=InstallMedia \' \
    && tee -a Launch.sh <<< '-drive id=InstallMedia,if=none,file=/home/arch/OSX-KVM/BaseSystem.img,format=qcow2 \' \
    && tee -a Launch.sh <<< '-drive id=MacHDD,if=none,file=/home/arch/OSX-KVM/mac_hdd_ng.img,format=${IMAGE_FORMAT:-qcow2} \' \
    && tee -a Launch.sh <<< '-device ide-hd,bus=sata.4,drive=MacHDD \' \
    && tee -a Launch.sh <<< '-netdev user,id=net0,hostfwd=tcp::${INTERNAL_SSH_PORT:-10022}-:22,hostfwd=tcp::${SCREEN_SHARE_PORT:-5900}-:5900,${ADDITIONAL_PORTS} \' \
    && tee -a Launch.sh <<< '-device ${NETWORKING:-vmxnet3},netdev=net0,id=net0,mac=${MAC_ADDRESS:-52:54:00:09:49:17} \' \
    && tee -a Launch.sh <<< '-monitor stdio \' \
    && tee -a Launch.sh <<< '-boot menu=on \' \
    && tee -a Launch.sh <<< '-vga vmware \' \
    && tee -a Launch.sh <<< '${EXTRA:-}'

# docker exec containerid mv ./Launch-nopicker.sh ./Launch.sh
# This is now a legacy command.
# You can use -e BOOTDISK=/bootdisk with -v ./bootdisk.img:/bootdisk
RUN grep -v InstallMedia ./Launch.sh > ./Launch-nopicker.sh \
    && chmod +x ./Launch-nopicker.sh \
    && sed -i -e s/OpenCore\.qcow2/OpenCore\-nopicker\.qcow2/ ./Launch-nopicker.sh

USER arch

ENV USER arch


#### libguestfs versioning

# 5.13+ problem resolved by building the qcow2 against 5.12 using libguestfs-1.44.1-6

ENV SUPERMIN_KERNEL=/boot/vmlinuz-linux
ENV SUPERMIN_MODULES=/lib/modules/5.12.14-arch1-1
ENV SUPERMIN_KERNEL_VERSION=5.12.14-arch1-1
ENV KERNEL_PACKAGE_URL=https://archive.archlinux.org/packages/l/linux/linux-5.12.14.arch1-1-x86_64.pkg.tar.zst
ENV KERNEL_HEADERS_PACKAGE_URL=https://archive.archlinux.org/packages/l/linux/linux-headers-5.12.14.arch1-1-x86_64.pkg.tar.zst
ENV LIBGUESTFS_PACKAGE_URL=https://archive.archlinux.org/packages/l/libguestfs/libguestfs-1.44.1-6-x86_64.pkg.tar.zst

RUN sudo pacman -Syy \
    && sudo pacman -Rns linux --noconfirm \
    ; sudo pacman -S mkinitcpio --noconfirm \
    && sudo pacman -U "${KERNEL_PACKAGE_URL}" --noconfirm \
    && sudo pacman -U "${LIBGUESTFS_PACKAGE_URL}" --noconfirm \
    && rm -rf /var/tmp/.guestfs-* \
    ; libguestfs-test-tool || exit 1

####

# symlink the old directory, for redundancy
RUN ln -s /home/arch/OSX-KVM/OpenCore /home/arch/OSX-KVM/OpenCore-Catalina || true

####

#### SPECIAL RUNTIME ARGUMENTS BELOW

# env -e ADDITIONAL_PORTS with a comma
# for example, -e ADDITIONAL_PORTS=hostfwd=tcp::23-:23,
ENV ADDITIONAL_PORTS=

# add additional QEMU boot arguments
ENV BOOT_ARGS=

ENV BOOTDISK=

# edit the CPU that is being emulated
ENV CPU=Penryn
ENV CPUID_FLAGS='vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check,'

ENV DISPLAY=:0.0

# Deprecated
ENV ENV=/env

# Boolean for generating a bootdisk with new random serials.
ENV GENERATE_UNIQUE=false

# Boolean for generating a bootdisk with specific serials.
ENV GENERATE_SPECIFIC=false

ENV IMAGE_PATH=/home/arch/OSX-KVM/mac_hdd_ng.img
ENV IMAGE_FORMAT=qcow2

ENV KVM='accel=kvm:tcg'

ENV MASTER_PLIST_URL="https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom.plist"

# ENV NETWORKING=e1000-82545em
ENV NETWORKING=vmxnet3

# boolean for skipping the disk selection menu at in the boot process
ENV NOPICKER=false

# dynamic RAM options for runtime
ENV RAM=3
# ENV RAM=max
# ENV RAM=half

# The x and y coordinates for resolution.
# Must be used with either -e GENERATE_UNIQUE=true or -e GENERATE_SPECIFIC=true.
ENV WIDTH=1920
ENV HEIGHT=1080

# libguestfs verbose
ENV LIBGUESTFS_DEBUG=1
ENV LIBGUESTFS_TRACE=1

VOLUME ["/tmp/.X11-unix"]

CMD test -f /home/arch/OSX-KVM/OpenCore/OpenCore.qcow2 || sudo touch /dev/kvm /dev/snd "${BOOTDISK}" "${ENV}" 2>/dev/null || true \
    ; sudo chown -R $(id -u):$(id -g) /dev/kvm /dev/snd "${BOOTDISK}" "${ENV}" 2>/dev/null || true \
    ; [[ "${NOPICKER}" == true ]] && { \
        sed -i '/^.*InstallMedia.*/d' Launch.sh \
        && export BOOTDISK="${BOOTDISK:=/home/arch/OSX-KVM/OpenCore/OpenCore-nopicker.qcow2}" \
    ; } \
    || export BOOTDISK="${BOOTDISK:=/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2}" \
    ; [[ "${GENERATE_UNIQUE}" == true ]] && { \
        ./Docker-OSX/osx-serial-generator/generate-unique-machine-values.sh \
            --master-plist-url="${MASTER_PLIST_URL}" \
            --count 1 \
            --tsv ./serial.tsv \
            --bootdisks \
            --width "${WIDTH:-1920}" \
            --height "${HEIGHT:-1080}" \
            --output-bootdisk "${BOOTDISK:=/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2}" \
            --output-env "${ENV:=/env}" \
    || exit 1 ; } \
    ; [[ "${GENERATE_SPECIFIC}" == true ]] && { \
            source "${ENV:=/env}" 2>/dev/null \
            ; ./Docker-OSX/osx-serial-generator/generate-specific-bootdisk.sh \
            --master-plist-url="${MASTER_PLIST_URL}" \
            --model "${DEVICE_MODEL}" \
            --serial "${SERIAL}" \
            --board-serial "${BOARD_SERIAL}" \
            --uuid "${UUID}" \
            --mac-address "${MAC_ADDRESS}" \
            --width "${WIDTH:-1920}" \
            --height "${HEIGHT:-1080}" \
            --output-bootdisk "${BOOTDISK:=/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2}" \
    || exit 1 ; } \
    ; ./enable-ssh.sh && /bin/bash -c ./Launch.sh

# virt-manager mode: eta son
# CMD virsh define <(envsubst < Docker-OSX.xml) && virt-manager || virt-manager
# CMD virsh define <(envsubst < macOS-libvirt-Catalina.xml) && virt-manager || virt-manager
