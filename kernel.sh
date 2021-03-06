#!/bin/bash

# We're building IMMENSiTY.
cd ..

# Export compiler type
if [[ "$@" =~ "clang"* ]]; then
	export COMPILER="BenzoClang-12.0"
elif [[ "$@" =~ "lto"* ]]; then
	export COMPILER="ProtonClang-12.0 LTO"
elif [[ "$@" =~ "proton"* ]]; then
	export COMPILER="ProtonClang-12.0"
elif [[ "$@" =~ "gcc"* ]]; then
	export COMPILER="Bare Metal GCC-10.2.0"
else
	export COMPILER="ProtonClang-12.0"
fi

# Export correct version
if [[ "$@" =~ "beta"* ]]; then
	if [[ "$@" =~ "lto"* ]]; then
		export TYPE=beta-LTO
	else
                export TYPE=beta
	fi
	export VERSION="IMMENSiTY-AUTO-RAPHAEL-${TYPE}${DRONE_BUILD_NUMBER}"
	export INC="$(echo ${RC} | grep -o -E '[0-9]+')"
	INC="$((INC + 1))"
else
	if [[ "$@" =~ "lto"* ]]; then
		export TYPE=C.I-LTO
	else
                export TYPE=C.I
	fi
	export VERSION="IMMENSiTY-AUTO-RAPHAEL-${TYPE}"
fi

export ZIPNAME="${VERSION}.zip"

# How much kebabs we need? Kanged from @raphielscape :)
if [[ -z "${KEBABS}" ]]; then
	COUNT="$(grep -c '^processor' /proc/cpuinfo)"
	export KEBABS="$((COUNT * 2))"
fi

# Post to CI channel
curl -s -X POST https://api.telegram.org/bot${BOT_API_KEY}/SendAnimation -d animation=https://thumbs.gfycat.com/TidyOccasionalIncatern-size_restricted.gif -d chat_id=${CI_CHANNEL_ID}
curl -s -X POST https://api.telegram.org/bot${BOT_API_KEY}/sendMessage -d text="Kernel: <code>IMMENSiTY KERNAL</code>
Type: <code>${TYPE}</code>
Device: <code>XiaoMi Redmi K20 Pro (raphael)</code>
Compiler: <code>${COMPILER}</code>
Branch: <code>$(git rev-parse --abbrev-ref HEAD)</code>
<i>Build started on Drone Cloud...</i>
Check the build status here: https://cloud.drone.io/UtsavBalar1231/kernel_xiaomi_raphael/${DRONE_BUILD_NUMBER}" -d chat_id=${CI_CHANNEL_ID} -d parse_mode=HTML
curl -s -X POST https://api.telegram.org/bot${BOT_API_KEY}/sendMessage -d text="Build started for revision ${DRONE_BUILD_NUMBER}" -d chat_id=${CI_CHANNEL_ID} -d parse_mode=HTML

# Make is shit so I have to pass thru some toolchains
# Let's build, anyway
START=$(date +"%s")
make O=out ARCH=arm64 raphael_defconfig
if [[ "$@" =~ "clang"* ]]; then
	PATH=/drone/src/clang/bin:/drone/src/gcc/bin:/drone/src/gcc32/bin:${PATH}
	make ARCH=arm64 \
		O=out \
		CC="clang" \
		CLANG_TRIPLE="aarch64-linux-gnu-" \
		CROSS_COMPILE="aarch64-linux-android-" \
		CROSS_COMPILE_ARM32="arm-linux-androideabi-" \
		-j${KEBABS}
elif [[ "$@" =~ "lto"* ]]; then
scripts/config --file out/.config \
	        -e LTO \
	        -e LTO_CLANG \
		-d THINLTO \
	        -e SHADOW_CALL_STACK \
	        -e TOOLS_SUPPORT_RELR \
	        -e LD_LLD
cd out

make O=out \
        ARCH=arm64 \
        olddefconfig
cd ../

PATH=/drone/src/clang/bin/:$PATH
	make ARCH=arm64 \
		O=out \
		CC="clang" \
		LD="ld.lld" \
		AR="llvm-ar" \
		NM="llvm-nm" \
		OBJCOPY="llvm-objcopy" \
		OBJDUMP="llvm-objdump" \
	        OBJSIZE="llvm-size" \
		READELF="llvm-readelf" \
		STRIP="llvm-strip" \
		CLANG_TRIPLE="aarch64-linux-gnu-" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
		-j${KEBABS}
elif [[ "$@" =~ "proton"* ]]; then
scripts/config --file out/.config \
	        -d LTO \
	        -d LTO_CLANG \
		-d THINLTO \
	        -e SHADOW_CALL_STACK \
	        -e TOOLS_SUPPORT_RELR \
	        -e LD_LLD
cd out

make O=out \
        ARCH=arm64 \
        olddefconfig
cd ../

PATH=/drone/src/clang/bin/:$PATH
	make ARCH=arm64 \
		O=out \
		CC="clang" \
		LD="ld.lld" \
		AR="llvm-ar" \
		NM="llvm-nm" \
		OBJCOPY="llvm-objcopy" \
		OBJDUMP="llvm-objdump" \
	        OBJSIZE="llvm-size" \
		READELF="llvm-readelf" \
		STRIP="llvm-strip" \
		CLANG_TRIPLE="aarch64-linux-gnu-" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
		-j${KEBABS}
elif [[ "$@" =~ "gcc"* ]]; then
	PATH=/drone/src/gcc/bin:/drone/src/gcc32/bin:${PATH}
	make ARCH=arm64 \
		O=out \
		CROSS_COMPILE="aarch64-elf-" \
		CROSS_COMPILE_ARM32="arm-eabi-" \
		-j${KEBABS}
else
	PATH=/drone/src/clang/bin/:$PATH
	make ARCH=arm64 \
		O=out \
		CC="clang" \
		LD="ld.lld" \
		AR="llvm-ar" \
		NM="llvm-nm" \
		OBJCOPY="llvm-objcopy" \
		OBJDUMP="llvm-objdump" \
		OBJSIZE="llvm-size" \
		READELF="llvm-readelf" \
		STRIP="llvm-strip" \
		CLANG_TRIPLE="aarch64-linux-gnu-" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
                -j${KEBABS}
fi
END=$(date +"%s")
DIFF=$(( END - START))

cp $(pwd)/out/arch/arm64/boot/Image.gz-dtb $(pwd)/anykernel/
cp $(pwd)/out/arch/arm64/boot/dtbo.img $(pwd)/anykernel/

# POST ZIP OR FAILURE
cd anykernel
zip -r9 ${ZIPNAME} *
CHECKER=$(ls -l ${ZIPNAME} | awk '{print $5}')

if (($((CHECKER / 1048576)) > 5)); then
	curl -s -X POST https://api.telegram.org/bot${BOT_API_KEY}/sendMessage -d text="Kernel compiled successfully in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds for Raphael" -d chat_id=${CI_CHANNEL_ID} -d parse_mode=HTML
	curl -F chat_id="${CI_CHANNEL_ID}" -F document=@"$(pwd)/${ZIPNAME}" https://api.telegram.org/bot${BOT_API_KEY}/sendDocument
else
	curl -s -X POST https://api.telegram.org/bot${BOT_API_KEY}/sendMessage -d text="Error in build!!" -d chat_id=${CI_CHANNEL_ID}
	exit 1;
fi

rm -rf ${ZIPNAME} && rm -rf Image.gz-dtb
