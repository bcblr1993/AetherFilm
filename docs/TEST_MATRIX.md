# v0.1.0 验收矩阵

当前处于执行验收阶段，尚未发布。构建和部分协议 / 播放测试已有真实结果；失败、未测和未发布分别记录。每项执行后记录命令、环境、结果、证据文件和 commit。

| 层级 | 场景 | macOS | iOS |
| --- | --- | --- | --- |
| 构建 | 最低部署版本 26；Debug / Release；真机 archive | 最新 Debug / tests 与 universal Release 候选构建通过 | Simulator Debug / tests、已签名 device tests 与最终 Release archive 构建通过 |
| 本地 | 导入、取消、重复、中文 / 空格路径、重启访问 | 待测 | 待测 |
| SMB | 共享 / 目录、认证、中文路径、随机读取、Range、错误密码、超时 / 取消、加密失败不回落 | 19 项协议 / HTTP 回归通过；VM 播放与 SMB3 加密成功待测 | Simulator 真实 SMB 播放、20 次远近 seek、停止后重开通过；真机待测 |
| 播放 | H.264 + AAC MP4；HEVC MOV；MPEG4 + MP3 AVI；多轨 MKV；实际画面 / 音频输出 / 时间推进；4K HEVC | VM 待登录运行 | 四种容器与 4K HEVC Simulator 实际输出通过；真机硬件解码待测 |
| 控制 | 暂停 / 继续、进度跳转、倍速、全屏、结束、切换影片、退出清理 | VM 待测 | 本地 iOS 26.5 播放控制与完整 UI 通过；CI iOS 27 SMB seek 失败调查中，真机待测 |
| 字幕 | SRT / ASS / VTT 中文、内嵌字幕、开关、跳转同步、无字幕 | VM 待测 | Simulator 内嵌 / 外挂 SRT、ASS、VTT 选择与关闭、章节跳转、坏字幕不中断视频与同片重试通过；视觉同步 / 真机待测 |
| 音轨 | 单 / 多音轨、切换、无音轨、不可解码错误 | VM 待测 | 多轨选择通过；其余 UI / 真机待测 |
| 记录 | 断点、重启恢复、片尾完成、已看、清除；库条目删除不删除原文件 | shared storage 通过；AppStore / UI 待运行 | AppStore 5 case 与对应 UI 回归通过，含 cold-open 导入并发、移除保留原文件、旧进度清理 |
| UI | 本地 / 续播空状态；导入入口；SMB 表单校验 / 取消；目录 / 返回 / 空目录；列表筛选；失败重试；格式 / 观看状态；播放入口 | 自动化已编写，待 VM 运行 | 完整 19 项通过，0 skipped；虚拟 NAS 状态不替代真实协议 / 真机 |
| 可访问性 | 动态字体、可访问性描述、VoiceOver、实际系统减少透明度、键盘导航 | 待实际运行 / 人工验收 | 描述 audit、真实系统大字体及减少透明度通过；VoiceOver / 真机人工验收待测 |
| 适配 | 980×680 / 620×440 窗口、浅深色；iPhone 小屏 / 横屏；iPad 分屏 | 自动化已编写，待截图审核 | iPhone 22 张完整 UI 截图已审核；iPad 4 项布局烟测通过，分屏和完整键盘表单仍待测 |
| 分发 | 签名、公证、DMG 标签和内容、安装、首启、公开下载 SHA256 | 402034c 新候选公证及本地 28 项、Gatekeeper 启用的 VM 54 项安装 / 签名检查通过；首启 / 播放和公开下载待测 | 不适用 |
| 分发 | 真机安装 / 播放、TestFlight 构建和安装、公开入口 | 不适用 | 待测 |
| 官网 | 中英介绍、真实截图、系统要求、下载 / 发布链接、线上访问 | 隔离候选 153 项测试及 16 个浏览器场景通过；实际截图、下载与线上部署待完成 | 开发状态页面候选通过；无公开 iOS 安装链接 |

