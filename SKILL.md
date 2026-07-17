---
name: win-disk-cleanup
description: Windows C盘深度清理与AppData迁移工具。分析磁盘空间占用、清理临时文件/浏览器缓存/回收站、通过Junction将AppData大文件夹透明迁移到副盘、迁移npm/yarn/pip缓存环境变量。适用于C盘空间不足、AppData膨胀、需要深度清理或将应用数据迁移到D盘时。当用户提到清理C盘、磁盘空间不足、AppData太大、迁移缓存到D盘时触发。
version: 2.0.0
---

# Windows C盘深度清理与迁移

## 执行规则

- 所有 .ps1 脚本写入 QoderWork workspace，**不写** `%TEMP%`（会被清理掉）
- 输出报告也写入 workspace，不依赖 Bash stdout（清理 Temp 时会丢失）
- 使用 `powershell -ExecutionPolicy Bypass -File script.ps1` 执行
- CMD 下 `$_` 会被吞掉，**永远写成 .ps1 再执行**
- 每个阶段结束后向用户汇报结果，等待用户指示再决定是否进入下一阶段

---

## Phase 1: 基础清理（默认执行）

用户请求清理时，**先执行此阶段**，无需额外确认。

### 流程

1. 记录 C 盘和 D 盘当前可用空间
2. 清理以下项目（跳过被锁定的文件）：
   - `%TEMP%` 用户临时文件（**跳过 qoder-cli 子目录**）
   - `C:\Windows\Temp` 系统临时
   - 浏览器缓存（Chrome/Edge 的 Cache、Code Cache、Service Worker、GPUCache）
   - 缩略图缓存 `thumbcache_*.db`
   - pip 缓存 `pip cache purge`
   - 回收站 `Clear-RecycleBin -Force`
3. 汇报释放了多少空间

### 完成后

告知用户基础清理结果，询问是否需要**深度分析和清理**更多项目。若用户同意，进入 Phase 2。

---

## Phase 2: 深度分析 + 针对性清理（按需）

用户希望清理更多时执行。

### 2.1 扫描占用情况

执行 `scripts/scan_disk.ps1`，生成报告包含：

- C 盘顶层文件夹大小（Users / Windows / Program Files 等）
- AppData\Local 和 AppData\Roaming 中 >50MB 的文件夹（标注 Junction 状态）
- 用户目录下的 dotfolder（.vscode / .cache 等）
- 已安装程序列表（按大小排序，来自注册表）
- Program Files 各子目录大小
- 各应用缓存详情（微信、网易云、夸克、WPS、B站、抖音等）

### 2.2 向用户展示分析结果

将扫描结果按占用大小排列，分类呈现给用户：

- **可安全清理的缓存**：网易云、夸克、B站、抖音、Steam、各种 updater 残留等
- **需要应用内操作的缓存**：微信聊天缓存、WPS 缓存（需在应用设置中清理）
- **可评估是否保留的应用**：重复安装的软件、不用的 AI 工具等
- **系统/必要项**（不建议动）：Windows、Microsoft、Packages 等

### 2.3 根据用户选择执行清理

- **安全缓存类**：直接执行 `scripts/clean_caches.ps1` 或针对性删除
- **应用内缓存**：指导用户在应用设置中操作，给出具体路径
- **不用的程序**：指导用户通过控制面板卸载
- **大型文件夹**：确认后再删除

### 2.4 汇报清理结果

展示清理前后的空间对比，询问用户是否需要**路径迁移**防止空间再次被吃满。若用户同意，进入 Phase 3。

---

## Phase 3: Junction 迁移（按需）

用户明确要求迁移时执行。将 AppData 大文件夹透明搬到副盘，C 盘空间不再被蚕食。

### 3.1 前置检查

1. 执行 `scripts/check_running.ps1` 检查哪些应用在运行
2. 告知用户需要关闭哪些应用
3. 等待用户关闭后继续

### 3.2 执行迁移

执行 `scripts/migrate_junctions.ps1`，流程：

```
1. xcopy 复制到目标盘（robocopy exit>=16 时 fallback）
2. 校验目标大小 >= 源 90%
3. rmdir /S /Q 删除源
4. mklink /J 创建 Junction
5. 验证 Junction 生效
```

目标结构：`D:\AppData\{Local,Roaming,UserProfile}\...`

### 3.3 缓存路径迁移

迁移包管理器缓存到副盘（设置环境变量 + config）：

```powershell
# npm
npm config set cache "D:\DevCaches\npm-cache"

# Yarn
[Environment]::SetEnvironmentVariable("YARN_CACHE_FOLDER", "D:\DevCaches\yarn-cache", "User")

# pip
[Environment]::SetEnvironmentVariable("PIP_CACHE_DIR", "D:\DevCaches\pip-cache", "User")
```

### 3.4 重启后重试

迁移失败的文件（因锁定）需重启后立即重试脚本。关键：**在应用启动前执行**。

### 3.5 验证

执行 `scripts/verify_junctions.ps1` 确认所有 Junction 完好、环境变量正确。

### 不要迁移的

- `Microsoft` 文件夹（Edge/WebView2 系统组件）
- `Packages`（Windows Store UWP 应用）
- `Programs`（安装程序目录）
- QoderWork 自身（正在运行）

---

## 工具脚本

| 脚本 | 用途 | 何时使用 |
|------|------|----------|
| `scripts/scan_disk.ps1` | 扫描磁盘空间 + AppData 详情 | Phase 2 开始时 |
| `scripts/clean_caches.ps1` | 批量清理应用缓存 | Phase 1 或 Phase 2 |
| `scripts/migrate_junctions.ps1` | 批量迁移 + 创建 Junction | Phase 3 |
| `scripts/check_running.ps1` | 检查哪些应用在运行 | Phase 3 前置 |
| `scripts/verify_junctions.ps1` | 验证 Junction 完整性 | Phase 3 完成后 |
