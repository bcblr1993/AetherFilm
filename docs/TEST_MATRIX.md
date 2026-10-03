# v0.1.0 验收矩阵

当前处于执行验收阶段，尚未发布。构建和部分协议 / 播放测试已有真实结果；失败、未测和未发布分别记录。每项执行后记录命令、环境、结果、证据文件和 commit。

当前生产源码基准为 `e4d7ff0f8e91e99cec13c6bca66c60dda795ad3a`。正式 iOS App 本地与该提交 CI 的播放 / 持久化测试均为 **29 / 29、0 skipped**；完整 UI 全组 **18 通过、1 项 opt-in 跳过**，减少透明度专项另行 **1 / 1、0 skipped**，合计 19 个场景实际执行。旧 CI 整轮因共享测试 7 项失败而失败；两处 TCP 测试辅助代码改用独立 GCD queue 后，本地共享 **41 / 41、0 skipped**，新提交 CI 仍待验证。该辅助修复未改变生产 App、服务、桥接、工程规范或资源。历史结果保留，不能将单个绿色 job 或旧签名包视为当前发布完成。

| 层级 | 场景 | macOS | iOS |
| --- | --- | --- | --- |
| 构建 | 最低部署版本 26；Debug / Release；真机 archive | 当前正式桥接 Debug / tests 与 universal Release 构建通过；新签名 DMG 未制作 | 当前 Simulator Debug / tests、device build 与 Apple Development Release archive 构建通过；archive 57 项检查通过 |
| 本地 | 导入、取消、重复、中文 / 空格路径、重启访问 | 待测 | 待测 |
| SMB | 共享 / 目录、认证、中文路径、随机读取、Range、错误密码、超时 / 取消、加密失败不回落 | 28 项 Sources 回归通过；VM 播放、真实 NAS 与 SMB3 加密成功待测 | 本地及 CI Simulator 真实 SMB 播放、20 次远近 seek、停止后重开通过；真实尾部读错拒绝完成与新流重试通过；真机待测 |
| 播放 | H.264 + AAC MP4；HEVC MOV；MPEG4 + MP3 AVI；多轨 MKV；实际画面 / 音频输出 / 时间推进；4K HEVC | VM 待登录运行 | 四种容器与 4K HEVC Simulator 实际输出通过；真机硬件解码待测 |
| 控制 | 暂停 / 继续、进度跳转、倍速、全屏、结束、切换影片、退出清理 | VM 待测 | 正式桥接 / 音频 / EOF / 持久化本地与 CI 29 / 29 通过；当前完整 UI 与减少透明度专项通过；真机待测 |
| 字幕 | SRT / ASS / VTT 中文、内嵌字幕、开关、跳转同步、无字幕 | VM 待测 | Simulator 内嵌 / 外挂 SRT、ASS、VTT 选择与关闭、章节跳转、坏字幕不中断视频与同片重试通过；视觉同步 / 真机待测 |
| 音轨 | 单 / 多音轨、切换、无音轨、不可解码错误 | VM 待测 | 多轨选择通过；其余 UI / 真机待测 |
| 记录 | 断点、重启恢复、片尾完成、已看、清除；库条目删除不删除原文件 | Domain 9 / Library 4 通过；AppStore / UI 待 VM 运行 | AppStore 8 case 与当前 UI 回归通过；未确认片尾 seek 可续播、已确认已看不被清除、源失败 / 旧会话拒绝完成通过 |
| UI | 本地 / 续播空状态；导入入口；SMB 表单校验 / 取消；目录 / 返回 / 空目录；列表筛选；失败重试；格式 / 观看状态；播放入口 | 自动化已编写，待 VM 运行 | 全组 18 通过、1 opt-in 跳过；专项减少透明度 1 通过、0 skipped；19 场景已实跑，虚拟 NAS 状态不替代真实协议 / 真机 |
| 可访问性 | 动态字体、可访问性描述、VoiceOver、实际系统减少透明度、键盘导航 | 待实际运行 / 人工验收 | 当前描述 audit / 减少透明度专项通过；历史设置页标准 / 大 / 最大系统字号与滑杆证据保留；全应用最大字号、真实 VoiceOver / 真机人工验收待测 |
| 适配 | 980×680 / 620×440 窗口、浅深色；iPhone 小屏 / 横屏；iPad 分屏 | 自动化已编写，待截图审核 | 当前 iPhone 22 张 UI 截图已审核；历史 iPad 4 项布局烟测通过，当前完整 iPad / 分屏和键盘表单仍待测 |
| 分发 | 签名、公证、DMG 标签和内容、安装、首启、公开下载 SHA256 | 磁盘 c790607 DMG 为旧候选；VM 54 项仅对应旧 5e12be2；当前源码的新签名 / 公证包、VM、首启 / 播放和公开下载待测 | 不适用 |
| 分发 | 真机安装 / 播放、TestFlight 构建和安装、公开入口 | 不适用 | 当前 archive 57 项通过，Apple Development / get-task-allow=true；手机仍锁定，安装 / 播放 / TestFlight / 公开入口待测 |
| 官网 | 中英介绍、真实截图、系统要求、下载 / 发布链接、线上访问 | 隔离候选 153 项测试及 16 个浏览器场景通过；实际截图、下载与线上部署待完成 | 开发状态页面候选通过；无公开 iOS 安装链接 |

