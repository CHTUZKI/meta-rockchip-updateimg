# meta-rockchip-updateimg

**此项目还没有经过任何测试。**

`meta-rockchip-updateimg` 是一个可复用的 Yocto layer，用于将标准 Yocto 镜像输出打包成 Rockchip `update.img` 固件文件，可通过 RKDevTool 或 Rockchip `upgrade_tool` 进行烧录。

本 layer 适用于 RK3288、RK3399、RK3506、RK3566、RK3568、RK3588 等 Rockchip SoC。该 layer 仅负责固件打包，不自行生成 DDR、miniloader、ATF、U-Boot 或板级启动二进制文件。

## 功能范围

本 layer 提供：

- `rk-binary-native`：安装 Rockchip 原生打包工具，如 `afptool` 和 `rkImageMaker`。
- `rockchip-updateimg.bbclass`：生成以下文件：
  - `parameter`
  - `package-file`
  - `update.raw.img`
  - `<image>.update.img`
  - `update.img` 符号链接

本 layer 需要板级或 BSP layer 在 `${DEPLOY_DIR_IMAGE}` 或 `${IMGDEPLOYDIR}` 中提供 Rockchip 启动输入文件。

## 启动介质支持

本 layer 可用于面向 eMMC、SD 卡、SPI NAND、raw NAND 或其他 Rockchip 支持的存储介质的镜像。实际启动介质不由本 layer 决定，而是由板级启动链、U-Boot 配置、内核命令行、分区布局和 Rockchip loader 行为共同控制。

本 layer 专注于 Rockchip 固件容器格式：

- eMMC 和 SD 卡通常使用 `RK_UPDATEIMG_PARAMETER_MODE = "gpt"`。
- NAND 和 MTD 风格的布局通常使用 `RK_UPDATEIMG_PARAMETER_MODE = "mtd"` 或 `manual`。
- 特殊厂商布局可使用 `manual` 模式并配合完全自定义的 `RK_UPDATEIMG_PARAMETER_CMDLINE`。

## 必要输入文件

打包 class 至少需要：

- 一个 Yocto 磁盘镜像，通常为 `${IMAGE_LINK_NAME}.wic`
- `loader.bin` 或兼容的 loader 文件
- 根文件系统镜像，通常为 `${IMAGE_LINK_NAME}.ext4`

完整的 Rockchip 固件包通常还需要：

- `uboot.img`
- `trust.img` 或 `trust.bin`
- 若分区布局包含 `boot` 分区，则还需要 `boot.img`

## 使用方法

添加 layer：

```bash
bitbake-layers add-layer /path/to/meta-rockchip-updateimg
```

在镜像 recipe 中启用：

```bitbake
inherit rockchip-updateimg

IMAGE_FSTYPES += "wic ext4"
```

然后构建镜像：

```bash
bitbake core-image-minimal
```

预期输出：

```text
tmp/deploy/images/<machine>/<image>-<machine>.update.img
tmp/deploy/images/<machine>/update.img
```

## 常用配置

```bitbake
RK_UPDATEIMG_SOC = "RK3399"
RK_UPDATEIMG_ROOTDEV = "PARTLABEL=root"
RK_UPDATEIMG_REQUIRED_IMAGES = "loader.bin rootfs.img"
RK_UPDATEIMG_EXTRA_DEPENDS = "u-boot-rockchip:do_deploy rk3399-blobs:do_deploy"
```

若将 `RK_UPDATEIMG_SOC` 保持为 `auto`，class 会尝试从 `loader.bin` 中检测 SoC ID，并以 `-RKxxxx` 的形式传递给 `rkImageMaker`。

## parameter 生成模式

### GPT 模式

GPT 模式为默认模式，最适合 eMMC 和 SD 卡风格的 Yocto 镜像。

```bitbake
RK_UPDATEIMG_PARAMETER_MODE = "gpt"
IMAGE_FSTYPES += "wic ext4"
RK_UPDATEIMG_ROOTDEV = "PARTLABEL=root"
```

