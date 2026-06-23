SUMMARY = "Rockchip firmware packaging tools"
DESCRIPTION = "Native tools used to build update.img: afptool (built from source) and rkImageMaker (prebuilt)."

LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Proprietary;md5=0557f9d92cf58f2ccdd50f62f8ac0b28"

inherit native

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = " \
    git://github.com/neo-technologies/rockchip-mkbootimg.git;protocol=https;branch=master;name=mkbootimg;destsuffix=sources/mkbootimg \
    git://github.com/rockchip-linux/rkbin.git;protocol=https;branch=master;name=rkbin;destsuffix=sources/rkbin \
    file://rkImageMaker \
"

# Pinned revisions avoid git ls-remote at parse time (WSL/network TLS flakes).
SRCREV_mkbootimg ?= "2348690523faee6ce3cea9eb9ff47e8b8d5e1df6"
SRCREV_rkbin ?= "ecb4fcbe954edf38b3ae037d5de6d9f5bccf81f4"
SRCREV_FORMAT = "mkbootimg_rkbin"

S = "${WORKDIR}/sources"

DEPENDS += "openssl-native"

INSANE_SKIP:${PN} = "already-stripped"
STRIP = "echo"

do_configure[noexec] = "1"

do_compile() {
    cd ${WORKDIR}/sources/mkbootimg
    oe_runmake afptool CC="${CC}" LD="${LD}" CFLAGS="${CFLAGS}" \
        LDFLAGS="-L${STAGING_LIBDIR_NATIVE} -lcrypto"
}

do_install() {
    install -d ${D}${bindir}

    install -m 0755 ${WORKDIR}/sources/mkbootimg/afptool ${D}${bindir}/afptool
    install -m 0755 ${WORKDIR}/rkImageMaker ${D}${bindir}/rkImageMaker

    # Optional helpers shipped with rkbin; warn only when absent.
    for tool in boot_merger trust_merger upgrade_tool loaderimage mkkrnlimg; do
        found=""
        for candidate in $(find ${WORKDIR}/sources/rkbin/tools -maxdepth 1 -type f -name ${tool} 2>/dev/null); do
            install -m 0755 ${candidate} ${D}${bindir}/${tool}
            found="1"
            break
        done
        if [ -z "${found}" ]; then
            bbwarn "Rockchip tool ${tool} was not found in rkbin/tools"
        fi
    done
}