共享代码回归：文件格式 / 自然排序、目录边界、HTTP Range、进度边界、编码往返、损坏 / 未来版本数据、密钥不入普通持久化和源健康。当前两处 TCP 测试辅助修复后的完整共享测试 **41 / 41、0 failures、0 skipped**：Domain 9、Library 4、Sources 28，证据 `.build/SMBSocketQueueFixEvidence/review.json`。旧 `e4d7ff0` CI 的共享结果为 34 / 41、7 failures，原始失败保留，修复后新提交 CI 待验证。历史半关闭阶段的 33 / 33 日志 `.build/kit-full-halfclose-candidate.log` 和此前 31 项 `.build/kit-full-candidate.log` 仍保留。

协议集成使用隔离 SMB2 服务和自己生成的媒体样片，验证认证、读取、HTTP Range、取消、超时与失败路径。WebDAV / Jellyfin 未入选本期，不是本期验收项。

macOS UI 优先在 Tart `macos27` 验证，避免占用用户主机键鼠。自动化结果不替代 iPhone 的硬件解码、声音、4K 和安装验收。测试样片由脚本生成，不提交版权影片。

下列分阶段证据保留各自原提交和结果；当前结论以前述矩阵和文末正式集成记录为准。

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

HTTP 修复后的首次诊断全组 13 / 13 通过，62.168 秒；暂停确认修改后的全组曾 12 / 13，SMB 跳转采样失败，旧结果保留。100 ms 细化诊断记录到一例明确的界面值滞后：seek 68 时 raw backendTime 69.885 且已输出新帧，而 SwiftUI position 仍是 68.0；约 200 ms 后界面值更新为 70.028，错过原目标窗口。SMB 精度断言随后改读底层时间，仍要求 `target + 0.2 < time < target + 2`、新显示帧、原 12 秒超时和无等待快速操作序列，不用乐观目标值代替成功证据。每个 case 有独立 120 / 180 秒 XCTest watchdog。增量 Runner 执行旧事件的问题及旧失败结果均保留。

最新源码 `5e12be2fb9f62923ce3477ad590e79065b667135` 在移除自己的旧测试 host、重启明确指定的 iPhone 17 Pro / iOS 26.5 Simulator 并使用全新 DerivedData 后，完整 **13 / 13 通过，0 failures、0 skipped，61.837 秒**。真实 SMB 两次打开与 20 次 seek 通过，36.081 秒；306 次读取都有结束或取消事件，共 612 条、0 遗漏、0 错误。20 次跳转都满足底层时间推进和新显示帧断言，其中 15 次成功时 UI position 仍停在刚设置的目标值，确认不能用界面采样替代底层输出判定。产品暂停 / seek / 播放行为未改变。证据 `.build/PlaybackEvidence/diagnostic-final-review.json`、`ios-diagnostic-backend-clock-fresh-full-smb.log` 与 `.build/results/iOS-diagnostic-backend-clock-fresh-full-SMB-20261003-0610.xcresult`，三个相关源文件 hash 与提交一致。本地结果不替代新 CI、真机或 Mac GUI 验收。

新 GitHub CI `37070907202` 首轮：33 项共享回归与三个平台构建通过，iOS 27 播放 **11 / 13 passed、2 failed、0 skipped**，119.927 秒。失败为 SMB 首次 seek 62 秒时底层时钟停在 62.0，以及坏字幕 case 在添加字幕之前的本地 MP4 初始画音输出超时（所有输出计数为 0）；不能把后者称为字幕加载失败。SMB 前四个 512 KiB 读取耗时 9.773 / 7.490 / 5.518 / 5.585 秒；seek 在 t27.264 发起，新高偏移的 provider 读取 begin 在 t36.718，2.670 秒后随测试结束取消，无结束或错误事件。该 begin 位于 HTTP 解析与响应头发送之后，不是 TCP 到达或 VLC 发出请求时间。旧读在测试层 100 ms 延迟之前就取消，没有进入共享 C 会话。日志另有 CoreAudio overload / no-object 消息。这些是广泛迟滞的证据，尚未确定最终根因，也未证明快速 pause / seek / play 无竞态。保留 `.build/ci-5e12be2-platform-failure.log`、`.build/CI5ePlaybackResult/` 与安全数值附件 `.build/CI5ePlaybackAttachments/`。

