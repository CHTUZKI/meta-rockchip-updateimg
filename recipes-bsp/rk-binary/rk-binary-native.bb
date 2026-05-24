SUMMARY = "Rockchip binary firmware packaging tools"
DESCRIPTION = "Native Rockchip tools used to package firmware images, including afptool and rkImageMaker."

LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Proprietary;md5=0557f9d92cf58f2ccdd50f62f8ac0b28"

inherit native

SRC_URI = " \
    git://github.com/JeffyCN/mirrors.git;protocol=https;nobranch=1;branch=rkbin-2021_10_13;name=rkbin;destsuffix=sources/rkbin \
    git://github.com/JeffyCN/mirrors.git;protocol=https;branch=tools;name=tools;destsuffix=sources/tools \
"
SRCREV_rkbin = "c41b714cacd249e3ef69b2bbe774da5095eefd72"
SRCREV_tools = "1a32bc776af52494144fcef6641a73850cee628a"
SRCREV_FORMAT ?= "rkbin_tools"

S = "${UNPACKDIR}/sources"

INSANE_SKIP:${PN} = "already-stripped"
STRIP = "echo"
UNINATIVE_LOADER := ""

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${bindir}

    sources_dir="${S}"
    if [ ! -d "${sources_dir}" ]; then
        sources_dir="${WORKDIR}/sources"
    fi
    if [ ! -d "${sources_dir}" ]; then
        bbfatal "Cannot find Rockchip tools source directory"
    fi

    find ${sources_dir} -type d -name rk_sign_tool -exec rm -rf {} + 2>/dev/null || true

    for tool in afptool rkImageMaker boot_merger trust_merger firmwareMerger kernelimage loaderimage mkkrnlimg resource_tool upgrade_tool; do
        found=""
        for candidate in $(find ${sources_dir} -type f -name ${tool} 2>/dev/null); do
            install -m 0755 ${candidate} ${D}${bindir}/${tool}
            found="1"
            break
        done
        if [ -z "${found}" ]; then
            bbwarn "Rockchip tool ${tool} was not found in ${sources_dir}"
        fi
    done
}
