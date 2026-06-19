# meta-rockchip-updateimg

可复用的 Yocto layer，将标准镜像产物打包为 Rockchip `update.img`，供 RKDevTool / `upgrade_tool` 烧录。

## 职责边界

| 组件 | 职责 |
|------|------|
| **BSP 层**（如 meta-rk3506b-custom） | U-Boot、内核、机器配置、WIC 分区模板 |
| **本层** | `afptool` / `rkImageMaker` 工具链 + `update.img` 打包 |

## 目录结构

```
meta-rockchip-updateimg/
├── conf/layer.conf
├── classes/
│   ├── rockchip-image.bbclass       # rootfs.img 链接、WIC 缺图自动裁剪
│   └── rockchip-updateimg.bbclass   # parameter / package-file / update.img
└── recipes-bsp/rk-binary/
    ├── rk-binary-native.bb          # afptool（源码编译）+ rkImageMaker（预编译）
    └── files/rkImageMaker
```

## 快速接入

```bitbake
# conf/bblayers.conf
BBLAYERS += "${TOPDIR}/../meta-rockchip-updateimg"

# conf/layer.conf（BSP 层）
LAYERDEPENDS_my-bsp = "core rockchip-updateimg"
```

```bitbake
# recipes-core/images/my-image.bb
inherit core-image
inherit rockchip-updateimg

IMAGE_FSTYPES += "wic ext4"

RK_UPDATEIMG_SOC = "auto"
RK_UPDATEIMG_REQUIRED_IMAGES = "loader.bin uboot.img boot.img rootfs.img"
```

> **RK3506 芯片标识**：`loader.bin` 内 tag 为 **`350F`**（非 `RK35`）。请保持 `RK_UPDATEIMG_SOC = "auto"`（从 loader 自动读取），或显式设为 `"350F"`。误用 `RK35` 会导致 RKDevTool `CheckChip: Chip is not match`。

## 启动链说明

Rockchip 有两种常见打包方式：

1. **Miniloader**：`loader.bin` + `uboot.img` + `trust.img`（独立 ATF/TEE）
2. **U-Boot SPL + FIT**（RK3506 等）：`trust` 已打入 `uboot.img`，**不需要**单独 `trust.img`

SPL+FIT 平台请将 `trust.img` 放入 `RK_UPDATEIMG_OPTIONAL_IMAGES`，不要写入 `RK_UPDATEIMG_REQUIRED_IMAGES`。

## 关于 `RK_UPDATEIMG_OS_TYPE = "androidos"`

**这不代表你在构建 Android 系统。** 该变量仅传给 `rkImageMaker`，作为 `update.img` 容器的格式标记。

- `rkImageMaker` 只接受 `-os_type:RKOS|ANDROIDOS`，**没有** `linux` 选项
- 设为 `linux` 会导致 `Error: Get image version failed!` 打包失败
- Rockchip 官方 Linux SDK 的 `mkupdate.sh` 同样使用 `-os_type:androidos`
- 实际 rootfs 仍是 Yocto Linux（ext4 + 标准用户态），与 Android 无关

若需修改，仅可在 `RKOS` 与 `ANDROIDOS`（或 `androidos`）之间选择；`androidos` 是生态内验证最广的默认值。

## 主要变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `RK_UPDATEIMG_ENABLE` | `1` | 是否生成 update.img |
| `RK_UPDATEIMG_SOC` | `auto` | SoC 标识；RK3506 从 loader 读为 **`350F`**（勿用 `RK35`） |
| `RK_UPDATEIMG_OS_TYPE` | `androidos` | rkImageMaker 容器格式（非 Android 系统，见上文） |
| `RK_UPDATEIMG_PARAMETER_MODE` | `gpt` | 从 WIC 镜像解析 GPT 分区生成 parameter |
| `RK_UPDATEIMG_REQUIRED_IMAGES` | `loader.bin rootfs.img` | 缺失则构建失败 |
| `RK_UPDATEIMG_OPTIONAL_IMAGES` | `trust.img` | 缺失仅警告 |
| `RK_UPDATEIMG_EXTRA_DEPENDS` | `virtual/bootloader:do_deploy` | 打包前额外 task 依赖 |

## WIC 缺图裁剪

`rockchip-image.bbclass` 在 `do_fixup_wks` 阶段检查 WIC 模板中引用的 `.img` 文件；若 deploy 目录中不存在（如 SPL+FIT 无 `trust.img`），自动从模板删除对应分区行。

## 工具来源

- **afptool**：从 [neo-technologies/rockchip-mkbootimg](https://github.com/neo-technologies/rockchip-mkbootimg) 源码编译
- **rkImageMaker**：Rockchip SDK 预编译二进制（无官方开源版），随层分发
- **rkbin 辅助工具**：`boot_merger`、`upgrade_tool` 等从 [rockchip-linux/rkbin](https://github.com/rockchip-linux/rkbin) 安装（可选）

## 输出

```
tmp/deploy/images/<MACHINE>/
├── <image>.update.img
├── update.img          # 符号链接
├── *.wic
└── *.ext4
```

## 兼容性

`LAYERSERIES_COMPAT_rockchip-updateimg = "kirkstone ..."`