共享代码回归：文件格式 / 自然排序、目录边界、HTTP Range、进度边界、编码往返、损坏 / 未来版本数据、密钥不入普通持久化。加入合法 TCP 半关闭回归后的完整共享测试 **33 项通过**：Domain 8、Library 4、Sources 21，0 skipped；日志 `.build/kit-full-halfclose-candidate.log`。此前 31 项运行日志 `.build/kit-full-candidate.log` 保留。SMB 证据见下文。

协议集成使用隔离 SMB2 服务和自己生成的媒体样片，验证认证、读取、HTTP Range、取消、超时与失败路径。WebDAV / Jellyfin 未入选本期，不是本期验收项。

macOS UI 优先在 Tart `macos27` 验证，避免占用用户主机键鼠。自动化结果不替代 iPhone 的硬件解码、声音、4K 和安装验收。测试样片由脚本生成，不提交版权影片。

## SMB 协议与代理执行证据

2026-10-03，宿主 macOS 27.0.1（26A434）、Apple Silicon、Swift 6.4，提交 `402034cd87fd10545d22e3ef33c8ee80473e75f0`：`FilmSourcesTests` 的 SMB 筛选 **19 / 19 通过，0 skipped**，测试执行 2.128 秒。此运行没有操作宿主 UI，不作为 VM 播放或 iPhone 验收。日志：`.build/SMBEvidence/smb-swift-tests-2026-10-03.log`。

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/aetherfilm-smb-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/aetherfilm-smb-module-cache \
/private/tmp/aetherfilm-smb-test-venv/bin/python scripts/test_smb_integration.py -- \
  swift test --package-path Packages/AetherFilmKit \
    --cache-path /private/tmp/aetherfilm-smb-swift-cache --disable-sandbox --filter SMB
```

隔离服务使用固定测试依赖 `impacket==0.13.0`，仅监听 `127.0.0.1`，临时用户名 / 密码在内存产生；目录和样片均为本轮自建，不访问用户 NAS。已覆盖真实 SMB2 认证、共享枚举、中文目录、1 MiB 文件完整 / 随机读取、错误密码后重试、文件不存在、停滞连接超时和握手取消。HTTP 代理已覆盖 512 KiB 分块、普通 / 后缀 / 开放 Range、HEAD、416 / 404 / 405、空文件、停止活跃读取及连续十次取消后仍可读取；并发取消不会留下可复用的旧认证会话。释放代理对象时会取消活跃读取并关闭监听器：新增回归在修复前等待客户端超时 3.003 秒而失败，修复后整组运行 0.068 秒通过。

`requireEncryption=true` 对本轮 SMB2 服务明确失败；测试证明没有退回明文，关闭要求后才能重新访问。固定 libsmb2 的加密实现支持 AES-128-CCM，SMB3 加密成功、真实 NAS 兼容和实际断网恢复仍待独立验收，不能用本轮拒绝测试代替。

`--media-folder` 已用自建中文 MP4 / SRT 样片进行真实 SMB 字节比对，复制后的内容一致，非媒体文件和符号链接被跳过。`--bootstrap-only` 已验证子进程环境没有密码；测试进程从临时 loopback JSON 接口在内存取得凭据，响应 `Cache-Control: no-store`，URL 不含密码，接口随测试结束关闭。日志：`.build/SMBEvidence/smb-media-bootstrap-2026-10-03.log`。Xcode / VM 播放测试应使用以下方式，scheme 只传 `AETHERFILM_SMB_BOOTSTRAP_URL`，不保存密码：

```sh
python scripts/test_smb_integration.py --bootstrap-only \
  --media-folder .build/PlaybackFixtures -- xcodebuild test ...
