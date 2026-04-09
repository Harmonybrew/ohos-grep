#!/bin/sh
set -e

# 当前工作目录。拼接绝对路径的时候需要用到这个值。
WORKDIR=$(pwd)

# 如果存在旧的目录和文件，就清理掉
rm -rf *.tar.gz \
    ohos-sdk \
    daily_build.log \
    manifest_tag.xml \
    grep-3.12 \
    grep-3.12-ohos-arm64

# 准备 ohos-sdk
curl -fL -o ohos-sdk-full_6.1-Release.tar.gz https://cidownload.openharmony.cn/version/Master_Version/OpenHarmony_6.1.0.31/20260311_020435/version-Master_Version-OpenHarmony_6.1.0.31-20260311_020435-ohos-sdk-full_6.1-Release.tar.gz
tar -zxf ohos-sdk-full_6.1-Release.tar.gz
rm -rf ohos-sdk-full_6.1-Release.tar.gz ohos-sdk/windows ohos-sdk/ohos
cd ohos-sdk/linux
unzip -q native-*.zip
unzip -q toolchains-*.zip
rm -rf *.zip
cd ../..

# 设置交叉编译所需的环境变量
LLVM_BIN=$WORKDIR/ohos-sdk/linux/native/llvm/bin
export CC=$LLVM_BIN/aarch64-unknown-linux-ohos-clang
export CXX=$LLVM_BIN/aarch64-unknown-linux-ohos-clang++
export LD=$LLVM_BIN/ld.lld
export AR=$LLVM_BIN/llvm-ar
export AS=$LLVM_BIN/llvm-as
export NM=$LLVM_BIN/llvm-nm
export OBJCOPY=$LLVM_BIN/llvm-objcopy
export OBJDUMP=$LLVM_BIN/llvm-objdump
export RANLIB=$LLVM_BIN/llvm-ranlib
export STRIP=$LLVM_BIN/llvm-strip

# 编译 grep
curl -fLO https://ftp.gnu.org/gnu/grep/grep-3.12.tar.gz
tar -zxf grep-3.12.tar.gz
cd grep-3.12
./configure --prefix=$WORKDIR/grep-3.12-ohos-arm64 --host=aarch64-linux gl_cv_func_pthread_rwlock_init=no
make -j$(nproc)
make install
cd ..

# 进行代码签名
cd $WORKDIR/grep-3.12-ohos-arm64
find . -type f \( -perm -0111 -o -name "*.so*" \) | while read FILE; do
    if file -b "$FILE" | grep -iqE "elf|sharedlib|ELF|shared object"; then
        echo "Signing binary file $FILE"
        ORIG_PERM=$(stat -c %a "$FILE")
        $WORKDIR/ohos-sdk/linux/toolchains/lib/binary-sign-tool sign -inFile "$FILE" -outFile "$FILE" -selfSign 1
        chmod "$ORIG_PERM" "$FILE"
    fi
done
cd $WORKDIR

# 履行开源义务，将 license 随制品一起发布
cp grep-3.12/COPYING grep-3.12-ohos-arm64/
cp grep-3.12/AUTHORS grep-3.12-ohos-arm64/

# 打包最终产物
tar -zcf grep-3.12-ohos-arm64.tar.gz grep-3.12-ohos-arm64
