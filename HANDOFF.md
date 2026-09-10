# Saymore（VoiceInk fork）

对标 Typeless。上游：https://github.com/Beingpax/VoiceInk（GPL v3，作者不收 PR）。本仓库：https://github.com/pmpub/saymore，同样以 GPL v3 发布。
同步上游：`git remote add upstream https://github.com/Beingpax/VoiceInk.git && git fetch upstream && git rebase upstream/main`。

## 这个 fork 改了什么

| 改动 | 文件 | 目的 |
|---|---|---|
| 改名 Saymore + 换图标 | `VoiceInk.xcodeproj/project.pbxproj`（Release 的 PRODUCT_NAME / CFBundleDisplayName）、`Assets.xcassets/AppIcon.appiconset`、`App/VoiceInk.swift` 主窗口标题 | 显示名和 .app 文件名都是 Saymore；图标是 Baskerville Bold 的 S（对照 Typeless 的浅底黑形风格，使用者 选定）。**Bundle ID 保持 com.prakashjoshipax.VoiceInk 不动**：权限授权、Keychain 里的 key、Application Support 目录都挂在它上面，代码里也有硬编码 |
| DeepSeek 作为一等 AI 增强 provider | `Features/Enhancement/State/AIService.swift`、`Infrastructure/Credentials/APIKeyManager.swift`、`Features/ModelLibrary/Views/ProviderCloudManagementView.swift`、`APIKeyManagementView.swift`、`Onboarding/*`、`Dashboard/Components/ModelInsightComponents.swift` | 清洗层用 DeepSeek（`deepseek-chat`），走 OpenAI 兼容接口 `https://api.deepseek.com/v1/chat/completions` |
| Whisper 中文 initial prompt 改成中英夹杂 | `Infrastructure/Providers/Transcription/Whisper/WhisperPrompt.swift` | 让 Whisper 输出简体 + 保留英文术语，而不是把英文翻成中文或输出繁体 |
| 清洗系统提示词加 `<CHINESE_RULES>` + 三条中英混说示例 | `Core/Enhancement/AIPrompts.swift` | 简体、全角标点、中英之间加空格、去中文口头禅、中文自我纠正、中文数字转阿拉伯数字、同音字纠错 |

## 构建（用 fork 自带脚本，不要直接 make local）

```bash
brew install cmake                          # 只需一次
xcodebuild -downloadComponent MetalToolchain # 只需一次，Xcode 26+ 把 Metal 编译器拆成了可选组件，mlx-swift 要用
make whisper                                # 只需一次；Makefile 全量 clone 慢，可手动 git clone --depth 1 后 ./build-xcframework.sh
sh scripts/build.sh                    # 解析依赖 → 构建 → 重签 → 装到 /Applications → 启动
```

`scripts/build.sh` 解决了本机 `make local` 踩到的全部坑，按出现顺序：

| 坑 | 现象 | 脚本里的解法 |
|---|---|---|
| GitHub 慢 | SPM 拉 28 个包几小时拉不完，git 经代理 ~2 KB/s | 临时 `GIT_CONFIG_GLOBAL` 把 github.com 重写到 gh-proxy.com（git 十几 MB/s），不改全局配置；已用 ls-remote / 全哈希 fetch 逐包核验过 commit 与原站一致 |
| 二进制包下不动 | Sparkle / NemoTextProcessing / TranscribeCpp 三个 zip 走系统代理 2.5 KB/s | 手动下载后放进 `~/Library/Caches/org.swift.swiftpm/artifacts/<URL 非字母数字全换下划线>`，SPM 直接取缓存；校验值在各包 Package.swift 里 |
| 插件/宏校验 | `Validate plug-in "CudaBuild" in package "mlx-swift"` 失败 | `-skipPackagePluginValidation -skipMacroValidation` |
| 缺 Metal 工具链 | `cannot execute tool 'metal'` | `xcodebuild -downloadComponent MetalToolchain`（839 MB，苹果 CDN 快） |
| 启动即崩 | dyld: whisper.framework "different Team IDs" | hardened runtime 下主程序和内嵌库 Team ID 必须一致；脚本从里到外统一用 Apple Development 身份重签 |

产物在 `.local-build/`，装到 `/Applications/Saymore.app`。Dock 图标和菜单栏模板图都由 `python3 scripts/make-icons.py` 生成（Baskerville Bold S 浅底黑形微立体；菜单栏 SemiBold、占画布 62%），改图标改脚本重跑。SenseVoice 模型文件在 `~/Library/Application Support/com.prakashjoshipax.VoiceInk/TranscribeCpp/sensevoice-small/`，旁边的 `.SenseVoiceSmall-Q8_0.gguf.sha256` 存校验值，App 靠文件大小 + 这个校验文件判断已安装。

## 首次使用配置

1. Transcription 模型：中英混说优先 **SenseVoice Small**（本地，阿里，专为 zh/en/ja/ko 设计，241 MB）；备选 **Whisper Large v3 Turbo**，语言选 `zh`（不要选 auto，混说时 auto 会在句中切语言）。
2. AI Enhancement：provider 选 **DeepSeek**，填 API key（https://platform.deepseek.com/api_keys），模型 `deepseek-chat`。
3. Dictionary 里加自己的专有名词（产品名、人名、缩写），Replacements 里加固定误识别的纠正对。
4. 系统权限：麦克风、辅助功能、输入监控。ad-hoc 签名每次重编后可能要重新授权，用 Apple Development 身份签名可避免。

## 已知边界

- 本地 filler 词过滤用 `\b` 边界，对中文无效，中文口头禅全靠 LLM 提示词去。
- DeepSeek 没有品牌图标，走 SF Symbol 兜底。
- `deepseek-reasoner` 也列了，但听写不该用，慢。
