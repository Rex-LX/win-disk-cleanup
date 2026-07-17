# win-disk-cleanup

Windows C 盘深度清理与 AppData 迁移工具 — 一个 [QoderWork](https://qoder.com) Agent Skill。

当你的 C 盘空间告急、AppData 膨胀、各种应用缓存占满磁盘时，这个 Skill 可以帮你系统性地清理垃圾并将大文件夹透明迁移到副盘。

## 功能概览

这个 Skill 分三个阶段工作：

**Phase 1 — 基础清理**：清理临时文件（%TEMP%、Windows\Temp）、浏览器缓存（Chrome/Edge）、缩略图缓存、pip 缓存和回收站，快速释放空间。

**Phase 2 — 深度分析与清理**：扫描 C 盘空间占用情况，列出 AppData 中的大文件夹、已安装程序、各类应用缓存（微信、网易云、夸克、B 站、抖音、Steam 等），由你决定清理哪些。

**Phase 3 — Junction 迁移**：将 AppData 中的大文件夹透明迁移到 D 盘（或其他副盘），通过 NTFS Junction 让应用完全无感知，从根本上解决 C 盘被吃满的问题。同时支持 npm/yarn/pip 缓存路径迁移。

## 安装

这个 Skill 需要在 QoderWork 中使用。安装步骤：

1. 确保你已安装 [QoderWork](https://qoder.com)
2. 下载本仓库（`git clone` 或直接下载 ZIP）
3. 将整个 `win-disk-cleanup` 文件夹复制到 `~/.qoderworkcn/skills/` 目录下
4. 重启 QoderWork，Skill 会自动加载

你也可以在 QoderWork 中直接对话："帮我清理 C 盘" 或 "C 盘空间不够了"，Skill 会自动触发。

## 目录结构

```
win-disk-cleanup/
├── SKILL.md                        # Skill 定义与执行流程
├── README.md
├── LICENSE
└── scripts/
    ├── scan_disk.ps1               # 磁盘空间扫描与报告
    ├── clean_caches.ps1            # 缓存清理（支持 basic/deep 模式）
    ├── check_running.ps1           # 迁移前检查运行中的应用
    ├── migrate_junctions.ps1       # 批量迁移 + 创建 Junction
    └── verify_junctions.ps1        # 验证 Junction 完整性
```

## 脚本说明

### scan_disk.ps1

扫描磁盘空间占用，输出 C/D/E 盘概览、C 盘顶层大文件夹、AppData\Local 和 Roaming 中超过 50MB 的文件夹（标注 Junction 状态）、用户目录 dotfolder、以及各类可清理项的大小。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/scan_disk.ps1
```

### clean_caches.ps1

清理缓存文件，支持两种模式：

- `basic`（默认）：清理临时文件、浏览器缓存、缩略图、pip 缓存、回收站
- `deep`：在 basic 基础上增加应用缓存（网易云、夸克、B 站、抖音、Steam 等）和 updater 残留

```powershell
powershell -ExecutionPolicy Bypass -File scripts/clean_caches.ps1 -Mode basic
powershell -ExecutionPolicy Bypass -File scripts/clean_caches.ps1 -Mode deep
```

### check_running.ps1

迁移前检查目标应用是否在运行（微信、QQ、Chrome、VS Code、Steam 等），列出需要关闭的应用，避免迁移时文件被锁定。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_running.ps1
```

### migrate_junctions.ps1

批量迁移文件夹并创建 NTFS Junction。流程：robocopy 复制 → 校验目标大小 → 删除源 → mklink /J 创建 Junction → 验证。默认目标路径为 `D:\AppData`。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/migrate_junctions.ps1 -targetRoot "D:\AppData"
```

### verify_junctions.ps1

验证所有已创建的 Junction 是否完好，检查缓存环境变量（YARN_CACHE_FOLDER、PIP_CACHE_DIR、npm cache）是否正确指向。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify_junctions.ps1
```

## 注意事项

- 所有脚本需要以 PowerShell 执行（`-ExecutionPolicy Bypass`）
- 基础清理会跳过 `%TEMP%` 中的 `qoder-cli` 子目录，避免清理过程中丢失脚本
- Junction 迁移前请务必关闭相关应用，脚本会自动检查并提示
- `Microsoft`、`Packages`、`Programs` 等系统关键目录不会被迁移
- 迁移失败的文件（因锁定）建议重启后重试
- 建议在执行前确保目标盘有足够空间

## License

MIT License — 详见 [LICENSE](LICENSE)