同源新 runner 的 attempt 2 为 **12 / 13 passed、1 failed、0 skipped，138.207 秒**，仍是首次 SMB seek 62 秒失败；之前字幕 case 的本地 MP4 初始零输出未再次出现。本轮 provider 高偏移读取在 seek 后 11.162 秒才开始，距断言期限仅 0.930 秒；旧读取消耗时 2.655 秒，不能沿用首轮 10 ms / 未进入 C 的排除结论。HTTP / SMB 链路没有 MainActor 要求；固定 AMSMB2 同 context 的命令锁确实存在，但取锁、C 入口和 HTTP 首字节均未计时，不能认定锁争用或系统负载是根因。完整精确来源：job `111054789327`、artifact `11255992751`，ZIP SHA256 `422990e84709bf55dbedac01bf787eecf5f3a64b7d1530d8bf52086173e83553`，证据 `.build/CI5eAttempt2Evidence/review.md` / `review.json`。旧源失败保留；后续新源 CI 是独立验证。

## 异步音频与暂停控制回归

对 `5e12be2` 做隔离诊断时，实际 VLC paused 回调被暂存，在确认底层暂停并重新输出画面 / 音频后，经原 MainActor Task 路径放回。旧代码把界面状态写为暂停，但底层仍在播放，下一次真实 toggle 未暂停：原 case 失败 6.687 秒，时钟在 800 ms 内从 5.192 推进至 6.002，超出原 0.35 容差。仅改为按当前 engine state 发布暂停状态后，相同 case 通过 3.563 秒，真实 toggle 后时钟保持静止。无虚构 callback / backend state，证据 `.build/PlayerEventRaceProbe/evidence/review.json`、两个原始 xcresult 和日志。它证明独立的控制状态缺陷，不能据此宣称已确定 CI SMB 超时根因。

将该修复及后台串行音频协调层接入后的初步源码（FilmPlayer SHA256 `6881cb022cf16db9232d0ff84c0480677e291926b8d0d857e57e2cd6a0860b02`）在实际 iOS 26.5 Simulator 完整 **18 / 18 通过，0 failures、0 skipped，63.470 秒**：AppStore 5、FilmPlayback 9、AudioSessionCoordinator 4。协调层覆盖非主线程执行、FIFO、多个 owner、失败与重复释放；真实媒体和 20 次 SMB seek 仍保留原严格断言。证据 `.build/PlaybackEvidence/AudioSessionIntegration/full18-before-reattach-test.log` 与 `.build/results/iOS-audio-full18-before-reattach-20261003-0650.xcresult`。

只读 review 另发现无 drawable 的完成分支释放音频后，仍播放中的播放器重新挂载未必再次激活音频。补齐实际 nil→surface 音频恢复后，最终工作源码（FilmPlayer SHA256 `6111efafdd176ab206f3ef14a4cbce50f8a67b53bf0cec190e6b4b6240ecdba7`）全新构建与实际执行 **22 / 22 通过，0 failures、0 skipped，70.895 秒**。新增 4 项通过可控后台 gate 调用真实 AVAudioSession，验证准备时暂停 / 重复播放、stop / 换片后旧完成、初始无 surface、已播放中的 surface 重挂载；均要求真实 VLC 输出。关键重挂载确实经历 backend playing=true、音频 API 已成功停用的触发状态，随后第三次真实激活及时间 .913→1.415、显示帧 31→45、音频输出 106→129 通过。driver active 字段是系统 API 成功反馈，不代替人工听音或真机验收；没有将此运行称为旧 guard 的 A/B 失败对照。证据 `.build/PlaybackEvidence/AudioSessionIntegration/full22-test.log` 与 `.build/results/iOS-audio-full22-reattach-6111.xcresult`。同源 3 项 UI 聚焦和签名候选已有后续结果（见下文），新 CI 存在失败，设备验收仍待完成。

