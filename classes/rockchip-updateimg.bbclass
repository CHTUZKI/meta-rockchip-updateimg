# Pack Yocto deploy artifacts into Rockchip update.img (RKDevTool / upgrade_tool).

inherit rockchip-image

do_image_complete[depends] += "rk-binary-native:do_populate_sysroot ${RK_UPDATEIMG_EXTRA_DEPENDS}"

RK_UPDATEIMG_ENABLE ?= "1"
RK_UPDATEIMG_STRICT ?= "1"
RK_UPDATEIMG_IMAGE_TYPE ?= "wic"
RK_UPDATEIMG_ROOTFS_TYPE ?= "${RK_ROOTFS_TYPE}"
RK_UPDATEIMG_ROOTDEV ?= "PARTLABEL=root"
RK_UPDATEIMG_FIRMWARE_VER ?= "1.0"
RK_UPDATEIMG_TABLE_TYPE ?= "GPT"
RK_UPDATEIMG_OS_TYPE ?= "androidos"
# rkImageMaker only accepts RKOS|ANDROIDOS (not "linux"). Rockchip Linux SDKs
# also use androidos for update.img containers; this does not mean Android OS.
RK_UPDATEIMG_SOC ?= "auto"
RK_UPDATEIMG_PARAMETER_MODE ?= "gpt"
RK_UPDATEIMG_PARAMETER_CMDLINE ?= ""
RK_UPDATEIMG_MTD_PARTITIONS ?= ""
RK_UPDATEIMG_EXTRA_DEPENDS ?= "virtual/bootloader:do_deploy"
RK_UPDATEIMG_REQUIRED_IMAGES ?= "loader.bin rootfs.img"
RK_UPDATEIMG_OPTIONAL_IMAGES ?= "trust.img"
RK_UPDATEIMG_FLASH_IDBLOCK ?= "1"
# Must match misc partition size in parameter (0x800 sectors x 512B = 1 MiB)
RK_UPDATEIMG_MISC_SIZE_KB ?= "1024"
RK_UPDATEIMG_FIXED_PARTITIONS ?= ""
RK_UPDATEIMG_PACKAGE_IMAGES ?= "loader.bin idblock.img uboot.env uboot.img boot.img rootfs.img system.img vendor.img oem.img userdata.img recovery.img misc.img dtbo.img vbmeta.img parameter.img resource.img kernel.img"
RK_UPDATEIMG_IDBLOCK_CANDIDATES ?= "idblock.img"
RK_UPDATEIMG_PARTITION_IMAGE_MAP ?= "root:rootfs.img rootfs:rootfs.img system:rootfs.img system_a:rootfs.img system_b:rootfs.img uboot-env:uboot.env backup:RESERVED"
RK_UPDATEIMG_LOADER_CANDIDATES ?= "loader.bin MiniLoaderAll.bin mini_loader.bin"
RK_UPDATEIMG_UBOOT_CANDIDATES ?= "uboot.img u-boot.img uboot-${MACHINE}.img u-boot-${MACHINE}.img ${UBOOT_SYMLINK} ${UBOOT_BINARY}"
RK_UPDATEIMG_BOOT_CANDIDATES ?= "boot.img zboot.img"
RK_UPDATEIMG_TRUST_CANDIDATES ?= "trust.img trust.bin"
RK_UPDATEIMG_ROOTFS_CANDIDATES ?= "${IMAGE_LINK_NAME}.${RK_UPDATEIMG_ROOTFS_TYPE} ${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${RK_UPDATEIMG_ROOTFS_TYPE} rootfs.img rootfs.${RK_UPDATEIMG_ROOTFS_TYPE}"
RK_UPDATEIMG_WIC_CANDIDATES ?= "${IMAGE_LINK_NAME}.${RK_UPDATEIMG_IMAGE_TYPE} ${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${RK_UPDATEIMG_IMAGE_TYPE}"
RK_UPDATEIMG_OUTPUT ?= "${IMAGE_LINK_NAME}.update.img"
RK_UPDATEIMG_LINK_NAME ?= "update.img"

