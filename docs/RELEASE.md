> 2026-10-08 普通候选第二轮已完成：macOS 恢复播放时同步最新意图与当前底层状态，处理取消尚未生效的暂停、因而不会再产生 playing 回调的情况。两端普通测试构建 exit0；远程 Mac 完整 62/0/0、iOS 完整 70/0/1（唯一跳过为私人 NAS 启动器），已编译用例身份逐项匹配原 xcresult，runtime warnings 均空、原生崩溃 0 / unreadable 0。实际加载普通 Native9 候选，Mac Main Thread Checker 保留；上一轮快速暂停恢复的失败与原断言 / 期限保持。证据：候选目录的 `mac-ordinary-full-r2-review.json`、`ios-ordinary-full-r2-review.json`、两端运行时映射、原日志和原生崩溃记录。
>
> 打包检查发现初轮 wrapper 模板中的 `libvlc_version.h` 缺少实际核心生成的 ABI 宏；原包保留，第二轮使用各平台核心生成的头文件重新组装，三个二进制字节保持原样。全部公开头文件（Mac 48、iOS 43）及每平台 315 个公开 libVLC 导出名称与 Native8 基线一致；AppleDouble 旁文件通过 magic 分类，仅作为文件元数据，不计作 C 头文件。冻结桥接 22 份生成源码 / 23 份固定输入及原 patch 校验通过，实际 macOS / iPhone / Simulator ARM64 回调消费者均编译链接 exit0，最低系统 26.0、ARC、单一二进制组件与自有播放器类均验证。该证据是明确本地依赖镜像验证，不等于未经修改的正式远程消费或完整 CI。证据：`normal-native9-generated-version-header-packaging-r2.json`、`normal-native9-public-compatibility-r2.json`、`Native9FrozenConsumers-r2/consumer-proof.json`。当前正式依赖仍 Native8；完整普通 CI、实际兼容恢复、设备 / 手动验收与分发仍未闭合，v0.1.1 继续为草稿。

> 2026-10-08 普通 Native9 私有候选：Mac / Simulator / Device 三份完整核心和六个 wrapper 目标均实际 exit0，三个最终 ARM64 框架最低系统为 26.0，无 ASAN 运行库依赖。三 slice XCFramework 已组装、压缩并重新解压核对二进制 SHA，私有 zip SHA256 为 `05ded3d3244e3d9530d3287c8d2377fc477598c322dd2346d3338ae2ed08e0ce`。38 份私有源码扩展文件逐项大小 / SHA 核对通过；该扩展仍依赖固定的基础源码材料，不是完整便携重建认证，当前公开依赖仍为 Native8。
>
> 当前源码的普通 iOS 完整回归实际 exit0：70 通过 / 0 失败 / 1 私人 NAS 条件跳过；全部 71 个已编译用例身份与 xcresult 一致，runtime warnings 空，原生崩溃 0 / unreadable 0。已确认运行时加载普通候选框架、未加载 ASAN，原断言与期限保持。远程 Mac 独立 QA App 保留 sandbox / Main Thread Checker 和原 App、测试代码段，完整 62 用例已启动，实际进程加载候选且 Main Thread Checker 存在；其终态为 exit65、61 通过 / 1 失败 / 0 跳过，runtime warnings 空，失败为快速暂停恢复：底层持续输出和推进时间，应用 isPlaying 却未恢复；原失败保留，已补充 macOS play() 的当前状态同步，新一轮两端普通测试构建正在运行，尚未认证该修正。完整普通 CI、实际兼容恢复、物理设备、UI / 听音 / VoiceOver、正式安装升级和公开分发尚未闭合，v0.1.1 仍为草稿。
>
> 证据：`.build/P0Optimization20261006/deferred-pause-cancel-candidate-r1/` 中 `ios-ordinary-full-r1-review.json`、运行时映射、各平台 linked-framework review、`native9-private-archive-r1.json`、`native9-private-archive-extraction-r1.json`、`native9-private-source-extension-r1.json`；远程 `/Users/chenxu/AetherFilmQA/Native9Ordinary-20261008-r1/` 的原日志与运行时映射。

> 2026-10-08 普通 Mac 核心恢复构建 exit0，完整静态归档已生成；Simulator 核心也 exit0，Device 核心已接续。普通 Mac 两个 wrapper 目标编译链接均 exit0，实际最终 Mach-O 的 302 个插件入口加独立 core 入口与基线一致，315 个公开 libVLC 导出名称与基线一致，最低 macOS 26.0，无 ASAN 符号或运行库引用。原静态归档的 Apple nm 检查因无法解析部分 Rust LLVM 元数据失败，未声明该检查通过；最终链接产品采用全体已定义符号检查（插件是局部 t 符号）及独立公开 libVLC 导出检查。证据：候选目录的 normal-mac-linked-framework-review.json、普通构建日志及 outcome。普通 App 播放 / 完整 CI / 设备 / 分发仍未通过，v0.1.1 继续为草稿。

> 2026-10-08 普通引擎构建记录：Mac 初轮在 contrib 阶段实际退出 1，原因是独立 Cargo 目录缺少 cargo-capi；原日志和 outcome 保留。已核对现有 cargo-c 0.10.9+cargo-0.85.0 及四个工具 SHA，复制到自有缓存后，在相同源码 / 输出目录继续构建并写独立 build-r2.log / outcome-r2.json。私有候选的移动端构建入口增加工具版本 / SHA 预检和自有缓存复制，两个移动端计划再次通过，等待 Mac 终态。该工具修复未修改全局安装或当前公开依赖。
>
> 时钟语义进一步核对：timer.c 对失效来源的首条时钟设置 VLC_TICK_MAX，仅禁用插值，不等于 input 进入暂停。候选片尾 5 轮均无实际暂停事件，首条运行时钟约 11.38 秒；CI 片尾的 11.812464 初始化点不能作为延后暂停根因证据。SMB CI 失败另有实际 paused-state 回调，仍需独立定位。证据：候选目录的 first-clock-sentinel-review.json、cargo-capi-tool-copy-review.json 和普通构建原始记录。普通引擎、完整 CI 和最终发布尚未完成。

> 2026-10-08 延后暂停取消候选的实际验证：原生 CLI 使用相同已固定 SHA 的 HTTP 视频、dummy 音频和关闭视频输出，原引擎在缓冲期间的恢复请求之后仍进入暂停（时钟 1 微秒），独立候选持续播放至约 6.6 秒，均 exit0 / 无 ASAN 错误。该结果证明原生控制请求缺口，不证明两项 CI 时钟越界的统一根因，也不替代听音或画面验收。Mac / Simulator 的两份改动组件共四次编译及四个诊断 wrapper 目标成功，最小版本仍为 26.0；其余归档成员逐项字节相同。
>
> 当前源码 App 的原引擎对照四用例各 5 轮共 20/20 通过；首轮因 XCTest 优先加载测试产物目录中的旧框架而被明确保留为对照，未计为候选验收。修正两处框架副本后的候选轮实际加载已通过 lsof 路径 / 哈希核对，ASAN 保留，原片尾跳转、SMB 连续跳转、快速暂停恢复及迟到暂停事件各 5 轮共 20/20 通过，exit0、runtime warnings 空、原生崩溃 0 / unreadable 0。未改变原断言和期限。证据：`.build/P0Optimization20261006/deferred-pause-cancel-candidate-r1/`。普通 Mac 引擎已开始独立构建，Simulator / iPhone 的独立源码和 SDK / Rust / 14 份 pin 预检通过并排队串行构建；原 Native8 发布 pin 和冻结桥接未改；完整普通 CI、实际兼容恢复、设备、UI 和最终分发门禁仍未通过，v0.1.1 保持草稿。