新源码 `c7906074451b0a8ccb0b5ad6f7f462f3ea60f4c1` 的 GitHub CI `37075306804`：共享 **33 / 33** 与三个平台构建通过，iOS 27 播放 **21 / 22 passed、1 failed、0 skipped**。迟到暂停、音频协调和四项真实音频准备回归通过，完整日志中两种 AudioHangRisk 文本均为零，xcresult 的 runtimeWarnings 为空。SMB 完整 20 次 seek / 重开本轮通过，但最慢 seek 用时 11.668 秒、接近原 12 秒期限，不能据单轮宣称稳定性已解决。唯一失败是 `testPauseSeekRateResumeAndNaturalCompletion`：seek 11 后 wrapper getter 先返回目标 11，再回退至旧时间 6.179；随后 stopping / stopped，应用误报中断，正常结束回调未发出。统计计数不能代替 EOF 原因证据。完整 job / xcresult / 附件与源码哈希见 `.build/CIc790607Evidence/review.md` 和 `review.json`；不修改原断言、等待期限或旧失败。

## 签名候选执行证据

`c790607` 的新 macOS universal Release 与 iOS 签名 Release archive 已构建；Mac App / DMG 公证与装订通过，新 DMG 为 60,235,559 bytes，SHA256 `84c488982fb76402d8d47515b155de46e6b6d5c9f8b3350056f2cdac5ba4d684`。本地 **31 项**检查通过，证据 `.build/ReleaseEvidence/local-inspection-c790607.json`；未完成新包 VM GUI 验收。iOS archive 的 32 项文件 / 签名检查通过，但使用 Apple Development、`get-task-allow=true`，并非 App Store / TestFlight 分发导出；未安装锁定的真实 iPhone，证据 `.build/ReleaseEvidence/ios-archive-inspection-c790607.json`。当前 manifest 明确 `publicationReady=false`、CI failure。此包未包含随后设置页标题与 DEBUG 字号入口修复，不能认证其 UI；代码最终修复后需重新构建、公证与独立验收。

此前候选源码 `5e12be2fb9f62923ce3477ad590e79065b667135` 已重新完成 macOS universal Release、macOS / iOS physical Debug build-for-testing 与 iOS 签名 Release archive。Debug 源码与提交逐字节一致、测试 host / bundle / 可执行文件及 xctestrun 均存在，证据 `.build/DebugBuildEvidence/5e12be2/provenance.json`；构建不代表运行测试。iOS archive 严格签名及 team、arm64、最低 26.0、iPhone / iPad family、图标和许可证均已核验，不含测试插件和样片；证据 `.build/ReleaseEvidence/ios-archive-inspection-5e12be2.json`，尚未安装或运行于锁定的 iPhone。

该旧候选 App 与 DMG 公证均为 `Accepted`，装订票据及签名通过。首次 DMG 提交遇到 `HTTPClientError.connectTimeout`，失败日志 `.build/package-5e12be2.log` 保留；同源重试成功，日志 `.build/package-5e12be2-retry.log`，记录 `artifacts/notarization-0.1.0.8YP1Kp/`。保留的旧 DMG `artifacts/previous-candidates/0.1.0-fb32d110/AetherFilm-0.1.0-macos-universal.dmg` 为 60,249,938 bytes，SHA-256 `fb32d110b58e0c17d61120ea8375677352a9846d9e2368f5f6ce665406690c74`。只读挂载后 **31 项本地检查通过**，包括真实卷标、Applications 链接、版本 / 最低系统、图标 / 原许可证、无测试资源、三个 Mach-O 的 arm64 / x86_64、严格签名 / 票据，以及主程序两片 UUID 与当前源码构建产物一致。证据 `.build/ReleaseEvidence/local-inspection-5e12be2.json`；该旧候选目录保留的 `CANDIDATE_MANIFEST.json` 与 `SHA256SUMS.txt` 覆盖其包和两个源码材料包。主机仍有原有 security override，未改变其策略，因此该处评估不能代替开启 Gatekeeper 的 VM 验收。

同一 `5e12be2 / fb32d110` 新候选已在 Tart `macos27` 完成 **54 / 54 安装文件系统 / 签名预检**。Gatekeeper 为 `assessments enabled`，DMG / 挂载 App / 安装 App 三次均为 `Notarized Developer ID`、无 override；原许可证逐字节 hash、版本 / 双架构 / 图标 / 无 debug dylib / 测试资源均通过。当前 Debug Products ZIP 两端 hash、6 个产品文件 hash 与 5 个 relocated paths 通过。证据 `.build/ReleaseEvidence/candidate-fb32d110/reviewed-summary.json`、`vm-preflight.json`、`testing-products.json`，待执行命令在 `READY_FOR_GUI.md`。VM console 仍为 root / 登录窗口，没有启动 GUI 或 XCTest，也没有修改账户、自动登录或安全设置；元数据明确 `publicationReady=false`。首启 / 实际播放、失败 CI 的处理和真机验收未完成，公开下载与网站部署未执行。