rockchip_updateimg_find_file() {
    result_var="$1"
    shift
    found=""
    for name in "$@"; do
        if [ -z "${name}" ]; then
            continue
        fi
        case "${name}" in
            /*)
                paths="${name}"
                ;;
            *)
                paths="${IMGDEPLOYDIR}/${name} ${DEPLOY_DIR_IMAGE}/${name}"
                ;;
        esac
        for path in ${paths}; do
            if [ -f "${path}" ] || [ -L "${path}" ]; then
                found="${path}"
                break 2
            fi
        done
    done
    eval ${result_var}="\"${found}\""
}

rockchip_updateimg_link_file() {
    link_name="$1"
    source_path="$2"
    if [ -z "${source_path}" ]; then
        return 1
    fi
    rel_path=$(realpath --relative-to="${IMGDEPLOYDIR}" "${source_path}")
    ln -sf "${rel_path}" "${IMGDEPLOYDIR}/${link_name}"
}

rockchip_updateimg_resolve_partition_image() {
    part_name="$1"
    default_image="${part_name}.img"
    for item in ${RK_UPDATEIMG_PARTITION_IMAGE_MAP}; do
        key="${item%%:*}"
        value="${item#*:}"
        if [ "${key}" = "${part_name}" ]; then
            echo "${value}"
            return
        fi
    done
    case "${part_name}" in
        *_a|*_b)
            echo "${part_name%_*}.img"
            ;;
        *)
            echo "${default_image}"
            ;;
    esac
}

rockchip_updateimg_detect_soc() {
    loader="$1"
    if [ "${RK_UPDATEIMG_SOC}" != "auto" ] && [ -n "${RK_UPDATEIMG_SOC}" ]; then
        echo "${RK_UPDATEIMG_SOC}"
        return
    fi
    soc=$(hexdump -s 21 -n 4 -e '4/1 "%c"' "${loader}" 2>/dev/null | rev)
    if [ -n "${soc}" ]; then
        echo "${soc}"
    fi
}

rockchip_updateimg_gen_parameter() {
    if [ "${RK_UPDATEIMG_ENABLE}" != "1" ]; then
        bbnote "Rockchip update.img generation is disabled"
        return
    fi

    cd "${IMGDEPLOYDIR}"
    out="${IMAGE_LINK_NAME}.parameter"
    ln -sf "${out}" parameter

    case "${RK_UPDATEIMG_PARAMETER_MODE}" in
        gpt)
            rockchip_updateimg_find_file disk_image ${RK_UPDATEIMG_WIC_CANDIDATES}
            if [ -z "${disk_image}" ]; then
                bbfatal "Rockchip update.img requires a ${RK_UPDATEIMG_IMAGE_TYPE} disk image in gpt mode. Add '${RK_UPDATEIMG_IMAGE_TYPE}' to IMAGE_FSTYPES or adjust RK_UPDATEIMG_WIC_CANDIDATES."
            fi
            ;;
        manual|mtd)
            disk_image=""
            ;;
        *)
            bbfatal "Unsupported RK_UPDATEIMG_PARAMETER_MODE: ${RK_UPDATEIMG_PARAMETER_MODE}. Supported values are gpt, manual and mtd."
            ;;
    esac

    if [ -n "${disk_image}" ]; then
        echo "# IMAGE_NAME: $(basename ${disk_image})" > "${out}"
    else
        echo "# IMAGE_NAME: ${RK_UPDATEIMG_OUTPUT}" > "${out}"
    fi
    echo "FIRMWARE_VER: ${RK_UPDATEIMG_FIRMWARE_VER}" >> "${out}"
    echo "TYPE: ${RK_UPDATEIMG_TABLE_TYPE}" >> "${out}"

    if [ -n "${RK_UPDATEIMG_PARAMETER_CMDLINE}" ]; then
        echo "CMDLINE: ${RK_UPDATEIMG_PARAMETER_CMDLINE}" >> "${out}"
    elif [ "${RK_UPDATEIMG_PARAMETER_MODE}" = "manual" ]; then
        bbfatal "RK_UPDATEIMG_PARAMETER_CMDLINE must be set when RK_UPDATEIMG_PARAMETER_MODE = \"manual\"."
    elif [ "${RK_UPDATEIMG_PARAMETER_MODE}" = "mtd" ]; then
        if [ -z "${RK_UPDATEIMG_MTD_PARTITIONS}" ]; then
            bbfatal "RK_UPDATEIMG_MTD_PARTITIONS must be set when RK_UPDATEIMG_PARAMETER_MODE = \"mtd\"."
        fi
        echo "CMDLINE: mtdparts=rk29xxnand:${RK_UPDATEIMG_MTD_PARTITIONS}" >> "${out}"
    else
        echo -n "CMDLINE: mtdparts=rk29xxnand:" >> "${out}"

        for item in ${RK_UPDATEIMG_FIXED_PARTITIONS}; do
            name="${item%%:*}"
            rest="${item#*:}"
            start="${rest%%:*}"
            size="${rest#*:}"
            printf "0x%08x@0x%08x(%s)," ${size} ${start} ${name} >> "${out}"
        done

        if [ "${RK_UPDATEIMG_PARAMETER_MODE}" = "gpt" ]; then
            sgdisk -p "${disk_image}" | grep -E "^ +[0-9]" | while read line; do
                name=$(echo ${line} | awk '{print $7}')
                start=$(echo ${line} | awk '{print $2}')
                end=$(echo ${line} | awk '{print $3}')
                size=$(expr ${end} - ${start} + 1)
                if [ -n "${name}" ] && [ -n "${start}" ] && [ -n "${size}" ]; then
                    printf "0x%08x@0x%08x(%s)," ${size} ${start} ${name} >> "${out}"
                fi
            done
        fi
        echo >> "${out}"
    fi
    echo "root: ${RK_UPDATEIMG_ROOTDEV}" >> "${out}"
    if [ -n "${RK_ROOTDEV_UUID}" ]; then
        root_part=$(echo "${RK_UPDATEIMG_ROOTDEV}" | sed 's/^PARTLABEL=//')
        echo "uuid:${root_part}=${RK_ROOTDEV_UUID}" >> "${out}"
    fi
}

rockchip_updateimg_prepare_misc() {
    cd "${IMGDEPLOYDIR}"
    if [ -f misc.img ] || [ -L misc.img ]; then
        return
    fi
    bbnote "Creating empty misc.img (${RK_UPDATEIMG_MISC_SIZE_KB} KiB) for Rockchip update.img"
    dd if=/dev/zero of=misc.img bs=1024 count=${RK_UPDATEIMG_MISC_SIZE_KB} 2>/dev/null
}

rockchip_updateimg_prepare_files() {
    cd "${IMGDEPLOYDIR}"

    rockchip_updateimg_prepare_misc

    rockchip_updateimg_find_file loader_src ${RK_UPDATEIMG_LOADER_CANDIDATES}
    if [ -z "${loader_src}" ]; then
        loader_src=$(ls -1 "${DEPLOY_DIR_IMAGE}"/loader.bin-* 2>/dev/null | head -1)
    fi
    rockchip_updateimg_find_file uboot_src ${RK_UPDATEIMG_UBOOT_CANDIDATES}
    rockchip_updateimg_find_file boot_src ${RK_UPDATEIMG_BOOT_CANDIDATES}
    rockchip_updateimg_find_file trust_src ${RK_UPDATEIMG_TRUST_CANDIDATES}
    rockchip_updateimg_find_file idblock_src ${RK_UPDATEIMG_IDBLOCK_CANDIDATES}
    if [ -z "${idblock_src}" ]; then
        idblock_src=$(ls -1 "${DEPLOY_DIR_IMAGE}"/idblock.img-* 2>/dev/null | head -1)
    fi
    rockchip_updateimg_find_file rootfs_src ${RK_UPDATEIMG_ROOTFS_CANDIDATES}

    rockchip_updateimg_link_file loader.bin "${loader_src}" || true
    rockchip_updateimg_link_file uboot.img "${uboot_src}" || true
    rockchip_updateimg_link_file boot.img "${boot_src}" || true
    rockchip_updateimg_link_file trust.img "${trust_src}" || true
    rockchip_updateimg_link_file idblock.img "${idblock_src}" || true
    rockchip_updateimg_link_file rootfs.img "${rootfs_src}" || true

    for image_name in ${RK_UPDATEIMG_PACKAGE_IMAGES}; do
        if [ -f "${image_name}" ] || [ -L "${image_name}" ]; then
            continue
        fi
        case "${image_name}" in
            loader.bin|idblock.img|uboot.img|boot.img|trust.img|rootfs.img|misc.img)
                continue
                ;;
        esac
        if [ -f "${DEPLOY_DIR_IMAGE}/${image_name}" ] || [ -L "${DEPLOY_DIR_IMAGE}/${image_name}" ]; then
            rockchip_updateimg_link_file "${image_name}" "${DEPLOY_DIR_IMAGE}/${image_name}" || true
        fi
    done

    for image_name in ${RK_UPDATEIMG_REQUIRED_IMAGES}; do
        if [ ! -f "${image_name}" ] && [ ! -L "${image_name}" ]; then
            if [ "${RK_UPDATEIMG_STRICT}" = "1" ]; then
                bbfatal "Required Rockchip update image input is missing: ${image_name}"
            else
                bbwarn "Required Rockchip update image input is missing: ${image_name}"
                return 1
            fi
        fi
    done

    for image_name in ${RK_UPDATEIMG_OPTIONAL_IMAGES}; do
        if [ ! -f "${image_name}" ] && [ ! -L "${image_name}" ]; then
            bbnote "Optional Rockchip update image input is missing: ${image_name}"
        fi
    done
}

rockchip_updateimg_gen_package_file() {
    cd "${IMGDEPLOYDIR}"
    out="${IMAGE_LINK_NAME}.package-file"
    ln -sf "${out}" package-file

    printf '# IMAGE_NAME: %s\n' "${RK_UPDATEIMG_OUTPUT}" > "${out}"
    printf 'package-file\tpackage-file\n' >> "${out}"
    printf 'bootloader\tloader.bin\n' >> "${out}"
    if [ "${RK_UPDATEIMG_FLASH_IDBLOCK}" = "1" ]; then
        if [ -r idblock.img ] || [ -L idblock.img ]; then
            printf 'idblock\tidblock.img\n' >> "${out}"
        elif [ "${RK_UPDATEIMG_STRICT}" = "1" ]; then
            bbfatal "Rockchip update.img requires idblock.img when RK_UPDATEIMG_FLASH_IDBLOCK = \"1\"."
        else
            bbwarn "Rockchip update.img: idblock.img missing, eMMC may not boot after upgrade"
        fi
    fi
    printf 'parameter\tparameter\n' >> "${out}"

    grep -oE '\([^)^:]*' parameter | tr -d '(' | sed 's/:grow$//' | while read name; do
        [ -n "${name}" ] || continue
        image=$(rockchip_updateimg_resolve_partition_image "${name}")
        if [ "${image}" = "RESERVED" ]; then
            printf '%s\tRESERVED\n' "${name}" >> "${out}"
        elif [ -r "${image}" ] || [ -L "${image}" ]; then
            printf '%s\t%s\n' "${name}" "${image}" >> "${out}"
        else
            bbwarn "Rockchip update.img: partition ${name} maps to ${image}, file missing"
        fi
    done
}

rockchip_updateimg_pack() {
    if [ "${RK_UPDATEIMG_ENABLE}" != "1" ]; then
        return
    fi

    rockchip_updateimg_prepare_files || return
    rockchip_updateimg_gen_package_file

    cd "${IMGDEPLOYDIR}"
    PSEUDO_DISABLED=1 ${STAGING_BINDIR_NATIVE}/afptool -pack ./ update.raw.img || bbfatal "afptool failed while packing Rockchip update.raw.img"

    soc=$(rockchip_updateimg_detect_soc loader.bin)
    if [ -z "${soc}" ]; then
        bbfatal "Cannot detect Rockchip SoC ID from loader.bin. Set RK_UPDATEIMG_SOC explicitly, for example RK_UPDATEIMG_SOC = \"350F\" for RK3506."
    fi

    PSEUDO_DISABLED=1 ${STAGING_BINDIR_NATIVE}/rkImageMaker -RK${soc} loader.bin update.raw.img "${RK_UPDATEIMG_OUTPUT}" -os_type:${RK_UPDATEIMG_OS_TYPE} || bbfatal "rkImageMaker failed while creating ${RK_UPDATEIMG_OUTPUT}"
    ln -sf "${RK_UPDATEIMG_OUTPUT}" "${RK_UPDATEIMG_LINK_NAME}"
    rm -f update.raw.img
}

rockchip_updateimg_cleanup() {
    rm -f ${IMGDEPLOYDIR}/update.raw.img
    rm -f ${IMGDEPLOYDIR}/package-file ${IMGDEPLOYDIR}/*.package-file
    rm -f ${IMGDEPLOYDIR}/parameter ${IMGDEPLOYDIR}/*.parameter
    rm -f ${IMGDEPLOYDIR}/${RK_UPDATEIMG_OUTPUT} ${IMGDEPLOYDIR}/${RK_UPDATEIMG_LINK_NAME}
}

IMAGE_POSTPROCESS_COMMAND:append = " rockchip_updateimg_gen_parameter; rockchip_updateimg_pack;"
do_clean[postfuncs] += "rockchip_updateimg_cleanup"
do_cleanall[postfuncs] += "rockchip_updateimg_cleanup"