class 使用 `sgdisk` 读取 `.wic` 镜像，将 GPT 分区转换为 Rockchip `parameter` 条目，并将分区名映射到镜像文件。

### MTD 模式

MTD 模式适用于 NAND 风格的布局，此时 Rockchip `parameter` 文件需直接描述 `mtdparts` 布局。

```bitbake
RK_UPDATEIMG_PARAMETER_MODE = "mtd"
RK_UPDATEIMG_ROOTFS_TYPE = "ubi"
RK_UPDATEIMG_ROOTDEV = "ubi0:rootfs"
RK_UPDATEIMG_MTD_PARTITIONS = "0x00002000@0x00004000(uboot),0x00002000@0x00006000(trust),0x00080000@0x00008000(rootfs:grow)"
RK_UPDATEIMG_ROOTFS_CANDIDATES = "${IMAGE_LINK_NAME}.ubi rootfs.ubi rootfs.img"
RK_UPDATEIMG_PARTITION_IMAGE_MAP += "rootfs:rootfs.img"
```

### 手动模式

手动模式适用于厂商特定或非常规的布局，需要用户自行提供完整的 Rockchip 命令行。

```bitbake
RK_UPDATEIMG_PARAMETER_MODE = "manual"
RK_UPDATEIMG_PARAMETER_CMDLINE = "mtdparts=rk29xxnand:0x00002000@0x00004000(uboot),0x00002000@0x00006000(trust),-(rootfs:grow)"
RK_UPDATEIMG_ROOTDEV = "ubi0:rootfs"
```

## 固定分区

某些平台的固件分区位于 GPT 布局之外，或需要显式的 Rockchip parameter 条目，可使用 `RK_UPDATEIMG_FIXED_PARTITIONS`。

格式：

```text
name:start_sector:size_sectors
```

示例：

```bitbake
RK_UPDATEIMG_FIXED_PARTITIONS = "uboot:0x4000:0x2000 trust:0x6000:0x2000"
```

## 分区到镜像的映射

class 从生成的 `parameter` 文件中解析分区名，并将其映射到镜像文件。默认映射包括：

```text
root -> rootfs.img
system -> rootfs.img
system_a -> rootfs.img
system_b -> rootfs.img
uboot-env -> uboot.env
backup -> RESERVED
```

可以覆盖或扩展映射：

```bitbake
RK_UPDATEIMG_PARTITION_IMAGE_MAP += "userdata:userdata.img vendor:vendor.img oem:oem.img"
```

## 常见 SoC 示例

### RK3399 eMMC 或 SD

```bitbake
inherit rockchip-updateimg

IMAGE_FSTYPES += "wic ext4"
RK_UPDATEIMG_SOC = "RK3399"
RK_UPDATEIMG_PARAMETER_MODE = "gpt"
RK_UPDATEIMG_ROOTDEV = "PARTLABEL=root"
RK_UPDATEIMG_FIXED_PARTITIONS = "uboot:0x4000:0x2000 trust:0x6000:0x2000"
RK_UPDATEIMG_REQUIRED_IMAGES = "loader.bin uboot.img trust.img rootfs.img"
```

### RK3588 eMMC 或 SD

```bitbake
inherit rockchip-updateimg

IMAGE_FSTYPES += "wic ext4"
RK_UPDATEIMG_SOC = "RK3588"
RK_UPDATEIMG_PARAMETER_MODE = "gpt"
RK_UPDATEIMG_ROOTDEV = "PARTLABEL=root"
RK_UPDATEIMG_REQUIRED_IMAGES = "loader.bin rootfs.img"
```

### NAND / UBI 根文件系统

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

## 重要设计原则

不要让本 layer 承担所有 SoC 启动链的生成工作。RK3288、RK3399、RK3506、RK3568 和 RK3588 往往需要不同的 DDR/miniloader/trust 生成流程，应将这些流程保留在 SoC 或板级 BSP layer 中，本 layer 只负责消费最终的 deploy 产物。