2026-10-03，此前提交 `402034cd87fd10545d22e3ef33c8ee80473e75f0` 的 macOS universal Release 与 iOS 签名 Release archive 构建通过。App 与 DMG 的 Developer ID 签名、公证均为 `Accepted`，票据装订和验证通过。旧候选的只读挂载中，真实卷标为 `AetherFilm`，包含 `AetherFilm.app`、指向 `/Applications` 的链接、许可证和中文安装说明；App 为 0.1.0 / build 1，最低 macOS 26，主程序与两个框架均有 arm64 / x86_64，不含测试 fixtures / 插件，含正式图标。

此前未发布候选已保留于 `artifacts/previous-candidates/0.1.0-ee54fc8d/AetherFilm-0.1.0-macos-universal.dmg`，60,249,014 bytes，SHA-256 `ee54fc8dd8a1f84604940278939c1a0e0e6cab06b73f2db3c7d60ec04d5b7600`。公证日志 `.build/package-402034c-retry.log`，公证记录 `artifacts/notarization-0.1.0.xt5c5H/`；本地 28 项检查通过，证据 `.build/ReleaseEvidence/local-inspection-402034c.json`。该目录保留的 `CANDIDATE_MANIFEST.json` 记录旧源码提交和全部三个分发资产的 SHA256；不能用来认证新候选，尚未验证公开下载和图形首启。

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
| 浅深色 / 窄窗 / 大字体 | 实际窗口 frame 和可点击区域断言，以及逐张截图审核 | 待测 | iPhone 390×844 点与受控 accessibility3 大字体布局通过；iPad 4 项布局烟测通过 |
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

减少透明度通过既有测试的原生 Settings 操作启用，实际 `UIAccessibility.isReduceTransparencyEnabled` 必须为 true；截图同时记录系统开关和应用。测试 defer 将开关恢复 0，随后核对 `EnhancedBackgroundContrastEnabled=0`，并恢复测试前该偏好键不存在的状态。没有伪造只读 SwiftUI environment。额外实际系统大字体运行 `iOS-20261003-system-large-text.xcresult`：既有大字体 case **1 / 1 通过，0 skipped，11.059 秒**；先读取字号 `large`，用 simctl 将本轮自有设备设为 `accessibility-extra-large`，结束恢复 `large` 并读回确认。`iOS-20261003-system-large-text-attachments/` 两张图已审核，文件列表和原生 SMB sheet 文字同步变大并换行，取消 / 连接保留在视口内；登录 / 高级部分需要滚动，本项不证明大字体下完整认证流程通过。 后续源码复核确认：该正式大字体 case 显式传入 `--ui-content-size=accessibility3`，DEBUG helper 覆盖系统字号；旧结果证明受控大字体布局，不能单独证明应用自动跟随系统字号。记录系统设置和恢复行为仍有效。默认 UI 测试也曾被 helper 强制 large；新设置滑杆验收发现此问题后，已改为仅显式参数覆盖，其他情况保留系统字号，并独立复测。安装后主屏幕图标截图 `iOS-20261003-home-screen.png` 已审核，玻璃 A / 播放符号在原生图标尺寸下可辨。确认恢复后只清理自建 `29CA...` 设备，记录 `iOS-20261003-owned-device-cleanup.json`；其他设备未操作。

iPad 的独立自建 Pro 11-inch（M5）/ iOS 26.5 Simulator 共 **4 项布局烟测通过、0 failures**，包括浅深色双列、SMB sheet、横屏播放和显式 `accessibility3` 大字体布局；六张截图已审核。证据 `.build/iPadUIEvidence/review.json`、`review.md`、两个 xcresult 与 `screenshots/`。字号恢复 `large` 后仅清理自建 iPad 设备。旧大字体 case 同样显式传入 accessibility3，所验证为受控字体布局；原报告中实际系统字号驱动的说法已在补充记录中纠正，不删除旧结果。该结果不替代键盘连接流程、iPad 分屏或物理设备验收。macOS Tart `macos27` 尚无登录图形会话；准备的 UI 测试不能运行，不将无 GUI 导致的启动失败记作播放器失败，也没有改动 VM 账户或自动登录设置。

