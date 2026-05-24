# meta-rockchip-updateimg

`meta-rockchip-updateimg` is a reusable Yocto layer for packaging standard Yocto image outputs into Rockchip `update.img` firmware files that can be flashed by RKDevTool or Rockchip `upgrade_tool`.

This layer is intended for Rockchip SoCs such as RK3288, RK3399, RK3506, RK3566, RK3568, RK3588 and similar chips. The layer only packages firmware; it does not generate DDR, miniloader, ATF, U-Boot or board-specific boot binaries by itself.

## Scope

This layer provides:

- `rk-binary-native`, which installs Rockchip native packaging tools such as `afptool` and `rkImageMaker`.
- `rockchip-updateimg.bbclass`, which generates:
  - `parameter`
  - `package-file`
  - `update.raw.img`
  - `<image>.update.img`
  - `update.img` symlink

This layer expects the board or BSP layer to provide Rockchip boot inputs in `${DEPLOY_DIR_IMAGE}` or `${IMGDEPLOYDIR}`.

## Boot media support

The layer can be used for images intended for eMMC, SD card, SPI NAND, raw NAND or other Rockchip-supported storage media. The actual boot medium is not selected by this layer. It is controlled by the board boot chain, U-Boot configuration, kernel command line, partition layout and Rockchip loader behavior.

This layer focuses on the Rockchip firmware container format:

- eMMC and SD card normally use `RK_UPDATEIMG_PARAMETER_MODE = "gpt"`.
- NAND and MTD-style layouts normally use `RK_UPDATEIMG_PARAMETER_MODE = "mtd"` or `manual`.
- Special vendor layouts can use `manual` with a fully custom `RK_UPDATEIMG_PARAMETER_CMDLINE`.

## Required inputs

At minimum, the packaging class requires:

- A Yocto disk image, normally `${IMAGE_LINK_NAME}.wic`
- `loader.bin` or a compatible loader file
- A root filesystem image, normally `${IMAGE_LINK_NAME}.ext4`

Most complete Rockchip firmware packages also provide:

- `uboot.img`
- `trust.img` or `trust.bin`
- `boot.img` if the partition layout contains a `boot` partition

## Usage

Add the layer:

```bash
bitbake-layers add-layer /path/to/meta-rockchip-updateimg
```

Enable it in an image recipe:

```bitbake
inherit rockchip-updateimg

IMAGE_FSTYPES += "wic ext4"
```

Then build your image:

```bash
bitbake core-image-minimal
```

Expected output:

```text
tmp/deploy/images/<machine>/<image>-<machine>.update.img
tmp/deploy/images/<machine>/update.img
```

## Common configuration

```bitbake
RK_UPDATEIMG_SOC = "RK3399"
RK_UPDATEIMG_ROOTDEV = "PARTLABEL=root"
RK_UPDATEIMG_REQUIRED_IMAGES = "loader.bin rootfs.img"
RK_UPDATEIMG_EXTRA_DEPENDS = "u-boot-rockchip:do_deploy rk3399-blobs:do_deploy"
```

If `RK_UPDATEIMG_SOC` is left as `auto`, the class tries to detect the SoC ID from `loader.bin` and passes it to `rkImageMaker` as `-RKxxxx`.

## Parameter generation modes

### GPT mode

GPT mode is the default and is best suited for eMMC and SD-card style Yocto images.

```bitbake
RK_UPDATEIMG_PARAMETER_MODE = "gpt"
IMAGE_FSTYPES += "wic ext4"
RK_UPDATEIMG_ROOTDEV = "PARTLABEL=root"
```

The class reads the `.wic` image with `sgdisk`, converts GPT partitions into Rockchip `parameter` entries, and maps partition names to image files.

### MTD mode

MTD mode is intended for NAND-style layouts where the Rockchip `parameter` file should describe an `mtdparts` layout directly.