```

真实 SMB → HTTP → VLC 的画面 / 音频输出、20 次逐次远近 seek、停止后字节读取稳定及两次重开已在 iOS Simulator 通过。VM 与 iPhone 的相同路径仍待验证。

协议复核新增真实 TCP 半关闭诊断：[RFC 9112 § 9.6](https://www.rfc-editor.org/rfc/rfc9112.html#section-9.6) 规定，客户端关闭发送方向并不代表放弃响应。旧实现将无错误的输入 EOF 当作取消，普通 GET / Range 能读完整，但 `shutdown(SHUT_WR)` 后两者都是 0 字节响应。修复只对真实 transport error 取消；半关闭 GET / Range 分别完整读取 1,048,593 / 262,144 字节，全部内容匹配。新增两项回归在旧实现失败，修复后真实 SMB2 / HTTP **21 / 21 通过，0 skipped，2.114 秒**。原取消回归改为明确的 TCP RST（`SO_LINGER(1,0)`），连续十次取消活跃读、不耗尽连接限额，owner stop / deinit 仍通过。证据 `.build/HTTPHalfCloseProbe/README.md`、`before.log`、`after.log` 和 `.build/SMBEvidence/smb-halfclose-full-suite-2026-10-03.log`。

FIN 本身无法区分有效半关闭与已放弃响应，后者由写入 / transport error 或 owner stop 取消。固定 VLC 正常 HTTP GET 路径未发现 `SHUT_WR`，本项不能认定为首次 CI seek 失败根因。该生产修复需要新的源码提交、平台构建与签名候选；下文 402034c / ee54fc8d 候选保留为此前证据。

## 播放与持久化执行证据

2026-10-03，iPhone 17 Pro / iOS 26.5 Simulator、Xcode 27.0，提交 `402034cd87fd10545d22e3ef33c8ee80473e75f0` 的播放 / 持久化代码：**13 / 13 通过，0 failures、0 skipped**，总执行 63.205 秒。其中 AppStore 5 项、FilmPlayback 8 项；SMB 实播 37.110 秒，外挂字幕 / 多轨 / 章节 1.963 秒，非致命字幕错误、同片重试与切片取消 10.539 秒。日志 `.build/PlaybackEvidence/ios-nonfatal-subtitle-full-smb.log`，结果 `.build/results/iOS-nonfatal-subtitle-full-SMB-20261003-0606.xcresult`。

4K HEVC 已有实际显示帧与音频输出；该 Simulator 的 VideoToolbox selected / accepted-frame 与硬件能力均为 false，不能据此声称硬件解码通过。真实字幕轨道加载与选中通过，字幕字形 / ASS 样式及人工声画同步仍待设备验收。详情见 [BACKEND_EVIDENCE.md](BACKEND_EVIDENCE.md)。

GitHub CI `37067646747` 对相同提交的第一轮：31 项共享回归、macOS / iOS Simulator 测试产物构建及 iOS device Release 构建通过；iPhone Air / iOS 27.0 的 13 项播放测试中 12 项通过，SMB 第一次跳转到 62 秒没有持续画面 / 时间推进，超时失败。原始日志 `.build/ci-402034c-failure.log` 和下载的 `.build/CI402PlaybackResult/` 保留。第二轮同提交重跑：真实 SMB 完整 20 次 seek / 重开通过，75.735 秒；唯一失败为暂停静止检查在底层异步 pause 确认前记录基准，后续位置 3.098 相比 2.346 超出原 0.35 容差。日志 `.build/ci-402034c-attempt2-failure.log` 保留。测试随后加入真实 backend paused / playing 状态确认，再记录基准；原静止时间、0.35 容差、快速暂停 / 继续与 SMB 无等待操作序列均保留。首次 seek 超时尚未确定根因；新增只读原始状态与无凭据的 range / bytes 诊断，未修改生产 pause / seek 行为。目前不能声称最终 CI 已通过。

HTTP 修复后的首次诊断全组 13 / 13 通过，62.168 秒；暂停确认修改后的全组曾 12 / 13，SMB 跳转采样失败，旧结果保留。100 ms 细化诊断记录到一例明确的界面值滞后：seek 68 时 raw backendTime 69.885 且已输出新帧，而 SwiftUI position 仍是 68.0；约 200 ms 后界面值更新为 70.028，错过原目标窗口。SMB 精度断言随后改读底层时间，仍要求 `target + 0.2 < time < target + 2`、新显示帧、原 12 秒超时和无等待快速操作序列，不用乐观目标值代替成功证据。每个 case 有独立 120 / 180 秒 XCTest watchdog。最新源码的完整复跑与新 iOS 27 CI 仍待确认；增量 Runner 执行旧事件的问题另行保留，重新构建与重启自己的测试设备后再判断实际行为。

## 签名候选执行证据

2026-10-03，提交 `402034cd87fd10545d22e3ef33c8ee80473e75f0` 的 macOS universal Release 与 iOS 签名 Release archive 构建通过。App 与 DMG 的 Developer ID 签名、公证均为 `Accepted`，票据装订和验证通过。已只读挂载这个新候选，真实卷标为 `AetherFilm`，包含 `AetherFilm.app`、指向 `/Applications` 的链接、许可证和中文安装说明；App 为 0.1.0 / build 1，最低 macOS 26，主程序与两个框架均有 arm64 / x86_64，不含测试 fixtures / 插件，含正式图标。

此前未发布候选（需要因 HTTP 修复重新构建）：`artifacts/AetherFilm-0.1.0-macos-universal.dmg`，60,249,014 bytes，SHA-256 `ee54fc8dd8a1f84604940278939c1a0e0e6cab06b73f2db3c7d60ec04d5b7600`。公证日志 `.build/package-402034c-retry.log`，公证记录 `artifacts/notarization-0.1.0.xt5c5H/`；本地 28 项检查通过，证据 `.build/ReleaseEvidence/local-inspection-402034c.json`。`artifacts/CANDIDATE_MANIFEST.json` 记录该源码提交和全部三个分发资产的 SHA256；尚未验证公开下载和图形首启。

相同 `ee54fc8d` 候选在 Tart `macos27` 完成独立 **54 项安装文件系统 / 签名预检**：Gatekeeper 为 `assessments enabled`，DMG、挂载 App 与安装副本均被评估为 `Notarized Developer ID` 且没有 security override；严格签名、票据、真实许可证哈希和两个架构均通过。证据 `.build/ReleaseEvidence/candidate-ee54fc8d/vm-preflight.json` 与 `.log`。安装副本位于本轮自有临时验收目录；VM 仍停留在登录窗口，图形首启、实际播放以及首次启动策略执行尚未验证。没有更改任何账户、自动登录或安全设置。

此前候选（已因播放按钮命中区域修复而替换）保留于 `artifacts/previous-candidates/0.1.0-969ae33c/AetherFilm-0.1.0-macos-universal.dmg`，SHA-256 `969ae33c72535a8db8a617d089c6e45d5edd6e2617d47951cb49276a353c07e8`；日志 `.build/package-candidate-verified.log`，公证记录 `artifacts/notarization-0.1.0.DHVc7j/`。主机 `spctl` 返回 `Notarized Developer ID`，同时标明现有策略 `override=security disabled`，所以本项不能代替启用 Gatekeeper 的 VM 首启验收；本任务没有更改主机安全设置。此前候选的 VM 文件系统安装与签名检查不代表修复后新候选的验收。图形首启、播放与公开下载仍待验收，版本没有发布。

## iPad 布局与官网候选证据

独立自建 iPad Pro 11-inch (M5) / iOS 26.5 Simulator：浅色列表、深色表单 / 列表、横屏播放器及实际系统 `accessibility-extra-large` 字体，共 **4 项通过、0 失败**。6 张截图已逐张检查，侧栏、列表和横屏控制正常。大字体表单完整键盘滚动 / 连接流程以及实际分屏仍未覆盖。证据 `.build/iPadUIEvidence/review.md`、`review.json` 和两个 `.xcresult`；原系统字体已恢复，仅本轮自建模拟器已删除。

官网在 `.build/SitePreview/site` 隔离副本完成验证：检查与完整构建、153 项测试通过；中英首页 / 产品 / 隐私 / 帮助，桌面 1440 与手机 390，共 16 个真实浏览器场景通过。没有横向溢出、缺失图片、脚本或 HTTP 错误；同时修复了英文 YAML 标量中的逗号截断。证据 `.build/SitePreview/Evidence/README.md` 与截图 / `render-report.json`。原官网没有修改或部署，候选如实显示开发中，未设置虚构下载链接。

## UI 自动化执行计划与证据

共享测试：`Tests/AetherFilmUITests/AetherFilmUITests.swift`，每个平台 19 个 case。执行脚本：`scripts/test_ui.sh`；缺少样片时调用生成脚本，缺少必要资源会失败。macOS 脚本会拒绝宿主机，iOS 必须提供明确的测试 destination。两个平台 build-for-testing 已通过；iPhone Simulator 全组已实际运行通过，macOS 仍待 VM 图形登录后运行。

| 流程 | 预期证据 | macOS | iOS |
| --- | --- | --- | --- |
| 本地 / 续播空状态、导入与取消 | 原生文件选择器可打开与关闭，空状态恢复 | 待测 | Simulator 通过 |
| SMB 表单必填、端口、加密选项、取消 | 连接按钮状态正确，取消关闭，认证数据不进入截图 | 待测 | Simulator 通过，含键盘上方开关操作 |
| 格式行、播放入口、时间推进 | MP4 标识、播放器控制、真实时间变化与截图 | 待测 | Simulator 通过，暂停按钮实际 frame 至少 44×44 点 |
| 控制层自动隐藏 / 单击唤回 / 暂停保持显示 | 真实交互与播放器截图，保留正常自动隐藏逻辑 | 待测 | Simulator 通过，含视频中心手势及拖动后按住 5 秒 |
| 倍速 / 播放设置 / 返回视频 | 倍速菜单生效，原生设置可打开与关闭 | 待测 | Simulator 通过 |
| Mac 全屏 / iPhone 横屏 | 实际视频 frame 覆盖显示器或旋转后控件仍在屏幕内 | 待测 | Simulator 横屏通过 |
| 续播 / 已看 / 清记录 / 移除 | 同一隔离 session 重启保存状态，其余条目保留 | 待测 | Simulator 通过 |
| 目录加载 / 失败 / 重试 | 失败可重试，新请求经过加载，再返回明确错误 | 待测 | 虚拟 NAS Simulator 通过 |
| 目录进入 / 空目录 / 上一级 / 切换片源 | 层级正确，空状态可返回，旧片源列表清除 | 待测 | 虚拟 NAS Simulator 通过 |
| 当前列表筛选 | 无匹配显示空结果 | 待测 | Simulator 通过 |
| 浅深色 / 窄窗 / 大字体 | 实际窗口 frame 和可点击区域断言，以及逐张截图审核 | 待测 | iPhone 390×844 点与实际系统大字体通过；iPad 4 项布局烟测通过 |
| 减少透明度 | 系统真实状态启用时运行；保存和恢复测试前设置 | 待测 | 原生 Settings 开关及实际 UIKit 状态确认通过，已恢复 |
| 可访问性描述 | 系统 accessibility audit 结果；VoiceOver 另行验收 | 待测 | sufficientElementDescription audit 通过；VoiceOver 人工验收待测 |

`--ui-test-session=<UUID>` 为每个 case 创建隔离目录，并保留同一 case 重启数据。虚拟 NAS 用于界面状态验证，真实 SMB 的认证 / 加密 / 读取 / 播放仍需要独立协议集成与设备证据。减少透明度 case 在系统未启用时会标记 skipped，需要单独启用系统设置后执行才算通过。

结果目录：`build/ui-results/`，保留 `.xcresult`、日志和截图附件。iOS 使用本轮自建 iPhone 16e Simulator `29CA8331-DEB8-4F00-94AD-C3DF5F96F440`，iOS 26.5（23F77）、Xcode 27.0（27A266a）。最终测试对应源码 commit `402034cd87fd10545d22e3ef33c8ee80473e75f0`；六份产品 / 测试源文件逐一与该提交比对一致，SHA256 和 xctestrun 路径记录于 `iOS-20261003-fresh19-source-proof.json`。

首轮 `iOS-20261003-0454.xcresult`：18 case，11 通过 / 6 失败 / 1 skipped。失败包括长路径 identifier 查询超过 XCTest 128 字符限制、空状态容器覆盖按钮 identifier、toolbar 容器被当作真实 disabled 按钮，以及倍速可访问性 label 缺少值。对应查询和视图可访问性已修正，原失败结果与附件保留。

第二轮 `iOS-20261003-full-second.xcresult`：19 case，15 通过 / 4 失败 / 0 skipped。真实系统 Reduce Transparency 已通过，原生 Settings 开关与 UIKit 实际状态均确认启用，结束恢复关闭；`EnhancedBackgroundContrastEnabled=0` 已核对。此轮还发现短加载态采样延迟、自动隐藏控制的查询延迟，以及点击整行 Switch 中心没有触及原生开关的问题；测试继续修正后完整复跑。旧失败不会被后续结果覆盖。

第三轮 `iOS-20261003-candidate.xcresult`：19 case，15 通过 / 4 失败 / 0 skipped。目录加载重试与真实系统减少透明度通过。播放器暂停失败被证据确认是产品按钮命中区域缺陷：`player.playPause` 可访问性 frame 仅 13.3×18 点，中心处是暂停图标的空白，点击落到视频单击手势并隐藏控制。产品随后将 44 点图标 label 增加矩形 `contentShape`，待修复后的运行证明。另外两个测试动作已校正：拖动从真实 Slider thumb 开始；SMB 开关先滚到键盘上方后点击原生 Switch，避免点击键盘导致端口多出字符。修复前截图、可访问性树和事件附件全部保留在 `iOS-20261003-candidate-attachments/`，未将失败改写为通过。

最终完整运行 `iOS-20261003-fresh19.xcresult`：**19 / 19 通过，0 failures、0 skipped，283.655 秒**。命令使用独立 `AetherFilm-iOS-ui-fresh-20261003-0540.xctestrun`、明确 Simulator UUID、`-only-testing:AetherFilmUITests-iOS -collect-test-diagnostics never -parallel-testing-enabled NO`。日志 `iOS-20261003-fresh19.log`、结果摘要 `iOS-20261003-fresh19-summary.json` 与 22 张原始截图 `iOS-20261003-fresh19-attachments/` 已保留。逐张审核确认浅深色列表、空状态、格式 / 已看 / 续播行、原生 SMB 表单、播放设置、实际视频画面和横屏控制布局正常；SMB 加密开关能滚至键盘上方并操作。附件名 `Recoverable NAS directory failure` 的图实际记录返回本地空状态，目录错误 / 重试的通过依据为事件与元素断言，不能将这张图当作错误页截图。

播放器按钮修复后的实际 frame 至少 44×44 点，中心空白处暂停成功。透明 SwiftUI 手势层在真实视频中心接收单击与双击；快进至少 8 秒的断言通过。最终日志明确执行先移动 Slider、再按住 5 秒的 API（0.1 秒按下、250 pixels/s 拖动、hold 5.0 秒），随后控制自动隐藏、中心单击唤回、暂停后保持显示均通过。独立预检 `iOS-20261003-drag-hold-preflight.xcresult` 亦通过，连续视频 `iOS-20261003-drag-hold-video.mp4`（35.8 秒）和 `iOS-20261003-drag-hold-midframes/` 留存按住期间控制仍可见的证据。此前 `iOS-20261003-final19.xcresult` 虽为 19 / 19，其日志包含旧的先静止长按 5 秒动作；原因未确认，因此又卸载自有 Runner、重启自有设备并用唯一 xctestrun 完整复跑，最终以 fresh19 的实际新事件为准。旧结果保留。

历史边界已追加聚焦确认，未改写旧失败：`iOS-20261003-surface-preflight.xcresult` 中先静止长按 5 秒再移动，曾出现控制层不再自动隐藏。对最新 commit `402034c`，在 `.build/StaticSliderProbe/` 构建独立 UI Runner，目标 App 主程序、实际 Debug dylib 和两份自建样片均与 fresh19 产品字节相同，正式产品与 19 项测试源码均未改动。使用新自建 iPhone 16e `910CF366-E8DF-47B7-B7BC-B3CA07D5ABAC`，`iOS-20261003-static-fresh.xcresult` **2 / 2 通过，0 skipped，67.645 秒**：真实 thumb 先静止按住 5 秒再拖动释放后，时间继续推进并在原 8 秒窗口内自动隐藏；再次同动作、按 Home、等待实际后台状态、恢复后等待暂停按钮实际可点击、显式续播、退出重开和真实 seek 后，时间推进与自动隐藏均通过。未在最新产品复现持续卡住，无需产品修改；本项没有模拟手指尚按住时的系统取消。

聚焦过程原结果亦保留：`iOS-20261003-static-focused.xcresult` 为 1 通过 / 1 失败，失败在按 Home 后立即读取 app.state，播放 / 自动隐藏断言通过。`iOS-20261003-static-interruption.xcresult` 在恢复后先点视频，随后暂停 HUD 查询失败；等待控件实际可点击后通过，与返回动画中的状态竞争一致，但未独立确定底层原因。`iOS-20261003-static-paused-restore.xcresult` 的日志仍运行旧诊断断言，不能当作最新诊断结论。仅卸载自有 Runner、重启自建设备、改用唯一 xctestrun 后，最终日志确认先等后台 / 控件可点击再交互，两项均通过。最新日志、summary、截图和实际 thumb 几何位于 `iOS-20261003-static-fresh*`，App 字节比对与独立测试源 SHA256 记录于 `iOS-20261003-static-product-proof.json`，诊断源 / spec 归档于 `build/ui-results/StaticSliderProbeSource/`。诊断结束后仅清理新自建 `910CF...` 设备，记录 `iOS-20261003-static-owned-device-cleanup.json`；没有更改系统可访问性设置。

减少透明度通过既有测试的原生 Settings 操作启用，实际 `UIAccessibility.isReduceTransparencyEnabled` 必须为 true；截图同时记录系统开关和应用。测试 defer 将开关恢复 0，随后核对 `EnhancedBackgroundContrastEnabled=0`，并恢复测试前该偏好键不存在的状态。没有伪造只读 SwiftUI environment。额外实际系统大字体运行 `iOS-20261003-system-large-text.xcresult`：既有大字体 case **1 / 1 通过，0 skipped，11.059 秒**；先读取字号 `large`，用 simctl 将本轮自有设备设为 `accessibility-extra-large`，结束恢复 `large` 并读回确认。`iOS-20261003-system-large-text-attachments/` 两张图已审核，文件列表和原生 SMB sheet 文字同步变大并换行，取消 / 连接保留在视口内；登录 / 高级部分需要滚动，本项不证明大字体下完整认证流程通过。安装后主屏幕图标截图 `iOS-20261003-home-screen.png` 已审核，玻璃 A / 播放符号在原生图标尺寸下可辨。确认恢复后只清理自建 `29CA...` 设备，记录 `iOS-20261003-owned-device-cleanup.json`；其他设备未操作。

iPad 的独立自建 Pro 11-inch（M5）/ iOS 26.5 Simulator 共 **4 项布局烟测通过、0 failures**，包括浅深色双列、SMB sheet、横屏播放和实际系统 `accessibility-extra-large`；六张截图已审核。证据 `.build/iPadUIEvidence/review.json`、`review.md`、两个 xcresult 与 `screenshots/`。字号恢复 `large` 后仅清理自建 iPad 设备。该结果不替代键盘连接流程、iPad 分屏或物理设备验收。macOS Tart `macos27` 尚无登录图形会话；准备的 UI 测试不能运行，不将无 GUI 导致的启动失败记作播放器失败，也没有改动 VM 账户或自动登录设置。