对提交 `c7906074451b0a8ccb0b5ad6f7f462f3ea60f4c1` 的迟到暂停状态修复、后台音频协调与重新连接画面实现，使用完整 22 项播放回归同一份 `.build/PlaybackAudioReattachDerived/Build/Products/AetherFilm-iOS_iphonesimulator27.0-arm64.xctestrun` 做 iOS 播放器聚焦 UI 验证：**3 / 3 通过、0 failures、0 skipped，71.428 秒**。沿用既有正式测试，覆盖实际时间推进、暂停与续播记录在退出 / 重启后的持久化、真实 thumb 拖动后按住 5 秒、自动隐藏 / 单击唤回 / 暂停保持显示、倍速与原生设置返回；日志明确记录 thumb `[0.38, 0.50]` 移动至 `[0.45, 0.50]`，250 pixels/s，hold 5.0 秒。结果 `build/ui-results/iOS-20261003-audio-focused.xcresult`、同名日志 / summary 和 `iOS-20261003-audio-focused-attachments/` 的五张原始截图保留且已逐张审核：续播行清楚，真实样片画面从 16.167 秒推进至 20.375 秒，随后暂停在 22.375 秒，控制与设置在屏幕内正常呈现。`.build/UIAudioRegression/review.json` 记录 10 份源码与该提交逐一 SHA256 一致、运行前后产品未变化，以及实际主程序、承载 Swift 实现的 `AetherFilm.debug.dylib` 与 UI Runner 哈希；并非只核对启动器。使用已分配且由播放测试释放的现有 iPhone 17 Pro / iOS 26.5 Simulator `5DF11F8D-1DC2-4F30-8DB2-8518313C2ADD`，结束交回播放测试；未新建设备、删除设备、重建工程、修改正式 UI 测试或操作宿主键鼠。本次聚焦不重认证历史完整 19 项布局与静止长按诊断，也不补充真实后台中断、VoiceOver、物理 iPhone 或 macOS 图形会话证据。

本轮设置可见标签修复与真实系统字号验收：`PlayerScreen.swift` SHA256 `9a869832736035d8cab10a3cc0bd35f8d2b69c586c24b4b80f898d7c6bd4c617` 将“字幕大小”和“音量”标题放在各自原生 Slider 上方，并保留 Slider 的 VoiceOver 标签；可见标题避免重复朗读。`AetherFilmApp.swift` SHA256 `361e266b5b94a62379d3f3873e3ca555bd3efa11b02a3f56a418baa23e74aa11` 仅在 DEBUG UI 测试显式字号参数存在时覆盖 Dynamic Type，其他情况保留系统值。三个独立运行均 **1 / 1 通过、0 failures、0 skipped**：既有正式设置 case `iOS-20261003-system-label-settings.xcresult` 为 **21.110 秒**；独立诊断 Runner 在实际系统 `large` 下的 `iOS-20261003-system-label-standard.xcresult` 为 **28.867 秒**；实际系统 `accessibility-extra-large` 下的 `iOS-20261003-system-label-accessibility.xcresult` 为 **31.844 秒**。独立 Runner 未传字号覆盖参数，实际两 Slider 手势使字幕大小分别从 1 变为 1.757 / 1.737，音量均从 100% 变为 34%，之后实际点击“完成”返回视频并退出播放器。13 张原始截图逐张审核确认标题可见、系统大字体真实增长、较长设置行自然换行，滚动后滑杆和固定“完成”按钮均可操作；不是用隐藏文本的 accessibility 查询替代视觉证据。

证据 `.build/UILabelEvidence/review.json`、`system-font-probe-product-proof.json` 与 `installed-app-proof.json`：正式 Debug App、独立 Runner 使用的 App 副本及模拟器实际安装 App 的 **57 个文件逐一字节相同**，核对运行前后没有变化。实际承载 Swift 实现的 `AetherFilm.debug.dylib` SHA256 为 `017dc3405a87cc8c3ca3931fe2bbb757e0327360a43c73dafb069147580f28be`，主程序为 `4f35389385d44af1c823979b0233d7fc472fcdfc47f35c6fbf16b2efe924bca3`；10 份相关源码比对和完整 22 项回归的五份音频源码未变化记录亦保留。仍使用分配的 `5DF11F8D-1DC2-4F30-8DB2-8518313C2ADD`，字号恢复至原 `large`、外观仍为原 `dark` 并读回确认；仅卸载自建 `com.aethernative.AetherFilm.LabelProbe.xctrunner`，保留目标 App 与设备，记录 `cleanup.json`。第一轮旧 helper 强制 large 时的系统大字体日志和截图保留且降级为未认证系统跟随字号，不沿用其通过结论。该阶段证据只认证两个真实系统字号下的设置交互；最大可访问性字号由下述后续运行补充，VoiceOver 人工朗读、物理设备和 macOS GUI 仍待测，不视为发布门槛全部满足。