```bitbake
RK_UPDATEIMG_PARAMETER_MODE = "mtd"
RK_UPDATEIMG_ROOTFS_TYPE = "ubi"
RK_UPDATEIMG_ROOTDEV = "ubi0:rootfs"
RK_UPDATEIMG_MTD_PARTITIONS = "0x00002000@0x00004000(uboot),0x00002000@0x00006000(trust),0x00080000@0x00008000(rootfs:grow)"
RK_UPDATEIMG_ROOTFS_CANDIDATES = "${IMAGE_LINK_NAME}.ubi rootfs.ubi rootfs.img"
RK_UPDATEIMG_PARTITION_IMAGE_MAP += "rootfs:rootfs.img"
```

### Manual mode

Manual mode is intended for vendor-specific or unusual layouts. In this mode, provide the complete Rockchip command line yourself.

```bitbake
RK_UPDATEIMG_PARAMETER_MODE = "manual"
RK_UPDATEIMG_PARAMETER_CMDLINE = "mtdparts=rk29xxnand:0x00002000@0x00004000(uboot),0x00002000@0x00006000(trust),-(rootfs:grow)"
RK_UPDATEIMG_ROOTDEV = "ubi0:rootfs"
```

## Fixed partitions

Some platforms put firmware partitions outside the GPT layout or need explicit Rockchip parameter entries. Use `RK_UPDATEIMG_FIXED_PARTITIONS` for that.

Format:

```text
name:start_sector:size_sectors
```

Example:

```bitbake
RK_UPDATEIMG_FIXED_PARTITIONS = "uboot:0x4000:0x2000 trust:0x6000:0x2000"
```

## Partition to image mapping

The class parses partition names from the generated `parameter` file and maps them to image files. Defaults include:

```text
root -> rootfs.img
system -> rootfs.img
system_a -> rootfs.img
system_b -> rootfs.img
uboot-env -> uboot.env
backup -> RESERVED
```

You can override or extend:

```bitbake
RK_UPDATEIMG_PARTITION_IMAGE_MAP += "userdata:userdata.img vendor:vendor.img oem:oem.img"
```

## Common SoC examples

### RK3399 eMMC or SD

```bitbake
inherit rockchip-updateimg

IMAGE_FSTYPES += "wic ext4"
RK_UPDATEIMG_SOC = "RK3399"
RK_UPDATEIMG_PARAMETER_MODE = "gpt"
RK_UPDATEIMG_ROOTDEV = "PARTLABEL=root"
RK_UPDATEIMG_FIXED_PARTITIONS = "uboot:0x4000:0x2000 trust:0x6000:0x2000"
RK_UPDATEIMG_REQUIRED_IMAGES = "loader.bin uboot.img trust.img rootfs.img"
```

### RK3588 eMMC or SD

```bitbake
inherit rockchip-updateimg

IMAGE_FSTYPES += "wic ext4"
RK_UPDATEIMG_SOC = "RK3588"
RK_UPDATEIMG_PARAMETER_MODE = "gpt"
RK_UPDATEIMG_ROOTDEV = "PARTLABEL=root"
RK_UPDATEIMG_REQUIRED_IMAGES = "loader.bin rootfs.img"
```

### NAND / UBI rootfs

```bitbake
inherit rockchip-updateimg

IMAGE_FSTYPES += "ubi"
RK_UPDATEIMG_SOC = "RK3506"
RK_UPDATEIMG_PARAMETER_MODE = "mtd"
RK_UPDATEIMG_ROOTFS_TYPE = "ubi"
RK_UPDATEIMG_ROOTDEV = "ubi0:rootfs"
RK_UPDATEIMG_MTD_PARTITIONS = "0x00002000@0x00004000(uboot),0x00002000@0x00006000(trust),0x00080000@0x00008000(rootfs:grow)"
RK_UPDATEIMG_ROOTFS_CANDIDATES = "${IMAGE_LINK_NAME}.ubi rootfs.ubi rootfs.img"
RK_UPDATEIMG_PARTITION_IMAGE_MAP += "rootfs:rootfs.img"
```

## Important design rule

Do not make this layer responsible for every SoC's boot chain generation. RK3288, RK3399, RK3506, RK3568 and RK3588 often need different DDR/miniloader/trust generation flows. Keep those in the SoC or board BSP layer, and let this layer only consume the final deploy artifacts.