> 2026-10-08 最新普通 CI 仍未通过：[37651250092](https://github.com/bcblr1993/AetherFilm/actions/runs/37651250092)，源码 `8b8b19e`。Mac 原 62 项全部通过，iOS 为 68 通过 / 2 失败 / 1 私有 NAS 条件跳过，runtime warnings 均为空。失败为 1.5 倍片尾跳转和 SMB 连续跳转；原生首个运行时钟已越过原目标窗口，不能由本地通过推断 CI 问题已修复。原始产物与附件：`.build/P0Optimization20261006/ci-notification-pool-source-order-r1/`。
>
> 同源码的两个失败用例本地各重复 5 轮，共 10 次通过，命令 exit0；这是未复现，保留 CI 失败门禁。另已核对 Native8 的 13 份源文件 pin，并准备独立的“取消延后暂停”原生控制候选；隔离控制检查复现原分支会忽略缓冲期间的恢复请求。该候选尚未链接到 App，也未证明时钟越界根因。证据：`ci-failure-reproduction-ios-r1-review.json`、`deferred-pause-cancel-candidate-r1/review.json`。v0.1.1 仍为草稿，真机、完整 UI、听音、VoiceOver、实际兼容恢复与最终安装 / 分发门禁继续保留。

> 2026-10-08 原播放回归与桥接消费者完成：Mac原62项身份匹配并全部通过；iOS原71项身份匹配，70通过 / 0失败 / 1私有NAS条件跳过，exit0，runtime warnings为空。通知池22份源已冻结并再次精确生成；Mac / iPhone / Simulator三个arm64实际消费者编译链接exit0、目标26.0，来源见Provenance/consumer-build-review.json。开发签名iPhone测试构建也成功，但设备实时详情仍为Developer Mode disabled，真机验收未通过。CI / 完整UI / 听音 / VoiceOver / 兼容恢复 / 最终分发等门禁继续保留，发布仍为草稿。

> 2026-10-08 完整远程Mac回归：同一回调顺序 / 通知池源码候选原62项全部通过 / 0失败 / 0跳过，原case身份集合核对通过，原Main Thread Checker日志干净；Xcode27读取原xcresult runtime warnings为空，原生崩溃0 / unreadable0，严格签名复查通过。测试打印 TEST EXECUTE SUCCEEDED；Xcode26报告缺少runtimeWarnings字段使测试结束后的自有报告脚本exit1，原测试命令exit未持久化，保留该报告错误，不重跑或覆盖原结果。自有终态LaunchAgent已bootout0。完整iOS尚在运行，冻结 / 消费者 / 分发门禁未完成。证据：seek-source-order-remote-full-r2/。

> 2026-10-08 回调顺序修复专项：Mac与arm64 iOS测试构建通过。远程Mac保留sandbox / 原Main Thread Checker，原SMB seek-zero20轮及隐私20轮全部通过，exit0，xcresult唯一2通过 / 0失败 / 0跳过、runtime warnings为空；无调试器 / 采样，原断言和期限不变。此前15/20的输入与时钟匹配失败本轮未复现。完整Mac62项正在同一源码隔离产品中执行，完整iOS / 消费者 / 真机与分发门禁尚未完成；发布仍为草稿。证据：seek-source-order-remote-r1/及seek-source-order-{mac,ios}-build-r2.log。

> 2026-10-08 断言解读更正：原 EOFPlaybackTests.swift:1568（新增诊断后1591）实际断言为 matchedInputs 非空，之前将其解释为 isSeeking 瞬变有误。原结果仍为 Mac 61通过 / 1失败；最新远程原 seek-zero 20轮为5通过 / 15失败，隐私20轮通过，isSeeking断言20轮全部通过。第1轮原始时间线显示运行时钟 callback149 / delivery150，输入 callback151 / delivery152，随后提示在153清除；下一个时钟callback154尚未到达，因此输入不能匹配当前运行时钟。证据保留于 seek-callback-truth-remote-r1-attachments/，修复候选补充实际回调顺序，原验收条件与期限保持不变，发布仍为草稿。

> 恢复原检查器后的通知池候选结果：远程macOS27.0.1原停止换片20 / 20通过，隐私控制20 / 20通过，exit0，原xcresult唯一2项通过 / 0失败 / 0跳过、runtime warnings为空；未附加调试器、未采样或放宽原断言 / 期限。完整本机Mac原62项为61通过 / 1失败 / 0跳过，runtime warnings为空、原生崩溃0 / unreadable0、清理exit0；停止换片及第二次预热本轮通过，唯一剩余失败为SMB回零提示清除时当前运行时钟对应的输入证据为空（EOFPlaybackTests.swift:1568；原解读已更正），不认证发布。完整运行开始后曾观察到另一项目模拟器测试进程51318，保留该并发环境限制，不中断其他任务。通知池源候选尚未冻结，三平台消费者 / 完整iOS / 独立SMB状态修复及分发仍待验证。证据：`notification-pool-remote-stop-mtc-r2/`、`notification-pool-full-mac-r2-{summary,review}.json`及原附件。

> 通知池修复候选进度：Mac与arm64 iOS测试构建均通过；iOS generic首轮误选组件不含的x86_64，exit65，失败记录保留，明确arm64后的r2成功。远程候选停止换片20轮与隐私20轮均通过、未附加调试器，但随后核对发现新build-for-testing默认缺少原Main Thread Checker，因此不认证该轮完成原门禁。完整Mac r1也在启动前被原检查器门禁拦截，exit2 / 实际0项；现已按历史原xctestrun恢复检查器注入，不改变代码段、权限、断言或期限。远程RunMTC-r2重新执行原20轮，本机完整Mac r2执行原62项，均仍待结果；frozenApproved保持false。历史a7cecef本机排队对照终态20+20通过，只证明间歇失败本轮未复现，不覆盖远程原第6轮死锁。

> 远程macOS27.0.1的新现场已确认通知释放重入计时锁：原停止换片前5轮通过，第6轮原12秒预热失败，随后tearDown挂起并被原120秒期限终止；20轮隐私控制通过。失败后LLDB读取到完整链：UpdateTimerEvent → HandleWatchTimeDiscontinuity → autoreleasePoolPop → NSConcreteNotification dealloc → 播放器dealloc → unwatch_time → RemoveTimer → vlc_mutex_lock；固定源码确认回调持有timer.lock且RemoveTimer重取该锁。调试器exit0且已detach；未取得对象指针，不推断第二次预热CoreAudio锁的完整关联。新候选仅在原discontinuity handleEvent块内加临时对象释放池，保留原调度与releaseQueue；两个独立生成的22份源码与安装候选一致，新增受控autoreleasing通知实验10组基线 / 10组内层pool均确认预期析构线程。候选尚未完成编译 / 实际播放回归，frozenApproved=false，公开版仍为v0.1.0。证据：`remote-isolated-reopen-lldb-r1/native-deadlock-review.json`、原LLDB / xcresult及`event-notification-autoreleasing-control-r1/`。

> 停止换片重复诊断：原用例要求20轮，实际前8轮通过，第9轮第二次本地预热原12秒期限内画音解码输出为0；其后tearDown的FilmPlayer.stop原生释放挂起，被原120秒执行期限终止。20轮隐私控制通过，原断言与期限不变。样本、反汇编与对象布局确认主线程在.cxx_destruct+164释放偏移144的_audio（VLCAudio），触发原生vlc_player_Delete等待；回调线程在HandleWatchTimeDiscontinuity的通知释放路径等待，具体锁环未证明。固定版事件处理器的Foundation独立控制和Swift通知桥接控制均未复现“通知延迟释放导致回调线程析构”猜测，不据此修改释放语义。下一轮原用例诊断已排队，保持原独占门禁，仅在原预热断言失败后附加LLDB；附加后的运行只作为诊断，不认证普通发布验收。证据：`mac-isolated-reopen-sampled-r1/review.json`、两个`event-notification-*-control-r1/review.json`及`mac-isolated-reopen-lldb-r1/`。v0.1.1仍是草稿。

> 本机macOS27新增对照：原签名测试App及Developer ID测试副本均在系统沙盒初始化、XCTest连接前挂起，exit65 / 实际用例0。元数据和只读远程屏幕确认旧容器签名归属与新版本身份不同，系统显示访问旧版本数据的“仍要打开”许可，已请求用户确认，未批准、未关闭沙盒或修改容器。独立QA标识的测试副本保留原可执行代码段、权限、全部原用例与期限，实际完整运行60通过 / 2失败 / 0跳过，runtime warnings为空。失败为第二次本地预热（解码与画音0、缓冲完成但未记录到解码等待结束），以及SMB回零时跳转提示与底层请求状态不一致。原失败及附件保留；本轮不能由此前CI通过认证发布。证据：`mac-isolated-container-full-r1-{summary,review}.json`、原xcresult / 附件、`sandbox-container-identity-startup-review.json`与两机进程采样。

> 最新完整CI（2026-10-07）：[CI37631587164](https://github.com/bcblr1993/AetherFilm/actions/runs/37631587164) @a7cecef三任务全部通过。原xcresult核对Mac26.6.2为62通过 / 0失败 / 0跳过，原生崩溃0、runtime warnings为空、清理exit0；iOS27 / iPhone Air / 24A434为70通过 / 0失败 / 1私有NAS条件跳过，runtime warnings为空。附件实际导出并核对Mac85份、iOS92份；解码计数与源缓冲 / 解码等待白名单捕获真实数值。此前间歇失败本轮未复现，不据此认证根因修复。当前提交本机完整iOS也为70 / 0 / 1。新build4候选已上传Release草稿独立附件，SHA256为`4d4aa4be824248c08f05104f2a7d53dfaf692c6c029e7f09065f352717385916`，服务器digest与本地一致；旧build3附件保留且明确标识。完整Mac UI、实际兼容恢复多轨、物理iPhone播放、听音 / VoiceOver、安装播放 / 升级及公开分发仍待验收，v0.1.1尚未公开。证据：`ci-buffer-wait-audio-{mac,ios}-r1/`、`buffer-wait-audio-full-ios-r1-review.json`及`release-build4-draft-asset-upload-r1.json`。

> 历史普通CI门禁（6f00ce2）：[CI37625813841](https://github.com/bcblr1993/AetherFilm/actions/runs/37625813841) 整体失败，共享通过；Mac61通过 / 1失败 / 0跳过，原生崩溃0、runtime warnings为空。停止换片用例在第二次本地长视频预热失败，12秒期限结束仍画音输出0、正常时钟1微秒附近，尚未执行第二次换片；未认证该路径根因。iOS68通过 / 2失败 / 1私有NAS跳过，runtime warnings为空，失败为长GOP2倍和1.5倍片尾跳转的新鲜目标输出：首个正常点已越过原目标窗口，音频原始有界附件最大defer约0.562 / 0.875秒，没有复现5秒defer，不能将所有间歇失败归为同因。原xcresult / 附件保留于 `ci-watched-tail-audio-{mac,ios}-r1/`。原断言和期限不变；新候选仅补充解码计数、现有音频时序与源缓冲 / 解码等待的数值白名单，已完成两端测试构建与iOS专项验证；CI仍待执行。

新增源缓冲 / 解码等待诊断已验证：两端普通生产框架测试构建通过；iPhone Air / iOS27.0 / 24A434专项5个原用例各3轮，实际15通过 / 0失败 / 0跳过，runtime warnings为空。12份数值音频附件实际读取，捕获30次源缓冲与30次解码等待，最大解码等待149毫秒，证明严格上下文白名单能够捕获真实原生事件；未复现CI失败，不认证根因修复。原断言、期限和目标窗口不变，不留存原始消息、路径或凭据。证据：`buffer-wait-audio-focused-r1.xcresult`、对应summary / review及附件；安装检查：`release-build4-source6f-remote-install-r1.json`。

本机新建与CI一致的iPhone Air / iOS27.0 / 24A434，原完整播放实际70通过 / 0失败 / 1私有NAS条件跳过，未复现CI失败。匹配6f00ce2的build4来源说明资源已重新构建并签名公证，DMG SHA256 `4d4aa4be824248c08f05104f2a7d53dfaf692c6c029e7f09065f352717385916`，严格签名、票据、Gatekeeper及只读挂载核对通过；iOS新签名归档来源说明字节一致。新精确候选已在远程Mac mini独立目录安装，版本、严格签名、票据与Gatekeeper检查通过；实际安装播放和公开下载仍未验收。Mac直接诊断运行exit65 / 实际0项、XCTest建立连接前挂起370.382秒；规范Aqua首轮exit2 / 实际0项，原排他门禁发现两组实际运行的AetherScreens测试，未绕过或停止其他任务。

> 新音频诊断已验证：普通生产框架的 Mac / iOS build-for-testing 均exit0；两个原已看保留用例及既有隐私 / 有界诊断控制各3轮，原日志实际9次通过，xcresult按唯一用例记3通过 / 0失败 / 0跳过，runtime warnings为空。6份新增数值音频附件实际导出读取；首次原生正常时钟的旧CI证据为seek后5.69秒 / 10.184秒，已排除marker后才派送的旧source回调。本机未复现该CI失败，不认证根因修复。首次调用因误用不存在的venv路径exit127 / 实际0项，原日志保留；改用已存在的P0 venv后完成。证据：`watched-tail-audio-focused-r2-{summary,review}.json`及原xcresult / 附件。

> 当前普通CI门禁：125a2ad 的 [CI37623016669](https://github.com/bcblr1993/AetherFilm/actions/runs/37623016669) 已整体失败。Mac62通过 / 0失败 / 0跳过；iOS69通过 / 1失败 / 1私有NAS条件跳过，实际身份71，两端runtime warnings为空。唯一失败是 `testPriorWatchedStateSurvivesRealTailReadFailure` 在注入读错前未达到原6秒held-tail复合阶段：真实新增画音存在，最终正常时钟10.486秒、原输入约10.392秒，未到片尾门；源仍挂起、validator0、ended0，未由此证明已看状态保存错误或原生音频根因。原断言和期限不变，原xcresult及附件保留于 `ci-lifecycle-build4-ios-r1/`。新诊断仅把已有数值白名单音频时序附到这两个原已看保留用例；当前完整修复和发布门禁仍未完成。build4公证候选保留，尚未公开；后续源码补充了随包来源说明日期，最终分发须重新匹配该资源。

> build4 分发候选已实际完成：Mac App / DMG 公证均 Accepted，票据、严格签名与 Gatekeeper 全部通过。只读挂载确认卷名 AetherFilm、build4 及 App / Applications / Notices / 安装说明；DMG SHA256 `a644996bfc2efc8d8e0e6ce94282aa943294063c39b2242d9a4c5a0b55cb2230`，30,758,771 字节。远程 Mac mini 独立目录安装后版本、票据、严格签名与 Gatekeeper 通过；不认证实际播放。Mac 普通 CI37623016669 原 xcresult 实际62通过 / 0失败 / 0跳过、原生崩溃0、runtime warnings为空，79份附件及8份停止换片命令快照已核对。iOS 普通 CI 仍运行，签名归档不替代真机验收。证据：`release-build4-dmg-r3-review.json`、`release-build4-remote-install-r1.json`、`ci-lifecycle-build4-mac-r1/`。

> build4 分发进度：125a2ad 的普通 Mac Release 与 iOS 签名归档均构建成功，版本与快照类已核对，未链接 ASAN。CI37623016669 运行中。两次 App 公证 Accepted，DMG 等待出现连接超时；服务实际收到请求且仍 In Progress，不能将超时记为请求失败或完成。旧脚本错误收尾删除了两次精确 DMG，现修正为先保存提交回执、失败时保留精确签名 App / DMG。实际函数的失败控制保留原 exit73、回执和字节，未认证服务公证。新版候选仍在打包，当前无新公开下载。

> 当前源码候选：v0.1.1 / build4，包含快照生命周期修复；以下6b17364 CI为修复前最近一次普通CI失败记录。新提交的普通CI与新安装包验收尚待完成。

> 当前发布门禁（2026-10-07）：提交 `6b17364` 的 [CI37607953659](https://github.com/bcblr1993/AetherFilm/actions/runs/37607953659) 整体失败。Mac实际62通过 / 0失败 / 0跳过，原生崩溃采集0条；iOS实际69通过 / 1失败 / 1私有NAS条件跳过。唯一失败为真实SMB第二轮打开后跳转62秒：首次运行正常时钟在提交后4.65秒到达64.961秒，已经越过原62.2～64秒目标窗口，随后时钟继续推进。不能将本轮解释为固定时钟停滞，也不能记为根因修复。原断言和期限不变；证据为 `.build/P0Optimization20261006/ci-stop-change-phase-{ios-seek,mac}-review.json` 及原xcresult。

Mac本机原生ASAN停止换片20轮专项实际执行14轮：13通过 / 1原生abort失败，exit65。匹配的诊断框架UUID与ASAN已由进程采样证明加载；第14轮调用栈从AetherHandleMediaStopping进入播放器析构、VLCAudio释放、vlc_player_Delete和vlc_join，线程join错误11对应Darwin EDEADLK。停止回调直接读取弱播放器以复制数值快照的路径已识别；该证据不证明旧空timer链表SIGSEGV具有相同根因。新候选将数值快照改为事件处理器持有的独立对象，原生回调不再为快照读取提升弱播放器；固定输入不变，补丁 / 哈希可复现，frozenApproved已设为true，第二次独立生成与已测试源码22文件逐字节一致，两端ASAN测试构建均exit0，实际二进制快照类及独立测试包严格签名已核对；相同Mac原用例20轮ASAN回归实际20通过 / 0失败 / 0跳过，原生崩溃及ASAN错误0条、runtime warnings为空，160份命令阶段附件已核对（总附件200）。该已捕获的停止快照生命周期路径已通过本轮回归；旧空timer链表SIGSEGV相同根因仍未证明。修复候选的完整iOS ASAN播放实际70通过 / 0失败 / 1私有NAS条件跳过，runtime warnings为空、ASAN错误0条，86份附件已导出（`bridge-lifecycle-ios-full-asan-r1`）。完整Mac首轮被原排他会话门禁拦截，exit2、实际0项；确认无冲突后第二轮完整执行62通过 / 0失败 / 0跳过，exit0，runtime warnings为空，ASAN错误与原生崩溃0条，79份附件及清理exit0已核对（`bridge-lifecycle-mac-full-asan-r2`）。生产Native8的Mac / iOS真机 / iOS模拟器三平台消费者编译链接均exit0，ARC、单一artifact、命名空间及最低26版本已核对（`bridge-lifecycle-consumer-verification-r2`）；仅证明编译链接。非诊断完整CI及真机 / 分发门禁仍待完成。证据为 `bridge-lifecycle-mac-stop-asan-r1/` 原xcresult、summary / review及附件。原结果、原生崩溃和failure-review保留于 `native-mac-core-asan-stop-local-r1/`。


生产Native8框架对照同样以XCTest建立连接前挂起结束（exit65，实际播放用例0项，594.934秒）；非ASAN、远程Xcode26.5构建、同一6b17364源码。该启动失败并非只发生在ASAN诊断框架下，具体会话原因仍未确认。原xcresult及review保留于 `native-core-stock26-5-control-remote-r1/` 和 `native-core-stock26-5-control-r1-review.json`；不认证播放或崩溃修复。iOS模拟器独立ASAN诊断内核已完成：中断后的原日志到达成功终点且完整归档存在，原退出码未收取；保留原归档后同一独立缓存的增量构建实际exit0。302模块入口与插件归档一致，timer对象含ASAN检查，诊断框架两目标exit0、arm64 / min26 / SDK27通过。独立App进程采样确认实际加载框架UUID DD43B4F0-D74E-3408-A0CD-40E0646BE5D7及ASAN。完整原播放测试实际70通过 / 0失败 / 1私有NAS条件跳过，runtime warnings为空，播放日志ASAN错误0条；SMB两轮20次跳转、停止换片及8份命令阶段附件保留。本轮未复现故障，不认证历史间歇故障根因修复或真机 / 发布验收。证据为 `native-sim-core-asan-playback-r2.xcresult`、对应summary / review及附件。


诊断内核和VLCKit框架已实际构建成功，302个模块入口与插件归档一致，故障相关timer目标含ASAN引用。远程进程已确认加载诊断框架和ASAN。首轮XCTest建立连接前挂起，exit65、实际播放用例0项，原结果保留于 `native-core-stop-asan-remote-r1/`。匹配远程Xcode26.5的当前源码测试包已构建成功，215个受保护源码文件与提交快照一致；第二轮也以相同的XCTest建立连接前挂起结束，exit65、实际播放用例0项。原结果保留于 `native-core-stop-asan26-5-remote-r1/`；工具链匹配未解决启动问题，不认证原生崩溃修复或发布验收。独立诊断产物未替换生产依赖。

v0.1.1仍为草稿。现有build3签名包不包含字幕截止时间及快照生命周期修复；新版重新打包、真机播放、完整Mac UI / 听音 / VoiceOver及实际兼容恢复的多轨验收仍未完成。官网新Logo与候选说明已上线，公开下载保持v0.1.0。

> 历史发布门禁（2026-10-07）：[CI37606217593](https://github.com/bcblr1993/AetherFilm/actions/runs/37606217593) @ `ddb16f1` 整体失败。Mac实际61通过 / 1原生SIGSEGV失败 / 0跳过，失败为 `testStopAndChangeFilmCancelOldRealSeekCallbacksAndTimers`；UUID匹配的VLCKit故障指令为 `vlc_player_UpdateTimerEvent+140` 的停止事件监听链表读取，空地址8访问，根因未确认。iOS实际69通过 / 1失败 / 1私有NAS条件跳过；暂停片尾跳转第5.24秒仍新增视频、音频与正常时钟，未满足原最后一秒稳定断言。字幕重试和SMB连续跳转本轮通过，不覆盖历史失败。原xcresult、原生崩溃及匹配反汇编保留于 `.build/P0Optimization20261006/ci-subtitle-deadline-*`。

新增仅测试使用的崩溃前快照：在原StopAndChangeFilm的4个命令阶段保存已有只读观察与原生时钟，避免原生退出绕过tearDown；不保存URL或原始日志，原断言、命令及期限不变。两端测试构建通过，本机StopAndChangeFilm与暂停片尾各3轮，实际6通过 / 0失败 / 0跳过，24份命令前快照已独立导出核对。未复现CI故障，不认证根因修复。证据为 `stop-change-paused-focused-r1.xcresult`、对应summary / review及附件。v0.1.1仍为草稿，build3不含字幕截止修复；新包、真机播放、完整Mac UI / 听音 / VoiceOver与恢复多轨验收仍未完成。

> 历史发布门禁（2026-10-07）：[CI37603567466](https://github.com/bcblr1993/AetherFilm/actions/runs/37603567466) @ `11488e3` 整体失败。Mac实际62通过 / 0失败 / 0跳过；iOS实际68通过 / 2失败 / 1私有NAS条件跳过，失败为真实SMB循环跳转到68秒后正常时钟未恢复，以及缺失字幕未在原7秒期限内报可恢复错误。两端runtime warnings为空。此前7acd6a3通过记录仅覆盖该轮执行，不能覆盖本轮失败。

当前修复候选将字幕加载的50次轮询改为原定5秒的真实经过时间预算；新增SMB原生时钟与有界音频数值附件，原断言和期限保持不变。两端测试构建通过；本机专项3个原用例各3轮，实际9通过 / 0失败 / 0跳过。字幕失败后视频继续、重试成功与旧加载器取消均按原用例验证；SMB两轮打开 / 20次跳转 / 关闭停止读取各3轮通过，3份正常时钟和有界音频附件保留。未复现CI的SMB停滞，不认证其根因修复。原始证据为 `.build/P0Optimization20261006/subtitle-deadline-focused-r1.xcresult`、对应summary / review及附件。build3签名包不含这次生产改动，后续需重新打包；v0.1.1仍为草稿。远程iPhone最新检查Developer Mode disabled、tunnel disconnected；真机播放和完整Mac UI / 人工听音 / VoiceOver门禁仍未完成。

> 历史通过记录（2026-10-07）：代码提交 `7acd6a3` 的 [CI37600863876](https://github.com/bcblr1993/AetherFilm/actions/runs/37600863876) 三任务全部通过。Mac26.6.2独立xcresult为62通过 / 0失败 / 0跳过，iOS27为70通过 / 0失败 / 1私有NAS条件跳过；实际用例身份数分别62 / 71，两端runtime warnings为空，Mac原生崩溃报告0条、清理exit0。新增片尾音频诊断已在iOS附件留存，但未复现此前时钟停滞，本轮通过不认证根因修复。v0.1.1 / build3仍为草稿。
本轮诊断压力专项：从干净代码7acd6a3重新构建iOS测试产品，短GOP与长GOP2倍速原片尾用例各20轮，实际40通过 / 0失败 / 0跳过；runtime warnings为空，40份有界音频附件全部保留。未复现旧异常，不认证根因修复；未改断言、时间边界或期限，未把模拟器当真机。原始证据为 `audio-timing-stress-r1.xcresult`、`audio-timing-stress-r1-{summary,review}.json` 及附件。


官网更新已按用户授权公开上线：`aethernative-site` 提交 `5a097e9`，Cloudflare Pages部署 `eb9ac14c-c27b-44dd-bd89-31042cd5e437` 成功；165项测试通过，336页构建与8990站内链接检查通过。线上浏览器已复核中英文产品页、新Logo与候选FAQ，下载入口保持公开v0.1.0。终端HTTP请求403不替代浏览器已见的上线结果；原失败保留。证据：`.build/P0Optimization20261006/website-logo-live-review.json` 及 `website-logo-live-zh.png`。

双音轨 / 内嵌及外挂字幕合成样片的真实SMB两种跳转路径各10次都保持第二音轨与外挂字幕、正常时钟和新音视频输出，但均未实际进入兼容恢复。要求实际恢复的专项原断言失败（各0通过 / 1失败，runtime warnings为空），不能记为恢复验收通过；候选专项和失败保留于 `recovery-track-acceptance-{candidate.swift,review.json}`。远程iPhone再次确认Developer Mode disabled且连接正常，真机播放仍待用户开启后执行。完整Mac UI、人工听音和VoiceOver也仍待验收。

> 上一轮CI记录（2026-10-07）：提交 `cb5b038` 的 [CI37598351828](https://github.com/bcblr1993/AetherFilm/actions/runs/37598351828) 已结束，整体失败。共享Python15项及Swift48项通过 / 8项SMB3条件跳过；Mac26.6.2实际61通过 / 0失败 / 0跳过；iOS27实际68通过 / 1失败 / 1私有NAS条件跳过。唯一失败为短GOP2倍速片尾跳转：跳转后有真实新视频与音频输出及EOS，但正常时钟停留11秒，未满足原时钟连续性门禁。两端runtime warning为空，Mac原生崩溃报告0条；旧失败记录保留，草稿未公开。
本轮补充仅测试使用的音频数值诊断：白名单核对真实AVSampleBuffer源码与函数，附件只保留模块枚举、启动延迟数值和相对时间，首32 / 末224有界记录，保留现有logger；不改变生产播放代码、时钟、原断言或期限。本机原短GOP2倍速片尾与隐私 / 有界控制各3轮通过，实际6次执行、runtime warnings为空。3轮均捕获真实AVSampleBuffer启动事件，本机延迟约40～91ms；尚未复现CI约5秒未来时钟，不能认证根因修复。两端测试构建通过，证据为 `.build/P0Optimization20261006/audio-timing-tail-r1-{summary,review}.json` 及附件。继续完整CI取得失败环境证据，草稿保持。


> 上一轮状态（2026-10-07）：候选 v0.1.1 / build3。提交 5d8b2bc 的 CI37595707384 整体失败：共享通过；Mac26.6.2 实际61通过 / 0失败 / 0跳过；iOS27实际65通过 / 4失败 / 1私有NAS跳过。两端 xcresult runtime warning 为空，Mac原生崩溃采集0条。GitHub Release仍为草稿，未公开发布。

> 2026-10-06的P0 / NAS优化阶段记录保留于 [TEST_MATRIX.md](TEST_MATRIX.md)。旧v0.1.0公开DMG的证据不覆盖新改动；最新候选和验收限制见下方 Current candidate，历史失败不因本轮通过而覆盖。

# Release gates

Target: v0.1.0, macOS-first public distribution; Apple Silicon only and minimum
macOS / iOS 26.0. v0.1.0 macOS release published on GitHub with Developer ID signature,
Apple Notarization Accepted and stapled DMG.

## Current candidate: 2026-10-07 (v0.1.1 / build3)

当前源码 `6b17364` 的完整CI失败（iOS69通过 / 1失败 / 1跳过，Mac62通过）。现有build3分发包不含后续字幕截止时间修复，不能作为当前源码的安装验收证据。当前门禁和诊断限制见文首及 [TEST_MATRIX.md](TEST_MATRIX.md)；下方保留历史候选分发证据。

- 用户选定的3号浅色玻璃A已接入macOS / iOS图标；版本唯一来源为 `Version.xcconfig`，最低系统仍为26.0。
- 提交 `422ba86` 的CI [37588324314](https://github.com/bcblr1993/AetherFilm/actions/runs/37588324314) 三任务全部成功。独立xcresult为Mac26.6.2播放60通过 / 0失败 / 0跳过，iOS27模拟器播放68通过 / 0失败 / 1私有NAS opt-in跳过；两端runtime warnings均为空。此前37584686443与37586192664的片尾失败、共享认证失败及Mac原生崩溃仍保留，重跑成功不认证根因修复。
- 当前DMG `artifacts/AetherFilm-0.1.1-macos-arm64.dmg` SHA256为 `81c762002e3c048fe507afe79429bcf3e396f1255683b529bbc4ead274b80828`。App和DMG公证Accepted、票据验证、严格签名及Gatekeeper通过；只读挂载确认卷名和App / Applications / Notices / 安装说明，远程Mac mini提取的App为build3且签名 / Gatekeeper通过。GitHub草稿资产digest与本地一致；这不等于公开下载或升级验收。
- iOS签名Release归档为 `build/AetherFilm-iOS-0.1.1-build3.xcarchive`。build3已实际安装并启动于用户批准的远程Mac mini连接的iPhone16ProMax / iOS27.0.1；安装启动不等于播放验收，未公开分发iOS。
- 真机首轮请求常用容器、4K HEVC及2倍速长GOP片尾三项原用例，命令exit70、实际0项执行，Xcode明确报告Developer Mode disabled。设备当前paired / available但开发者模式仍disabled；保留失败结果，等待用户在设备设置中开启后重跑，未弱化原断言或期限。
- 当前完整Mac UI、听音、VoiceOver、完整真机及兼容恢复路径的多音轨 / 外挂字幕等仍未闭合。是否先公开macOS并披露风险的范围取舍仍等待用户回复；维持发布草稿。

Evidence: `.build/P0Optimization20261006/` 下 `release-v011-build3-evidence.json`、`release-v011-build3-remote-install.json`、`release-v011-build3-ios-review.json`、`release-v011-build3-device-install.json`、`physical-build3-r1-outcome.json`、`ci-native-diagnostics-{mac,ios}-r1-summary.json`；公证记录 `artifacts/notarization-0.1.1.8k9X7s/`。旧build2候选保留于 `artifacts/candidates-v0.1.1-build2/`。

## Release published: 2026-10-06 (v0.1.0)

v0.1.0 macOS release asset `AetherFilm-0.1.0-macos-arm64.dmg` (SHA256 `20b579a6c089828808149f2eb776aa7536d4eb8d7b62859326721e300a02f51f`)
was signed with Developer ID Application: YanNan Chen (5984KQD4D7), notarized via Apple Notary Service
(profile `AetherRoute-Notary`, status Accepted) and stapled. Downloaded artifact was verified with
`shasum -a 256 -c SHA256SUMS.txt` and Gatekeeper assessment `spctl --assess --type open`.
GitHub release `v0.1.0` published with release notes, compatibility scope and explicit iOS distribution state.
The signed iOS Release archive (`build/AetherFilm-iOS.xcarchive`) was built and validated; iOS distribution
proceeds per developer account conditions.

## Current continuation: 2026-10-06 (tests executed 2026-10-05)

On base `375fc63` with the pre-existing SMB cancellation-fixture barrier,
local shared tests actually passed45 with8 opt-in SMB3 skips; separate encrypted
SMB3 passed8/0/0 and AddressSanitizer SMB integration passed4/0/0. All three
platform build-for-testing targets and the development-signed iOS Device build
passed. Original iOS27 and iOS26.5 Simulator playback each passed65/0/0,
with no runtime warnings;26.5 does not certify exact26.0 or a physical device.
Original playback on
the user-approved remote Mac mini (ARM64, macOS27.0.1, Xcode26.5, SDK26.5)
passed57/0/0 with unchanged assertions, deadlines and Main Thread Checker.
The remote182 protected source/fixture hashes match the snapshot; strict signing
verification and owned fixture / Aqua-agent cleanup passed.

Current Phone and Pad full UI each passed18/0/1; the real system Reduce
Transparency case separately passed1/0/0 on each, restoring the original setting.
The first Mac mini UI run could not initialize because automation mode required
administrator authentication; that zero-case failure is retained. The subsequent
original full19 run completed17 passes,1 failure and1 natural Reduce Transparency
skip, exit65. The sole failure is the unfiltered accessibility description audit
of an empty Disabled system TouchBar. An independent minimal native AppKit
window/button control reproduced the same audit failure (0/1/0); a temporary
SwiftUI TouchBar customization also failed and was reverted. Neither diagnostic
waives the original audit. Actual Mac Reduce Transparency and spoken VoiceOver
acceptance remain open; no audit filtering or weakened assertions were applied.

CI37215169426 remains failed, with real shared/Mac/iOS failures and a native
SMB teardown crash in the iOS4K test. Successful local runs do not certify that
intermittent crash fixed, or rewrite the CI result as a quota problem. Current
physical-iPhone full acceptance, user-NAS/listening/spoken VoiceOver, desktop UI,
minimum macOS runtime, final signed/notarized installation and distribution gates
remain open. The user authorized a source push on2026-10-06; release tags and
App publication are outside this continuation. A source push does not close
these release gates.

Evidence: `.build/Continuation20261005/`, especially `MacMiniPlayback-r2/`,
`MacMiniUI-r1/`, `MacMiniUI-r2/`, `MacMiniUI-native-control-r1/`,
`MacMiniUI-audit-touchbar-r1/`, `iOS-Full-r1.xcresult`, `iOS26-Full-r1.xcresult`, the four Phone/Pad UI bundles,
`SMB3-r1.json` and retained validation logs. Exact counts and limitations are in
`TEST_MATRIX.md`.

## Historical candidate notes: 2026-10-04

The unified Native8 candidate now contains four additional tail regressions;
the original61 iOS /53 Mac assertions and deadlines remain unchanged. Its pure
three-platform native build, six wrapper targets and three-slice assembly passed.
The private final C4 candidate passed physical original3/0/0 and new4/0/0;
eight actual drain-to-stop windows contained no later valid native clock point.
Final unfiltered iOS65 /Mac57, complete UI, signed installation, App publication
and website deployment still require their own evidence.

Preceding source `6100c1c` passed CI37202599510: all three ARM64 platform builds,
Mac26 playback53/0/0 and iOS27 Simulator playback61/0/0. Independent xcresult,
raw-log and expected-case identities agree. Shared tests actually executed
45 passes with8 opt-in SMB3 skips; the five runner unit tests passed. The
separate real encrypted SMB3 gate remains8/0/0. Earlier CI failures are retained.
The split native SwiftUI expressions resolve the SDK26 typechecking failure;
progress saves now join the existing ordered persistence queue before flush.

Public Native7 still has two physical iPhone tail-seek failures (full61:59/2/0).
A private native correction converts only media preroll to system ticks and
preserves caching compensation. It passed the original three physical regression
cases,3/0/0, including half-speed, without changing their assertions or deadlines.
The two new short-GOP tail controls actually returned1/1/0: at2× the last
normal clock11.771539 was below the unchanged new11.8 threshold. The same
short-GOP controls passed2/0/0 on known Native7, so they do not reject the
original long-GOP defect. Independent long-GOP coverage and actual audio drain
are being checked; the short-GOP failure is retained.
The additional AV async-drain candidate passed original3/0/0. Four new
controls returned2/2/0, then3/1/0 after the first upper-bound revision;
the2× long-GOP normal clock12.286767 still exceeded12.26. The real renderer
consumed every queued sample. Independent raw callbacks show that the public
normal clock uses a planned system-time/rate anchor and can lead the physical
sample position; observer period plus filter stride does not establish a
nominal-duration upper bound. A still-unmerged control revision will bound
clock progress by the independently measured monotonic elapsed seek time,
preserving all original61 assertions, fresh callback/output gates, tail lower
bounds, six-second deadline and exactly-once completion. Known Native7 was
correctly rejected by both same-source long-GOP controls,0/2/0. All original
failure records remain. This private numeric diagnostic build is not a
production component; no native completion fix or App release is certified yet.

Native7 fullUI binds preceding source `987ce91`: Phone and Pad18/0/1 each,
Mac17/1/1; actual system Reduce Transparency separately passed1/0/0 on all
three targets with original settings restored. The sole Mac failure is the
unfiltered system Disabled empty TouchBar description audit; no exception is
granted. Final unified-source UI acceptance remains open. User-NAS, audible and
spoken VoiceOver acceptance remain open; exact scope is in `TEST_MATRIX.md`.

The Native7 binary and corresponding source are public in a separate technical
prerelease, with complete anonymous downloads matching length and SHA256.
A full fresh portable source rebuild has not executed. The signed/notarized
Mac candidate and development iOS archive bind `987ce91`, not current source;
new final builds, installed VM / physical-device Release playback, public App
download and website deployment remain open. Host Gatekeeper has a pre-existing
security override and cannot replace Gatekeeper-enabled VM acceptance.

Evidence: `.build/Native7CICommit6100c1cReview20261004-r1/`,
`.build/NativeBufferingPrerollRateActualReadonly20261004-r1/REPORT.json`,
`.build/NativeCoreAudioClockCadenceMobileAcceptance20261004-r1/`, and the
UI / distribution evidence paths in `TEST_MATRIX.md`.

## Historical candidate evidence

2026-10-04 authentication continuation: after the user authenticated UI automation inside the macos27 VM, the same narrow UI candidate passed the actual Reduce Transparency case with1 pass /0 failures /0 skips, exit0. The original absent preference key and false API state were restored. Both earlier runner-initialization timeouts remain retained. This does not replace acceptance of the final unified Native6 source. Evidence: `.build/NativeSMBAXTypeUIExecution20261004-r2/MacReduceReview-r3/`.

Target: v0.1.0. No release has been published.

Latest final combined-source execution (2026-10-04): Native6 r2 SOURCE_READY35707893 passed the original unfiltered full61 on both iOS27 and the owned iOS26.5 Simulator,61/0/0 each, exit0, with original checker dictionaries, strict seals, complete source/product/config/cache guards and original deadlines preserved. The owned26.5 was actually restored to Shutdown. The additional real-SMB control also passed explicit disktrue at qualified output95% → same pending391-byte source failure → diskfalse with valid resume; native stopping reason1 is retained and rejected by the application validator. Mac53/UI19, physical iPhone, Mac26 and distribution still require their own final evidence. Earlier qualification and runtime failures remain preserved. Exact results are at the top of `TEST_MATRIX.md`.

Independent fixes in progress (2026-10-04): the real audio-renderer100ms clock candidate passed the unchanged half-speed function case1/1, with EOS24.568336 seconds, final normal12.072098, real audio/video output and exactly one completion; the original30-second bound and tail assertions remain. The session-owned watched-state correction separately passed10 focused cases on each of iOS26.5 and27. Those original fault runs did not cross an automatic95% checkpoint before failing, so an additional strict SMB integration control is still required to certify that rollback path. The original unified failures below remain preserved, and full combined-source, device and distribution acceptance are still open. See `TEST_MATRIX.md` for the exact artifacts and limitations.

Current narrow UI evidence: the final identifier/native-value and expanded-sheet-height correction passed the original SMB case on all three targets. The unfiltered full19 is17/1/1 on Mac (only the system TouchBar audit fails), and18/0/1 on each mobile simulator. Real system Reduce Transparency separately passed1/1 on both mobile targets with settings restored. The same corrected Mac products encountered two automation-mode initialization timeouts before entering that case; settings were restored and both original infrastructure failures remain. Earlier Native5 Reduce1/1 evidence is retained as history. No final combined-source UI pass or audit waiver is claimed.

The new natural SMB rollback control on iOS26.5 failed its unchanged30-second healthy precondition before fault injection: a genuinely held391-byte tail stopped input at10.43091, below95%, despite the advancing renderer clock. Source/products/checker/signatures and owned simulator restoration passed. This is not rollback-path acceptance; a reachable real-playback control is being prepared without changing the original54 or six persistence controls.

Minimum-system branch evidence (2026-10-04): the same sealed Native5 App passed the complete54 cases on the owned iOS26.5 simulator, zero failures/skips, exit0, with exact source/products/configuration/cache and strict signatures. Its initial Shutdown state was restored. This certifies this simulator/runtime run, not iOS26.0, physical iPhone or macOS26, and does not waive the two actual iOS27 failures below. Evidence: `.build/FinalNative5SimulatorAcceptance20261004-r1/Results-iOS26.5-full54-r1/outcome.json`, SHA `21ce554a…`.

Current combined-source gate (2026-10-04): the final Native5 iOS27 unfiltered54 run actually passed52, failed2 and skipped0, exit65. The exact compiled/runtime case list, original source/products/configuration/cache and strict signatures remained stable. Half-speed EOS arrived within the original timing bounds, but its last normal media clock was11.568169 against the unchanged11.9 tail assertion. A real tail read fault also exposed a previously automatic95% watched mark that was not revoked; existing/manual watched controls passed. Both failures are retained and block release. The earlier independent53/53 and half-speed1/1 results do not certify this combined candidate. Evidence: `.build/FinalNative5SimulatorAcceptance20261004-r1/Results-iOS27-full54-r2/outcome.json`, SHA `9fa71eb6…`.

Current architecture scope (user confirmation, 2026-10-04): macOS releases require Apple Silicon (arm64) and macOS26+. Intel compatibility, Intel builds and universal-Mac packaging are removed from current release gates. Build the App and embedded frameworks for arm64; the DMG is named `AetherFilm-0.1.0-macos-arm64.dmg`. Historical universal-build evidence below remains historical. iOS / iPadOS minimum26 and physical-device acceptance remain required.

Baseline frozen Native4 evidence (2026-10-04): the three ARM64/min26 framework slices and all three App builds passed their build and strict signing checks. Physical iPhone12Pro/iOS27 playback50 was49 passes/1 failure/0 skips; simulator playback50 was48/2/0; Mac playback42 was41/1/0. All physical SMB cases and 4K hardware evidence executed. The waiting-UI fixture allowed its original seek0 target to recover, and the simulator also failed its saved-watched assertion. Mac UI19 was16/2/1, with SMB disclosure interaction and an empty disabled system TouchBar audit issue failing. These original results remain preserved; the corrected combined App requires fresh acceptance. See `TEST_MATRIX.md` for artifacts and precise limitations.

Independent candidate evidence (2026-10-04): the hidden-control view-tree correction passed the unchanged full UI19 on both iPhone and iPad simulators (18 passes / zero failures / one natural skip each), plus a real system Reduce Transparency check on each device with settings restored. The qualified unread seek8 target and confirmed-progress correction passed all53 iOS27 playback cases, including real healthy pre-EOS95% confirmation and preservation of prior/manual watched records. These exact tested source changes are merged. The Native4 four-container smoke passed on an owned iOS26.5 simulator; full minimum-system and combined-source regression remain required. The first SMB identifier-only correction failed its unchanged case during exclusive execution; a native label-click correction is awaiting the user's shared-VM test window.

The half-speed audio timing correction is built into all three Native5 framework slices. Its new functional case actually passed1/1 with zero failures or skips: the12-second clip reached EOS around24.57 seconds,22.056 seconds after early real output readiness, within the independent30-second bound and above the21.202-second lower bound. Real tail audio/video, normal/input time, engine identity and exactly one completion were checked. The test is merged without changing the original53 cases or deadlines; the older60-second measurement is retained separately. Final Native5 playback54 /46, full UI, physical device, distribution and public-download acceptance are pending. The macOS26 CI job is configured and five local runner failure/control tests pass; hosted build/runtime has not executed. The pinned synthetic EOF asset pair preserves byte-range qualification across encoder versions. No App release or gate waiver is claimed.

Latest physical-device execution (2026-10-04): the original native3 unfiltered50 run on the USB iPhone12Pro / iOS27 was39 passes /1 failure /10 SMB bootstrap skips. The four original local seek cases passed. The sole 4K failure was subsequently matched with a precise static-log recognition correction; the unchanged original 4K case passed1/1, exit0, with VideoToolbox selected/accepted-frame evidence and real video/audio output. Strict signatures and source/product guards passed before and after that run. The first full result remains preserved; physical SMB, full UI, audible acceptance, minimum26 runtime and distribution still require evidence. The fixed-cache native IO mechanism control passed24/24 primary expected outcomes and all13 candidate controls, but its no-drain negative hypothesis was disproved and the original runner exit1 is retained. That C correction is not yet built into the App and does not establish recovery of the original App's intermittent held-tail failure. See `TEST_MATRIX.md` for the exact artifacts and limitations.

Latest execution (2026-10-04): the iOS27 ARM64 native3 candidate passed the original four seek cases, including actual new paused preview, with4 passes /0 failures /0 skips. The same sealed App's first unfiltered50-case playback run was49 passes /1 failure /0 skips (formal44 mapping43/1); held-tail seek0 failed its original6-second output gate. Two later single-case runs and one unfiltered50-case run passed, but all three passive samples were NO_STALL / INCONCLUSIVE with different HTTP/cache history; the original failure remains open. The Mac27 VM unfiltered UI19 was11 passes /7 failures /1 natural Reduce Transparency skip; raw logs identify Apex UI interference in four failing cases, separate audit/AX timeouts remain, and exclusive UI acceptance is still required. The corrected native SMB-control click has a newly compiled and signed UI19 product with unchanged App bytes; it has not yet run in the VM. The iPhone baseline core compilation and nm both exited0, with6269 native ARM64/platform2/minimum≤26 members and302 defined modules. The three pause corrections subsequently passed all14 Device object/archive steps, preserving the other6266 full-archive members and839 protected inputs. Both Device wrapper targets then exited0; the actual52874192-byte framework is arm64/platform2/minimum26/SDK27, with302 defined modules, unchanged primary inputs and retained warnings. Signed App and physical-device acceptance remain required. Evidence and precise scope are recorded at the top of `TEST_MATRIX.md`. No release or distribution gate is waived.

Latest isolated Mac paused-preview candidate (2026-10-03): the three native corrections together passed all four original seek-status cases, with0 failures and0 skips. Original assertions, fixtures and6-second deadlines were unchanged. The actual paused seek to8 produced a new input at7.997333 and normal video-clock event at7.966667 with new displayed frames before clearing the UI; an earlier readonly getter at the target did not clear it. Subsequent samples remained paused. Playing rapid seeks and stop/change also passed. All eight object/archive stages and both actual wrapper targets exited0, with raw MTC/background-layer/fixed GL counts0. Root checked the actual execution, original inventories and specific output evidence; independent review additionally read all eight trace/UI attachments in full. Evidence: `.build/SeekPausedPreviewDecoderMacProductsCandidate20261003/Results-mac-strict4-r1/` and `.build/SeekPausedPreviewDecoderMacRuntimeReview20261003/`. This is a Mac27 ARM64 diagnostic result; all paused interleavings, iOS, final App/full UI, minimum26 and distribution remain open. Earlier paused failures and formal36/36,43/1 evidence are retained.

Current formal-source verification (2026-10-03): the same frozen source built both test platforms. The complete Mac run passed36/36 with no failed or skipped cases; the iOS27 run passed43/44 with one active seek0 failure under indefinitely held tail IO and no skips. Exact case lists and unchanged source/product inventories were independently verified in `.build/FormalVerificationFinal36-44IndependentReview/`. Mac retained the original Main Thread Checker settings; its raw log had no fixed MTC / background NSView.layer / OpenGL assertion prints. A matched start2 complete-source seek0 control passed1/1 with real new video/audio and both clock/input rewinds; it does not replace the failing held-source test. The formal SMB3 encrypted group passed8/8 and default shared tests passed45 with8 opt-in skips. These results do not replace real NAS or physical-device acceptance.

The native sample-buffer backend is integrated in formal source. Historical normal Mac windows for ASS / SRT / VTT showed readable Chinese at the first cue, next cue and after a real seek, while missing H.264 clean aperture caused narrow side bars. An isolated aperture patch passed helper tests and the actual Mac arm64 core build. The third wrapper attempt built both targets with exit0; original tool-reader and deployment-target failures remain retained. Its owned-window H.264 / ASS diagnostic then exited0:124 public CM formats had valid320×180 aperture within coded320×192, VT reported hardware=1, and Root reviewed three original PNGs with correct cues and full16:9 picture without the old side bars. Original phase deadlines and complete raw logs were retained. A separate actual rebuild of18 GSM objects and static remerge passed;6544 other objects remain byte identical and all6562 minimum targets are≤26. The corrected archive then passed both fourth-wrapper targets and another real H.264 / ASS three-stage visual run, with Root-reviewed picture/glyphs and hardware=1. These are Mac27 diagnostic results, not final App, all orientations,4K or minimum26 runtime acceptance. App targets remain26. The earlier isolated seek-status candidate built both platforms but failed both paused-preview UI cases on each; rapid seeks and stop/change passed. The latest Mac-only native candidate result is recorded above. Its single new formal held-source control passed with real output, without a core recovery fix, and does not cancel the historical full-suite failure. Full Mac UI products await manual VM Aqua login. The unfiltered accessibility audit retains the empty system TouchBar failure and native baseline reproduction; the rejected filter was not applied. Physical iPhone acceptance, current-source signed package, release tag, public download and website deployment remain open. See `TEST_MATRIX.md` for exact evidence and original failures.

The corrected-archive diagnostic also passed real H.264 / SRT and WebVTT three-stage runs; Root and an independent review checked all six original PNGs for Chinese glyphs, full16:9 picture and first/next/rewound cues. Together with ASS, the current diagnostic has nine reviewed screenshots. A separate readonly public-core-time probe preserved both paused tests and their6-second deadlines: both platforms still failed both cases, and the getter remained at pre-seek time. Display statistics alone do not establish a target preview, so this query has not been used to clear the UI or waive the failures. These diagnostics remain separate from final App and distribution acceptance.

The iOS Simulator arm64 aperture core compiled with exit0 and produced6266 native objects with platform7 and minimum versions≤26; all302 generated module entries are defined. Its original driver exited1 on changed build inputs and retains `coreBuildPassed=false`. A separate full5840-input review closed only two differences: Git-index stat caches and the regenerated rav1e vendor container, with identical index semantics,33827 vendor file payloads/order and all other protected inputs. Both actual wrapper targets subsequently exited0. Independent review verified the arm64/platform7/minimum26 framework,302 generated definitions, public APIs, and unchanged source/product inventories. Raw compiler warnings and the missing bundle resource seal remain recorded; a newly sealed App copy is required for runtime testing. These build results do not establish App playback, iPhone operation or distribution.

The corrected-archive 4K HEVC diagnostic now passed three real ASS / SRT / WebVTT runs. Root personally reviewed all nine original own-window PNGs for readable Chinese, full16:9 content and first / next / actually rewound cues. Public CM formats were121 / 121 / 110, all with valid3840×2160 aperture and PAR1:1; all observed hvc1 sessions reported hardware=1. The original phase deadlines and unfiltered raw logs remain. The new copy used standard native signing; the old driver, signing pilot and kernel-rejected launch remain failed and retained. Evidence is in `.build/NativeAperture4KStandardSealedRuntime-r5/` and `.build/NativeAperture4KRootReview20261003/`; an independent review of all nine images and actual execution passed in `.build/NativeAperture4KStandardExecutionIndependentReview20261003/`. This does not establish final App, EOS, all orientations, audible, minimum26 or physical-device acceptance.

The iOS aperture engine has also run in a fresh ARM64 diagnostic product copy: all18 default signatures and strict checks passed without non-signature code/data/UUID changes. Its original complete44 tests actually passed43, failed1 and skipped0 on the assigned iOS27 simulator, exit65. The same indefinitely held-tail seek case still had no new video/audio over the original6-second observation. All original compiled inputs/products and checker configuration remained unchanged; raw MTC/background-layer/GL prints were0. This engine does not contain the native pause candidate. Evidence is in `.build/NativeIOSSimulatorAppIntegration20261003-r3/`; the old reserve failure remains unchanged. Final engines, subtitle visual checks, minimum26, physical-device and release acceptance remain open.

## Order

1. Finish the agreed scope, review the compatibility table, and run all applicable tests and platform builds.
2. Complete real playback and UI acceptance; preserve evidence for the exact candidate commit.
3. Verify GitHub CI. Build macOS release, sign with Developer ID, notarize, staple, mount DMG, install in the VM, and verify first launch and playback.
4. Build iOS archive with the intended team and provisioning. Install on a real iPhone and verify playback. The user accepted macOS-first public distribution with iOS built and tested alongside it. Advance TestFlight / App Store distribution as account conditions permit and report its actual state; do not add public iOS distribution as a prerequisite to the macOS-first release. If TestFlight is used, wait for processing and verify the install link before claiming availability.
5. Create a version tag and GitHub release with macOS artifact, SHA256, release notes, compatibility and explicit iOS distribution state. Never upload a simulator artifact as an installable iPhone release.
6. Download the published macOS artifact and check its hash, signature and notarization. Add the product and verified download to the AetherNative site through its existing content structure; verify the deployed page.

## Stop conditions

Failing core tests, crashes, missing playback evidence, or missing signed macOS artifacts block the macOS release. Missing iOS provisioning / device evidence blocks the iOS testing claim and must be reported explicitly; it does not silently change the accepted macOS-first distribution order. External App Store review cannot be called complete while pending. A preview release, if explicitly chosen, must state remaining limitations.

## Rollback

Retain the previous version and its hashes. Do not overwrite published artifacts in place. Correct faulty binaries with a new version. Website changes must be reversible through their scoped commit.

## Current candidate evidence

2026-10-03: the production implementation baseline is `e4d7ff0f8e91e99cec13c6bca66c60dda795ad3a`, including the derived typed-callback bridge, confirmed progress, source-health completion validation and session isolation. Commit `fb65037810a241b35b5e09c9e4b9f71a84a0e008` contains two TCP test-helper corrections and documentation. The current diagnostic changes add bounded DEBUG timelines, failure attachments, four shared diagnostic-boundary tests and explicit ARC ownership for Mac test windows; they do not change release playback, protocol deadlines or the agreed scope. Mac UI query/layout corrections are being validated separately. No current-source signed macOS DMG has been prepared.

The formal iOS 26.5 application run passed **29/29, zero failures or skips**, including AppStore 8, audio preparation/coordinator 8, EOF 4 and original playback 9. Result: `.build/results/AetherFilm-final-bridge-full-20261003-0038.xcresult`. Natural completion retained its original 6-second deadline, pause drift retained 0.35 seconds, and all 20 SMB seek/output assertions were preserved. The same App completed the full UI run with **18 passed, zero failed, one opt-in skipped**; a correctly configured Reduce Transparency run separately passed **1/1, zero skips**. Together, 19 scenarios actually ran; 22 original screenshots were reviewed and all 69 installed App files matched the build. Evidence: `.build/FinalBridgeUIEvidence/review.json`, full `0040` and dedicated `0047-v2` xcresults. The incorrect legacy target/configuration skip in `0045` remains preserved. This does not certify full-app maximum text sizes or spoken VoiceOver acceptance.

GitHub run `37083136280` for `e4d7ff0` **failed overall**. Its platform job passed all three builds and the formal iOS 27 Simulator **29/29, zero failures or skips**, with no runtime warnings. Its shared job was **34/41, seven failures, zero skips**: six BSD socket receive EAGAIN errors and one concurrent stalled-protocol check at 8.162 seconds against the unchanged 5-second deadline. Exact logs/artifact and review remain in `.build/CIe4d7ff0Evidence/review.json`. A green platform job does not satisfy the CI gate.

Two test socket helpers now execute blocking BSD operations on dedicated concurrent GCD queues through continuations instead of detached Swift tasks. The full local shared suite passed **41/41, zero failures or skips**: Domain 9, Library 4, Sources 28. All assertions, the existing 3-second socket receive timeout and the 5-second stalled-protocol limit remain unchanged; no filtering or serialization was added. Evidence: `.build/SMBSocketQueueFixEvidence/review.json`. The blocked cooperative-executor path is established, but no CI thread trace proves it is the sole cause of the earlier delays.

GitHub run `37084529322` for `fb65037810a241b35b5e09c9e4b9f71a84a0e008` **failed overall**. Shared tests passed **41/41**, and all three platform builds passed. The iOS 27 Simulator application tests were **26/29, three failed cases, zero skips**: the two real-SMB near-tail cases timed out before actual output reached their gates, and the repeated-seek case timed out on its first seek. Six failure records belong to these three cases. Exact artifact `11260201844` and review remain in `.build/CITestSocketFixEvidence/review.json`. The same unchanged test product passed the three focused cases locally on iOS 26.5 in **38.298 seconds**, with its source and binaries checked before and after; `.build/PlaybackEvidence/CI-fb650-Focused3/review.json`. This does not replace the failing iOS 27 CI result. Bounded, explicitly enabled DEBUG numeric timelines are being added to distinguish data delivery, decoder callbacks and application state; no playback deadline or output assertion is relaxed.

Diagnostic run `37086982680` for `4d25379ea11cb7caf2122ccd15c62ac889b1be82` also **failed overall**. Shared compilation failed before execution on Xcode 26.6 / Swift 6.3.3 because a DEBUG Task initializer was ambiguous. Platform builds passed; playback was **27/29, two EOF readiness failures, zero skips**. All 20 SMB seeks and reopening passed this run. Exact artifact `11261102382` matched its digest; `.build/CI4d25379Evidence/review.json` preserves the original result. Recorded delegate delivery and HTTP-send completion were short; opening/source reads consumed seconds before normal clocks began. The traces do not establish a particular SMB/C-lock root cause, and neither EOF test reached tail release/failure injection or completion validation. An explicit `Task<Void, Never>` fixes the compile ambiguity locally; Swift 6.3 CI verification is still required. The same diagnostic product passed the full local official iOS 27 run **29/29** in 82.917 seconds; this does not replace CI.

EOF test phases now give cold opening its existing 12-second actual-output gate before the unchanged six-second held-tail seek/output gate. A separate real-SMB cold-resume case retains direct `startAt: 10` coverage and real clock/input/frame/audio evidence before natural EOS. Its first observed running clock with real video/audio must be at least 9.95 seconds, rejecting ordinary playback from zero; the original readiness and EOS deadlines remain. Dynamically selected tail bytes remain withheld until the original gate passes, and video/audio after the explicit seek must each increase by more than five from its pre-seek baseline. Independent static review is in `.build/SMBDebugTraceEvidence/PhaseReview/review.json`; the earlier 30/30 draft lacking the first-output guard is not final evidence. The strengthened iOS 27 full suite passed **30/30, zero failures or skips**, in 78.575 seconds; the three SMB EOF cases passed **3/3** on iOS 26.5. A separate test-only negative copy using startAt0 was correctly rejected at clock0.866667 after 2.051 seconds. Original xcresult summaries are in `.build/PlaybackEvidence/PhaseGuard/`. This changes test setup, not production timing or streaming.

Exact commit `3210ab28466b4ba0cb0f109e587892e048002be4`, GitHub run `37089277731` attempt1, **passed overall**. Shared tests were **45/45, zero failures or skips** on Xcode26.6 / Swift6.3.3, verifying the explicit DEBUG Task type. All three platform builds passed; the formal iOS27 / 24A434 application run was **30/30, zero failures or skips**, 163.280 case seconds / 163.429 suite seconds. Real SMB completed all20 seeks and reopening. Artifact `11262016795` matched official SHA256 `2375c339e54aa1dc3e00754d73edda79ecd9437ac7c2dd975faa8d7c75eb6e60`; original results, attachments and logs are in `.build/CI3210ab2Evidence/review.json`. xcresult runtime warnings were empty, but the console contained audio-system warnings. This CI result does not certify Mac graphical playback, physical iPhone operation or distribution.

The enhanced Mac22 suite ran in the existing Aqua session with the original output assertions and deadlines: **10 passed, 12 failed, zero skipped**, 181.378 seconds. Failing output gates had decoded/displayed video0/0 while audio and clock could advance. The earlier ARC/window-close crashes did not recur; this does not establish the black-screen cause. Original result, numeric failure attachments and Aqua context are retained in `.build/ReleaseEvidence/candidate-fb650378/GUIReadiness-native-ui-c4fd83c4/PhaseGuard22/Results-AquaPlayback22-20261003-c4fd83c4/`. Mac playback remains a failing release gate. Separate stock/derived default-player diagnostics both recorded OpenGL view initialization failure. An independent experiment with the fixed engine’s original pixel-format attributes returned nil before view creation; the alternate CA output also failed to open. Original numeric records are in `.build/NativeMacUIDiagnostic-c4fd83c4/GLCA/Results-Aqua-20261003-c4fd83c4/`. These results locate the VM failure stage; they do not establish real-Mac compatibility. The four-variant renderer experiment confirmed an online software renderer in the VM: Accelerated requests fail, whereas software format/context/view creation succeeds. No production backend was changed. The separate real-Mac22 run was **17 passed, five failed, zero skipped**: two unchanged held-tail clock gates and three SIGABRT OpenGL framebuffer assertions (Replay,4K,CommonContainers). Real H264 output, cold SMB10 and all20 SMB seeks/reopening ran successfully; they do not replace the failing full run. Exact result and independent review are in `.build/HostMacPlayback22-06009614/`. Independent stock/derived processes are being prepared to isolate output and host-window lifecycle; physical iPhone and final distribution remain open.

Current-source macOS Debug/test products, unsigned arm64+x86_64 Release and the iOS Release archive were built. The new iOS archive passed **57/57** independent content/signature checks: minimum 26.0, iPhone/iPad, three arm64 Mach-O files, actual signature/provisioning, icons, four license texts plus bridge source/third-party notices, no test bundles or fixtures, and the derived class/callback evidence with no diagnostic getter. All 68 compiled-source/resource hashes matched the formal and frozen project. Evidence: `.build/ReleaseEvidence/ios-archive-inspection-confirmed-eof-system-trust.json`. The initial sandbox trust errors are retained; read-only system-trust verification passed outside the sandbox. This is an **Apple Development archive with `get-task-allow=true`**, not a TestFlight/public-distribution export, and it has not been installed or launched on the real iPhone.

An exact-`e4d7ff0` complete application/bridge source candidate, its manifest and archive, and actual modified-wrapper relinking are verified in `.build/CorrespondingSourceCandidates/e4d7ff0-51b82e86/{stage-review.json,relink-review.json,archive-review.json}`. Baseline and modified universal macOS Apps were relinked for arm64 and x86_64: both modified slices contained the marker, both baseline slices did not, and minimum macOS remained 26.0. A CLI consumer returned the one-file bridge modification's marker. No iOS relink or App GUI was executed. This does not establish a full libVLC engine rebuild or App GUI/playback acceptance. The candidate is unpublished; the final commit requires a new independent source archive and explicit hash binding to unchanged production code and the actual distribution build.

The DMG currently on disk belongs to old `c790607`; the 54 Gatekeeper-enabled VM checks belong only to old `5e12be2`. Neither certifies the new bridge. A new signed/notarized DMG, its VM install/first-launch/playback and published download checks remain open. The Mac VM now has an existing Aqua session. Running UI tests through that session produced **11 passed, seven failed, one opt-in skipped** in 204.137 seconds; original results and screenshots are retained in `.build/ReleaseEvidence/candidate-fb650378/GUIReadiness-native-ui-c4fd83c4/Results-AquaUI-20261003-c4fd83c4/`. The failures cover accessibility description, narrow-window sizing, return from full screen, system picker querying, playback advancement/controls and the SMB form. The earlier SSH-context UI initialization timeout is separate. The SSH-context Mac application run was **8/21 passed, 13 failed**; video output was absent and the crash logs showed an ARC/window-close problem in the test harness. New test windows retain ownership on close; the subsequent Aqua22 run above did not crash but still failed actual video output. The VM has a real1920×1080 display; an empty SSH display report did not establish that a display was missing. No account, automatic-login or security setting was changed. The physical iPhone is still locked, and no tag, release, TestFlight/public iOS installation or website deployment has completed. Remaining device/UI boundaries are recorded in `TEST_MATRIX.md`.

## Historical candidate evidence

2026-10-03: the preceding signed DMG is built from `c7906074451b0a8ccb0b5ad6f7f462f3ea60f4c1`. It includes TCP half-close compatibility, reconciliation of a reproduced late-pause control-state defect, and synchronous iOS audio activation on a background serial coordinator. Both platform Debug test products, universal macOS Release and an iOS Release archive were built. A local iOS 26.5 run passed 22/22 playback/AppStore/audio cases and a separate focused UI run passed 3/3. Historical complete UI results remain valid only for the source and scenarios recorded in `TEST_MATRIX.md`.

GitHub run `37075306804` passed shared tests 33/33 and all three builds, but platform tests were 21/22: natural completion after a seek failed when the wrapper's cached time rolled back from 11 to 6.179 seconds before stopping. Twenty real SMB seeks and all audio lifecycle cases passed this round; the slowest seek still approached the unchanged 12-second deadline. The complete logs contained no AudioHangRisk text and no xcresult runtime warnings. These observations do not prove SMB stability or the underlying completion cause. Evidence and earlier failed runs are retained; this is a failing release gate.

The old c790607 App and DMG notarization are Accepted; signatures and tickets validate. DMG SHA256 is `84c488982fb76402d8d47515b155de46e6b6d5c9f8b3350056f2cdac5ba4d684`; 31 local inspection checks passed, including the read-only mounted volume, licenses, icon, minimum 26.0, universal Mach-O files, and UUIDs matching the built app. `artifacts/CANDIDATE_MANIFEST.json` records three asset hashes and `publicationReady=false`. Host policy assessment is limited by its pre-existing security override. The 54 Gatekeeper-enabled VM checks and relocated Debug products belong to the preceding `5e12be2` / `fb32d110` candidate, retained in `artifacts/previous-candidates/0.1.0-fb32d110/`; they do not certify c790607 or the current-source candidate. The VM remains at its login window and no GUI first-launch/playback or UI acceptance has run.

The old c790607 iOS archive passed 32 signature/file inspections with minimum 26.0, iPhone/iPad support, arm64, icon and licenses, and no test bundles/fixtures. It is signed with Apple Development and `get-task-allow=true`, not an App Store/TestFlight distribution export. It has not been installed on the locked real iPhone.

Subsequent settings fixes show visible native subtitles-size and volume captions. The DEBUG UI appearance helper now preserves the system font unless an explicit test override is supplied. Four targeted runs passed: settings, native slider adjustments at the standard system size, actual accessibility-extra-large, and the maximum system size with no override. Original screenshots and app/dylib byte identity are recorded in `.build/UILabelEvidence/review.json`. Earlier controlled-font results were reclassified without deleting their evidence. The old signed DMG predates these settings fixes; current source builds and UI results are recorded above, while packaging and exact-candidate acceptance remain open.

No tag, release, public download or website deployment has been completed. Core CI, macOS graphical acceptance, iPhone playback acceptance, full-app maximum typography/VoiceOver and the remaining compatibility matrix are open. The isolated website candidate has passed checks and browser review but remains unpublished. See `TEST_MATRIX.md` for exact evidence and limitations.


原生 sample-buffer 候选已通过 ASS / SRT / VTT 共九张正常字幕画面的 Root 复核及 H.264 硬件属性检查；跨显示队列片尾候选在 iOS 两项真实 SMB golden 加十项纯判定实际12/12。从真实2秒段回零的held负向和完整SMB来源回零控制各实际1/1。现已合入正式源码并成功构建Mac36 / iOS44测试产品，完整回归待执行。4K初始字幕和hardware=1有正常窗口证据；独立作者样式的ScaledBorderAndShadow=yes实际清晰，不代表引擎修复。H.264物理比例、原早期seek0在held条件下恢复、完整新UI、设备与分发验收仍待完成；无tag或公开版本。


最新正式完整回归为Mac36/36、iOS43通过/1失败/0跳过；Mac原MTC环境保留、原始固定MTC/GL打印0。当前H.264原生格式缺visible aperture，实际320×180被呈现为320×192，正常图像窄黑边仍为失败项。M1健康放行单项虽1/1，但放行前已在播放缓存，没有复现旧stall，不证明其修复。完整UI、物理设备和新分发包仍待验收，不发布tag或版本。