随后补齐实际系统最大字号边界：沿用同一无字号覆盖参数的诊断 Runner 和同一 App，系统设为 `accessibility-extra-extra-extra-large` 并读回确认，`iOS-20261003-system-label-maximum.xcresult` **1 / 1 通过、0 failures、0 skipped，33.674 秒**。字幕大小实际从 1 变为 1.731，音量从 100% 变为 33%；六张原始截图逐张审核，两个标题、全宽原生滑杆和固定“完成”按钮在滚动后均清楚可达，长文本自然换行，实际点击完成并返回视频 / 列表。之后恢复 `large` / `dark` 并读回，仍核对实际安装 App 全 57 文件与既有正式构建一致，仅清理自建诊断 Runner；证据 `.build/UILabelEvidence/maximum-execution.json`、`maximum-cleanup-proof.json` 和同一 `review.json`。最大字号缺口仅在本设置交互范围关闭，不推广为全应用布局或 VoiceOver 验收。macOS Debug 同源 `build-for-testing` 亦退出 0，日志 / 4 份源哈希前后稳定 / App UUID 见 `.build/UILabelEvidence/mac-debug-build.log` 与 `.json`；实际 Debug dylib UUID `A8DB226F-0038-3122-B3B0-E9D592809DE9`，SHA256 `5b85b2f5f061b1b65986a98b8cdfd27423e3e2f9f3f71ea42984b366b24a31de`。只编译未启动 macOS GUI，未重新生成正式工程。

2026-10-03 续播修复的共享模块回归：新增“未确认的片尾跳转经过 Codable 保存 / 重读后仍可续播”用例，并保留真实播放达到 95% 和手工已看标记的语义。隔离 SMB2 夹具下运行全部共享测试，**34 / 34 通过、0 failures、0 skipped**（源服务 21、存储 4、领域 9）。证据 `.build/ConfirmedProgressEvidence/review.json` 和 `.build/shared-confirmed-progress-full-smb.log` 记录精确源哈希；新增 AppStore 退出重开回归尚待平台执行，正式播放器三参数回调尚待集成。本结果不认证最终应用、CI、真机或发布。
## 正式片尾与源健康集成（2026-10-03）

在固定原始依赖和同一正式实现下，共享包 **41 / 41、0 failures、0 skipped**（Domain 9、Library 4、Sources 28）通过真实隔离 SMB2 夹具；日志 `.build/shared-source-health-full-smb.log`、源与日志哈希 `.build/ConfirmedProgressEvidence/source-health-shared-review.json`。新增源健康回归覆盖合法短读、真实读错、取消 / RST 排除、stop / deinit、错误认证及新实例重试。

完整 iOS App 的正式三参数进度回调、源健康查询与会话校验已联编并实际运行：**29 / 29、0 failures、0 skipped，76.272 秒**，含 AppStore 8、音频 8、EOF 4、原播放 9。真实 SMB 尾部读取失败不会发送完成或保存伪造终点；健康片尾、独立重播保留字幕、旧暂停回调与挂起验证器的会话隔离通过。原自然结束 6 秒期限、暂停漂移 0.35 秒及 SMB 20 次跳转断言未放宽；本轮自然结束 3.105 秒、真实 SMB 跳转 / 重开 32.415 秒。未确认片尾 seek 退出重读可续播，已确认的观看状态不会被随后未确认 seek 清除。结果 `.build/results/AetherFilm-final-bridge-full-20261003-0038.xcresult`、日志 `.build/final-bridge-full-playback.log`，xcresult runtimeWarnings 为空。之前旧 wrapper 和诊断原型结果各自保留，不替代本轮正式结果。

同实现的 macOS Debug App / 测试包、arm64 + x86_64 Release 与 iOS Simulator 双架构测试产品、Apple Development iOS archive 构建均通过，最低版本均保持 26.0。桥接类在 App 中定义一次，测试包复用 App 的定义。`.build/FinalBridgeMacBuildEvidence/review.json`、`.build/final-bridge-symbol-link-proof.json` 及 `.build/final-bridge-device-archive.log` 记录具体边界。本地构建采用明确记录的固定 VLCKit 二进制镜像，只有复制工程 / 包的两个 manifest 改为同一规范路径，实现字节与正式仓库一致，见 `.build/final-bridge-source-inventory.json`；正式 manifest 保留官方远程 revision。随后 `e4d7ff0` CI 的远程图三个平台构建及 29 项运行通过，但共享 job 失败，整轮并未通过。

