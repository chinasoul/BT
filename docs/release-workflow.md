# Release 流程备忘（GitHub / R2 / Gitee）

本文档记录当前 `Release APK (Obfuscated)` 工作流的执行顺序、变量依赖与 fallback 逻辑，后续可直接引用本文件，减少重复沟通。

工作流文件：`.github/workflows/release.yml`

## 1. 触发方式

- `push tags: v*`（如 `v0.7.1`）
- `workflow_dispatch` 手动触发（输入 `tag`）

统一 tag 变量：

- `RELEASE_TAG = github.event.inputs.tag || github.ref_name`

## 2. 构建与版本号规则

1. `BUILD_NAME = RELEASE_TAG` 去掉前缀 `v`
2. `BUILD_NUMBER = github.run_number`
3. 构建产物：
   - `release-assets/v7a.apk`（`android-arm`）
   - `release-assets/v8a.apk`（`android-arm64`）
4. 校验产物：
   - `release-assets/SHA256SUMS.txt`

## 3. Release Notes 来源

优先级：

1. `release-notes/<RELEASE_TAG>.md`
2. 若不存在，使用 tag 对应提交的 commit message，写入：
   - `release-notes/_auto_generated.md`

## 4. Cloudflare R2（可选镜像分发）

步骤名：`Upload APKs to Cloudflare R2 (optional)`

### 必填（缺任一项则跳过）

- `secrets.R2_ACCOUNT_ID`
- `secrets.R2_ACCESS_KEY_ID`
- `secrets.R2_SECRET_ACCESS_KEY`
- `vars.R2_BUCKET`（或 `secrets.R2_BUCKET`）

### 可选

- `vars.R2_PREFIX`（默认 `releases`）
- `vars.R2_PUBLIC_BASE`（默认 `https://<bucket>.<account>.r2.dev`）

### 结果

- 上传：
  - `<prefix>/<tag>/v7a.apk`
  - `<prefix>/<tag>/v8a.apk`
  - `<prefix>/<tag>/SHA256SUMS.txt`
- 生成统一文案文件：
  - `release-assets/release-body.md`
- 该文案会追加 `Mirror Download (Cloudflare R2)` 三个下载链接。

## 5. GitHub Release

步骤名：`Publish GitHub Release`

- `tag_name/name = RELEASE_TAG`
- `body_path = RELEASE_BODY_FILE`（优先 `release-assets/release-body.md`）
- 附件：
  - `v7a.apk`
  - `v8a.apk`
  - `SHA256SUMS.txt`

## 6. Gitee 发布（最后 fallback）

步骤名：`Publish to Gitee`

### 启用条件

- `secrets.GITEE_TOKEN` 与 `vars.GITEE_REPO` 同时存在

### Release ID 获取顺序

1. `GET /releases/tags/{tag}`
2. 若 `200` 但无 `id`，则 list 回退：
   - `GET /releases?page=1&per_page=100` 按 `tag_name` 匹配
3. 若仍无可用 id，尝试 `POST` 创建 release（JSON body）
4. 若最终 `RELEASE_ID` 非数字，跳过附件上传并 warning

### 附件上传

- 目标接口：`/releases/{id}/attach_files`
- 上传前会查重：同名附件先删后传
- 上传超时：`--max-time 60`
- 保留重试：`--retry 3`
- 上传失败记 warning，不直接让脚本崩溃

## 7. App 端下载优先级（与发布流程对应）

文件：`lib/services/update_service.dart`

检查更新时：

1. 优先从 release `body` 提取 `.apk` 链接（可命中 R2/COS/OSS 等镜像）
2. 若未提取到，再回退到 release `assets` 中的 APK
3. 下载 GitHub 链接时，仍有内置代理回退（`ghproxy` 等）

因此当前策略可理解为：

- 主分发：release body 中的镜像链接（如 R2）
- 次分发：GitHub/Gitee release assets
- 最后兜底：现有网络代理与多源回退

## 8. 常见排查

- `build number` 来自 `github.run_number`，不是 tag 自增
- `Query by tag ... ID=` 常见于 Gitee 仓库未同步 tag/release
- `curl exit=28` 是网络超时（链路问题），非脚本语法错误
- 如需彻底稳定大陆下载，优先用对象存储直链，不依赖 Gitee 附件上传
