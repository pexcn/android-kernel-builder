#!/bin/sh
# shellcheck disable=SC1090,SC2086,SC2155,SC2103,SC2164,SC3043

CUR_DIR=$(dirname "$(readlink -f "$0")")

prepare_env() {
  . profile/${BUILD_PROFILE}
  mkdir build
}

setup_clang() {
  cd build

  local clang_pack="$(basename $CLANG_URL)"
  mkdir clang
  wget $CLANG_URL
  tar -C clang/ -zxf $clang_pack
  rm $clang_pack

  cd -
}

setup_gcc() {
  cd build

  local gcc_pack="$(basename $GCC_URL)"
  mkdir gcc
  wget $GCC_URL
  tar -C gcc/ -zxvf $gcc_pack
  rm $gcc_pack

  cd -
}

get_sources() {
  git clone $KERNEL_SOURCE build/kernel
  cd build/kernel
  
  # checkout version
  git checkout $KERNEL_VERSION

  # remove `-dirty` of version
  sed -i 's/ -dirty//g' scripts/setlocalversion

  # integrate kernelsu-next
  curl -sSL "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -s $KSU_NEXT_VERSION

  cd -
}

build_kernel() {
  cd build/kernel

  export KBUILD_COMPILER_STRING="$(clang --version | head -1 | sed 's/ (https.*//')"
  export KBUILD_BUILD_HOST=GitHub
  export KBUILD_BUILD_USER=pexcn
  export BRAND_SHOW_FLAG=oneplus

  export ARCH=arm64
  export SUBARCH=arm64
  make -j$(($(nproc) + 1)) vendor/kona-perf_defconfig vendor/debugfs.config \
    ARCH=arm64 \
    O=out \
    LD=ld.lld \
    LLVM=1 \
    LLVM_IAS=1 \
    || exit 1

  echo $CUR_DIR

  cd -
}

#package_output() {
#  local output_dir="build/kernel/out"
#  local tarball="${BUILD_PROFILE}.tar.gz"
#  tar -zcvf $tarball -C $output_dir $(ls $output_dir -1)
#}

prepare_env
setup_clang
setup_gcc
get_sources
build_kernel