同一正式 App 的完整 UI 已执行：`.build/results/AetherFilm-final-bridge-ui-20261003-0040.xcresult` **18 passed、0 failed、1 opt-in skipped，263.801 秒**。减少透明度须显式启用专项，正确配置的 `.build/results/AetherFilm-final-bridge-reduced-transparency-20261003-0047-v2.xcresult` **1 passed、0 failed、0 skipped，20.192 秒**，实际系统设置和应用截图均已审核。0045 的旧 target 配置错误所致跳过保留在同名 xcresult，不当作通过。19 个场景分别实跑，22 张原始截图已审核，实际安装 App 的 69 文件与本轮正式构建逐一字节相同，见 `.build/FinalBridgeUIEvidence/review.json`。外观 / 字号 / 减少透明度恢复记录保留；本轮不宣称全应用最大字号布局、真实 VoiceOver 朗读、macOS GUI 或物理设备验收。

正式源码 `e4d7ff0f8e91e99cec13c6bca66c60dda795ad3a` 的 GitHub CI `37083136280` **整轮 failed**：platform job 的 macOS build-for-testing、iOS Simulator build-for-testing、iOS device build 均通过，iPhone Air / iOS 27.0 正式 **29 / 29、0 failures、0 skipped**，case 时间合计 114.903 秒、suite elapsed 117.107 秒，runtimeWarnings 为空；shared job 为 **34 / 41、7 failures、0 skipped**。六项为 BSD socket receive EAGAIN，另一个并发停滞协议用例耗时 8.162 秒超过原 5 秒断言。原日志、精确 artifact 与审核 `.build/CIe4d7ff0Evidence/review.json` 保留，不把 platform 绿色解释为整轮 CI 绿色。

窄修仅将 `SMBReadFailureTests.swift`、`SMBStreamingServerTests.swift` 的阻塞 socket 辅助及 await 调用改为独立 concurrent GCD queue / continuation，避免占用 Swift cooperative executor；生产服务未改。所有断言、原 3 秒收包超时和 5 秒停滞期限保持不变，未增加过滤或串行化。修改后完整隔离 SMB2 共享回归 **41 / 41、0 failures、0 skipped**（Sources 28，2.115 秒；Library 4，0.005 秒；Domain 9，0.004 秒），证据 `.build/SMBSocketQueueFixEvidence/review.json`。旧实现阻塞 detached Swift task 的路径已确认，分组延迟支持 executor 干扰，但没有 CI 线程追踪证明这是唯一根因；下一提交 CI 待验证，不将本地通过替代远程结果。

新 iOS 归档 `.build/Archives/AetherFilm-iOS-0.1.0-confirmed-eof.xcarchive` 独立检查 **57 / 57 通过**：最低 26.0、iPhone / iPad、三个 arm64 Mach-O、实际严格签名 / 同 team / provisioning、图标、4 份 license 与 SOURCE / notice 共 6 份资源、无测试 / 样片。68 个编译源与资源哈希和正式 / 冻结工程一致；实际 ObjC class / metaclass metadata 与匹配 UUID 的 dSYM 类符号、三 typed callback selectors 存在，旧 diagnostic getter 不存在。证据 `.build/ReleaseEvidence/ios-archive-inspection-confirmed-eof-system-trust.json`；初次沙箱证书信任失败记录保留，沙箱外只读信任核验通过。该产物为 Apple Development、`get-task-allow=true`，不是 TestFlight / 公开分发导出，未安装或启动真机。

`e4d7ff0` 的完整 App / 修改 wrapper 对应源码候选已独立分阶段核验：`.build/CorrespondingSourceCandidates/e4d7ff0-51b82e86/stage-review.json`、`relink-review.json`、`archive-review.json`。源码清单与归档通过；隔离修改一个 wrapper 文件后，macOS 基线 / 修改版各两个架构（arm64、x86_64）实际重新链接，修改版双架构有 marker、基线无 marker，最低版本保持 26.0；CLI 执行返回该修改的 marker。未执行 iOS 重新链接或 App GUI。此证据不等于完整 libVLC 引擎重建、App 图形播放或分发验收。候选未发布；下一最终提交仍需新的独立源码归档及未变生产实现 / 构建产物的哈希绑定，不能将早期依赖源码输入包当作完整同提交源码。

磁盘中的 c790607 DMG 为旧候选，VM 54 项只认证旧 5e12be2 包。当前源码尚无新的签名 / 公证 DMG，也未做新包安装、首启 / 播放或公开下载。macOS VM 图形验收仍需用户登录，真实 iPhone 仍锁定；未更改登录、安全设置或账户。新提交 CI、最终源码资产 / 二进制绑定、VM GUI、真机安装 / 播放、GitHub tag / release 和官网上线均未完成。
