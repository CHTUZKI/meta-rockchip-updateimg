# Generic Rockchip image helpers shared by BSP layers.
# - rootfs.img symlink for update.img packaging
# - WIC template fixup when optional raw images are absent

export RK_ROOTFS_TYPE ?= "ext4"
export RK_ROOTFS_EXTRAOPTS ?= "-F -i 8192 -b 4096"

IMAGE_POSTPROCESS_COMMAND:append = " rockchip_link_rootfs_image;"
rockchip_link_rootfs_image() {
    ln -sf "${IMAGE_LINK_NAME}.${RK_ROOTFS_TYPE}" "${IMGDEPLOYDIR}/rootfs.img"
}

do_fixup_wks[depends] += " \
    virtual/kernel:do_deploy \
    virtual/bootloader:do_deploy \
"
do_fixup_wks() {
    [ -f "${WKS_FULL_PATH}" ] || return

    for image in $(grep -oE 'file=[^" ]+\.img' "${WKS_FULL_PATH}" | cut -d= -f2); do
        if [ ! -f "${DEPLOY_DIR_IMAGE}/${image}" ]; then
            bbnote "${image} not provided, removing from WIC layout"
            sed -i "/file=${image}/d" "${WKS_FULL_PATH}"
        fi
    done
}
addtask do_fixup_wks after do_write_wks_template before do_image_wic
