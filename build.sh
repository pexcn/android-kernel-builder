#!/bin/bash
# shellcheck disable=SC1090,SC2086,SC2164,SC2103,SC2155

prepare_env() {
  mkdir build
  mkdir download

  # updatable
  CLANG_URL=https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r530567.tar.gz

  # set local shell variables
  source config/$BUILD_CONFIG.conf
  CUR_DIR=$(dirname "$(readlink -f "$0")")
  MAKE_FLAGS=(
    O=out
    ARCH=arm64
    SUBARCH=arm64
    CLANG_TRIPLE=aarch64-linux-android-
    CROSS_COMPILE=aarch64-linux-android-
    CROSS_COMPILE_COMPAT=arm-linux-androideabi-
    CROSS_COMPILE_ARM32=arm-linux-androideabi-
    CC="ccache clang"
    LD=ld.lld
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    READELF=llvm-readelf
    OBJSIZE=llvm-size
    STRIP=llvm-strip
    LLVM=1
    LLVM_IAS=1
    LLVM_AR=llvm-ar
    LLVM_NM=llvm-nm
  )

  # setup clang
  local clang_pack="$(basename $CLANG_URL)"
  [ -f download/$clang_pack ] || wget -q $CLANG_URL -P download
  mkdir build/clang && tar -C build/clang/ -zxf download/$clang_pack

  # set environment variables
  export PATH=$CUR_DIR/build/clang/bin:$PATH
  export ARCH=arm64
  export SUBARCH=arm64
  export KBUILD_BUILD_USER=${GITHUB_REPOSITORY_OWNER:-pexcn}
  export KBUILD_BUILD_HOST=buildbot
  export KBUILD_COMPILER_STRING="$(clang --version | head -1 | sed 's/ (https.*//')"
  export KBUILD_LINKER_STRING="$(ld.lld --version | head -1 | sed 's/ (compatible.*//')"
}

get_sources() {
  [ -d build/kernel/.git ] || git clone $KERNEL_SOURCE build/kernel
  cd build/kernel
  git diff --quiet HEAD || git reset --hard HEAD

  # checkout version
  git checkout $KERNEL_COMMIT

  # remove `-dirty` of version
  sed -i 's/ -dirty//g' scripts/setlocalversion

  cd -
}

add_kernelsu() {
  cd build/kernel

  # integrate kernelsu-next
  curl -sSL "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -s v1.0.4

  # update kernel config
  cat <<-EOF >>arch/arm64/configs/${KERNEL_CONFIG%% *}
	CONFIG_MODULES=y
	CONFIG_KPROBES=y
	CONFIG_HAVE_KPROBES=y
	CONFIG_KPROBE_EVENTS=y
	EOF

  # re-generate kernel config
  make "${MAKE_FLAGS[@]}" $KERNEL_CONFIG savedefconfig
  cp -f out/defconfig arch/arm64/configs/${KERNEL_CONFIG%% *}

  cd -
}

build_kernel() {
  cd build/kernel

  # select kernel config
  make "${MAKE_FLAGS[@]}" $KERNEL_CONFIG
  # compile kernel
  make "${MAKE_FLAGS[@]}" -j$(($(nproc) + 1)) || exit 1

  cd -
}

prepare_env
get_sources
add_kernelsu
build_kernel
