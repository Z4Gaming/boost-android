#!/bin/bash

targetArch=$1
targetOS=android
SRCDIR=../
compiler=gcc

if [[ -z "$targetArch" ]]; then
	echo "Target platform must be specified, armeabi, armeabi-v7a, x86 or mips"
	exit 1
fi

if [[ "$targetArch" != "armeabi" ]] && [[ "$targetArch" != "armeabi-v7a" ]] && [[ "$targetArch" != "x86" ]] && [[ "$targetArch" != "mips" ]]; then
	echo "'armeabi', 'armeabi-v7a', 'x86', 'mips' are the only supported target architectures, while '${targetArch}' was specified"
	exit 1
fi
echo "Going to build Boost for ${targetOS}/${compiler}/${targetArch}"

# Verify environment
if [[ -z "$ANDROID_SDK_ROOT" ]]; then
	echo "ANDROID_SDK_ROOT is not set"
	exit 1
fi

if [[ -z "$ANDROID_NDK_ROOT" ]]; then
	echo "ANDROID_NDK_ROOT is not set"
	exit 1
fi

if [[ "$(uname -a)" =~ Linux ]]; then
	if [[ "$(uname -m)" == x86_64 ]] && [ -d "$ANDROID_NDK_ROOT/prebuilt/linux-x86_64" ]; then
		export ANDROID_NDK_HOST=linux-x86_64
	elif [ -d "$ANDROID_NDK_ROOT/prebuilt/linux-x86" ]; then
		export ANDROID_NDK_HOST=linux-x86
	else
		export ANDROID_NDK_HOST=linux
	fi

	if [[ -z "$OSMAND_BUILD_CPU_CORES_NUM" ]]; then
		OSMAND_BUILD_CPU_CORES_NUM=`nproc`
	fi
elif [[ "$(uname -a)" =~ Darwin ]]; then
	if [[ "$(uname -m)" == x86_64 ]] && [ -d "$ANDROID_NDK_ROOT/prebuilt/darwin-x86_64" ]; then
		export ANDROID_NDK_HOST=darwin-x86_64
	elif [ -d "$ANDROID_NDK_ROOT/prebuilt/darwin-x86" ]; then
		export ANDROID_NDK_HOST=darwin-x86
	else
		export ANDROID_NDK_HOST=darwin
	fi

	if [[ -z "$OSMAND_BUILD_CPU_CORES_NUM" ]]; then
		OSMAND_BUILD_CPU_CORES_NUM=`sysctl hw.ncpu | awk '{print $2}'`
	fi
else
	echo "'$(uname -a)' host is not supported"
	exit 1
fi
if [[ -z "$ANDROID_SDK_ROOT" ]]; then
	echo "ANDROID_NDK_ROOT '${ANDROID_NDK_ROOT}' contains no valid host prebuilt tools"
	exit 1
fi
echo "Using ANDROID_NDK_HOST '${ANDROID_NDK_HOST}'"

export ANDROID_NDK_PLATFORM=android-19
if [[ ! -d "${ANDROID_NDK_ROOT}/platforms/${ANDROID_NDK_PLATFORM}" ]]; then
	echo "Platform '${ANDROID_NDK_ROOT}/platforms/${ANDROID_NDK_PLATFORM}' does not exist"
	exit 1
fi
echo "Using ANDROID_NDK_PLATFORM '${ANDROID_NDK_PLATFORM}'"

export ANDROID_NDK_TOOLCHAIN_VERSION=4.9
echo "Using ANDROID_NDK_TOOLCHAIN_VERSION '${ANDROID_NDK_TOOLCHAIN_VERSION}'"

TOOLCHAIN_PATH=""
if [[ "$targetArch"=="armeabi" ]] || [[ "$targetArch"=="armeabi-v7a" ]]; then
	TOOLCHAIN_PATH="${ANDROID_NDK_ROOT}/toolchains/arm-linux-androideabi-${ANDROID_NDK_TOOLCHAIN_VERSION}"
elif [[ "$targetArch"=="x86" ]]; then
	TOOLCHAIN_PATH="${ANDROID_NDK_ROOT}/toolchains/x86-${ANDROID_NDK_TOOLCHAIN_VERSION}"
elif [[ "$targetArch"=="mips" ]]; then
	TOOLCHAIN_PATH="${ANDROID_NDK_ROOT}/toolchains/mipsel-linux-android-${ANDROID_NDK_TOOLCHAIN_VERSION}"
fi
if [[ ! -d "$TOOLCHAIN_PATH" ]]; then
	echo "Toolchain at '$TOOLCHAIN_PATH' not found"
	exit 1
fi
echo "Using toolchain '${TOOLCHAIN_PATH}'"

# Configuration
BOOST_CONFIGURATION=$(echo "
	--layout=versioned
	--with-thread
	toolset=gcc-android
	target-os=linux
	threading=multi
	link=static
	runtime-link=shared
	variant=release
	threadapi=pthread
	--stagedir=stage/$targetArch
	stage
" | tr '\n' ' ')

# Configure & Build static
echo "Using '${targetOS}.${compiler}-${targetArch}.jam'"
cp "targets/${targetOS}.${compiler}-${targetArch}.jam" "$SRCDIR/project-config.jam"

(cd $SRCDIR && ./b2 clean $BOOST_CONFIGURATION -j 4 && ./b2 $BOOST_CONFIGURATION -j 4)
retcode=$?
if [ $retcode -ne 0 ]; then
	echo "Failed to build 'Boost' for '${targetOS}.${compiler}-${targetArch}', aborting..."
	exit $retcode
fi

exit 0
