> build4 新候选分发检查通过：DMG 与 App 公证 Accepted，票据、严格签名及 Gatekeeper 通过；只读挂载核对实际0.1.1 / build4、卷名及安装内容，远程 Mac mini 独立安装版本和签名检查通过，实际安装播放仍未验收。普通 CI37623016669 的 Mac62项全部通过，唯一用例身份62，原生崩溃0、runtime warnings为空，79份附件 / 8份停止换片快照实际读取；iOS仍运行。详细证据见 `ci-lifecycle-build4-mac-r1/review.json` 和 `release-build4-dmg-r3-review.json`、`release-build4-remote-install-r1.json`。

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



## 2026-10-07：5d8b2bc 完整 CI 与官网候选

本轮仅补充测试诊断：服务端数值记录改为首64 / 末448的有界保留，并在清理前独立写入CI已上传的build/Logs目录；不记录路径、凭据或协议内容。修正诊断hook转发可选协商参数，避免监控本身改变协议调用。原断言、期限和App / 原生播放代码未改。15项执行器 / 崩溃采集 / 数值记录单元测试通过；独立真实SMB2控制完成270次字节校验读取，552事件保留512、明确省略40，负向子进程exit65正确保留。原四失败用例本机各重复3次，共12次通过，runtime warnings为空；不替代失败CI。补充诊断后的iOS与Mac build-for-testing均通过，validator原单项1/0/0且实际生成991事件、旧新generation附件。第一次诊断验证命令误用了-test-iterations 1，Xcode在执行前拒绝、实际0项；移除无效参数后的r2原断言通过。测试设备最终已处于Shutdown。证据为`numeric-timing-fixture-control-r2-review.json`、`failure-focused-r1-review.json`及原结果。

CI37595707384已结束，整体失败。共享任务通过，Mac26.6.2原完整61项全部通过；iOS27原完整70项为65通过 / 4失败 / 1私有NAS条件跳过。独立xcresult实际用例身份与计数一致，两端runtime warnings为空，Mac崩溃采集0条。修正后的SMB20次循环跳转 / 重开、恢复误通过控制及SMB seek-zero均通过，不能覆盖其他失败。

四个iOS失败用例：`testActiveDoubleSpeedForwardTailSeekConsumesRealOutputOnce`、`testPendingValidatorOldSessionCannotFinishNewFilm`、`testPriorWatchedStateSurvivesRealTailReadFailure`、`testRealSMBColdResumeHasOutputAndCompletes`。控制台8条失败记录属于4个用例。短GOP2倍速原始观察在seek后0.631秒有normal11.608605及新增音视频，但clockRunning一直false、最终ended1；没有达到原新鲜运行时钟门禁。其他三项分别在新会话真实输出、held初播、SMB冷续播输出等待中超时，未由此证明原播放状态保护错误或认证根因修复。不放宽期限或将缓存时钟当成真实播放。

远程Mac27完整运行exit65，runner建立连接前挂起，实际0项用例；保留通道拒绝、采样和结果，临时Agent清理exit0、严格签名复核通过。iPhone16ProMax / iOS27.0.1当前paired且connected，DeveloperMode仍disabled，真机播放门禁继续开放。

官网候选仅在隔离目录准备：基于官网8ccc6e7，只改AetherFilm app.yaml、releases.yaml、media/icon.png。165项测试、338页构建、9042站内链接、3份签名清单和469个本地JSON地址检查通过；浏览器复核中文产品页及中英v0.1.1说明。未部署，原官网工作区未改动。发布时须刷新日期、最终限制说明并先验证GitHub匿名下载。

证据：`.build/P0Optimization20261006/ci-seek-gate-{mac,ios}-case-review.json`、`ci-seek-gate-ios-failure-review.json`、两端原xcresult及attachments、`seek-gate-mac-full-r1/Results-runner/outcome.json`、`website-v011-candidate-review.json`。完整Mac UI、真机、听音、VoiceOver及恢复路径多轨道 / 外挂字幕仍待完成，Release保持草稿。

> 2026-10-07：用户反馈本机简单测试基本无问题；按基本使用 smoke 反馈记录，未据此认证 VoiceOver、完整设备或全部矩阵。用户选定3号图标后已重新构建build3；公开分发及完整验收仍未完成。

# v0.1.0 验收矩阵

## 2026-10-07 SMB恢复后的验收计数修正（PR #1，未发布）

- 文档提交 `fa916e5` 的CI37591286532整体失败：共享 / Mac26任务通过，Mac实际60通过 / 0失败 / 0跳过；iOS实际65通过 / 3失败 / 1私有NAS跳过，无runtime warning。三项失败为2倍速片尾、SMB seek-zero预热、SMB循环跳转；6条断言 / unexpected错误不写成6个失败用例。
- 循环跳转失败附件中，同一用户播放会话的兼容恢复更换原生引擎。旧引擎跳转前记录至少164个已显示帧；新引擎在原12.2～14秒目标窗口内已有真实正常时钟和最多67个新帧，原测试仍比较旧引擎计数。此次只修正测试的统计归属，不改App计数，不累加旧帧伪装新输出。原12秒期限、target+0.2～target+2边界、20次跳转 / 两次关闭重开均保留；额外要求同媒体且明确兼容恢复、新引擎真实音视频、seek后的配对运行正常时钟。新增控制拒绝无关引擎、旧时钟、目标越界与空音视频。
- 当前修改的真实SMB专项与新控制用例各执行3次，全部通过、无runtime warning。完整iOS27共70项为 **69通过 / 0失败 / 1私有NAS opt-in跳过**，无runtime warning；独立核对70个实际case身份，前述三项及新控制本轮均通过。自建模拟器已Shutdown。另两项偶发失败的生产根因未认证修复，不由此次测试修正消除历史失败。
- 当前修改的Mac Debug测试产品已构建，源码 / 传输包SHA256一致、严格签名通过；已在用户批准的远程Mac mini启动完整播放，当前仍在启动阶段，尚未进入用例；系统日志记录XCTestManager通道被拒绝，不能认证播放断言失败或通过。不得将先前Mac60或ASAN专项写成本轮完整通过。
- 原停止切换用例的App / test AddressSanitizer专项实际20轮均通过，原assertions保持、无runtime warning、ASAN错误0、原生崩溃报告0；ASAN运行时映射已实际核验，临时LaunchAgent清理及运行后严格签名通过。xcresult按1个方法聚合，原日志核对20次实际迭代。捆绑VLC库未以ASAN重建，旧原生崩溃根因仍未认证修复。
- build3 Mac UI复测exit65，runner启用Automation Mode超时；xcresult记1个runner初始化错误，实际UI用例0项，原始结果保留且临时Agent已清理。iPhone开发者模式仍disabled；真机与完整UI / 听音 / VoiceOver门禁未闭合。GitHub草稿DMG已实际认证下载，SHA256与本地公证包一致、镜像校验通过；这不认证匿名公开下载或安装后播放。

证据：`.build/P0Optimization20261006/` 中 `ci-build3-docs-ios-r1-summary.json`、`ci-build3-docs-ios-smb-replacement-counter-review.json`、`seek-gate-source-review.json`、`seek-gate-focused-r1-outcome.json`、`seek-gate-full-ios-r1-{summary,case-review}.json`、`mac-stop-asan-build3-r2/outcome.json`、`mac-ui-build3-r1/outcome.json`、`draft-download-build3-r1/download-evidence.json`。当前发布仍为草稿，P0未闭合。

## 2026-10-07 当前build3验收状态

| 门禁 | 当前证据 | 状态 / 限制 |
| --- | --- | --- |
| 当前提交CI | `422ba86`，CI37588324314三个任务success；Mac26.6.2为60 / 0 / 0，iOS27模拟器为68 / 0 / 1，runtime warnings均为空 | 本轮通过；旧偶发片尾、认证及Mac崩溃失败保留，根因未认证修复 |
| 选定图标与版本 | 3号浅色玻璃A；macOS / iOS Release产品均0.1.1 / build3 | 已接入，最低系统26.0保持 |
| macOS候选分发包 | SHA256 `81c762002e3c048fe507afe79429bcf3e396f1255683b529bbc4ead274b80828`；App / DMG公证Accepted、票据 / 严格签名 / Gatekeeper / 挂载内容通过，远程Mac提取App验证通过 | GitHub草稿digest一致；未公开下载，未认证完整安装后播放 / 升级 |
| iOS候选 | build3签名Release归档、iPhone16ProMax / iOS27.0.1实际安装与启动成功 | 未认证实际播放，未公开分发 |
| 真机首轮播放测试 | 三项请求，exit70、实际0项执行；Developer Mode disabled，设备paired / available | 环境阻塞；不是三个用例失败或通过；待用户开启模式后原断言重跑 |
| 完整UI / 人工验收 | 既有Mac TouchBar审计失败与后续0项启动失败保留；当前完整真机、听音、VoiceOver和恢复路径多音轨 / 外挂字幕未闭合 | 不以用户基本Mac smoke反馈或窄专项替代 |
| 发布 | PR #1开放draft，v0.1.1 Release为草稿 | 尚未发布；披露风险先发macOS的取舍等待用户回复 |

新崩溃收集器保留经过隐私裁剪的原生栈；本轮通过的Mac CI中报告0、不可读0，不以未出现报告证明旧崩溃根因已修复。证据见 `.build/P0Optimization20261006/ci-native-diagnostics-mac-r1/Mac26Playback/Results-runner/native-crashes.json`。新收集器本地两项专项及原执行器八项单元测试通过；未宣称CI运行了新增两项专项。

本轮构建 / 安装 / 真机环境失败记录见 [RELEASE.md](RELEASE.md#current-candidate-2026-10-07-v011--build3)。下方各阶段失败与通过记录保留，不覆盖其原始适用范围。

## v0.1.0 正式发布记录（2026-10-06）

- **macOS 首发包**：`artifacts/AetherFilm-0.1.0-macos-arm64.dmg`（SHA256 `20b579a6c089828808149f2eb776aa7536d4eb8d7b62859326721e300a02f51f`）。
- **签名与公证**：Developer ID Application 签名，Apple Notary Service（profile `AetherRoute-Notary`）公证 Accepted，票据装订并经 `spctl` 与本地只读挂载验证。
- **发布标签**：GitHub Release `v0.1.0` 已公开发布，附带 DMG、`SHA256SUMS.txt` 与完整发布说明。
- **iOS 归档状态**：`build/AetherFilm-iOS.xcarchive` 已构建并通过代码签名校验；App Store / TestFlight 审核分发按开发者账号排期推进。

## 2026-10-06 P0 与 NAS 浏览优化（已提交PR #1，未公开发布；以下保留阶段记录）

- NAS 常用目录、恢复上次目录 / 打开行、持久化自动连播开关及真实下一文件名已实现；库格式仍为 schema 1，旧数据默认自动连播开启。移除片源只移除对应浏览状态，不删除原视频。
- 共享当前套件实际 **48通过 / 0失败 / 8项 SMB3 opt-in 跳过**；真实 SMB AddressSanitizer 集成 **5通过 / 0失败 / 0跳过**，包括20轮读取消 / 关闭 / 重开。旧 native teardown crash 尚未认证修复。
- 原 CI `37407702629` 的共享 trace 阶段断言失败及三项 iOS 倍速片尾失败仍保留。仅为 trace 测试加入真正的 server requestFinished 屏障；将主动片尾轮询的 JSON 编解码换成同一 typed snapshot，原断言、时钟和期限均未修改。当前本地通过不替代 CI 重跑。
- 优化候选 iOS 原完整播放加新增测试 **68通过 / 0失败 / 1明确 opt-in 跳过**；NAS 用例缺少私有启动器时跳过。远程 Mac mini 当前 AppStore 修正后的完整播放 **60通过 / 0失败 / 0跳过**，原 Main Thread Checker、原方法身份与严格签名检查保留。macOS / iOS Simulator Debug、iOS Device unsigned Release 构建通过；unsigned build 不是设备验收。
- iPad 完整 UI **20通过 / 0失败 / 1自然跳过**；后续最终 AppStore 候选的收藏 / 自动连播 / 实际开启 Reduce Transparency 专项 **3通过 / 0失败 / 0跳过**，恢复原系统设置；最终 iPhone 实际开启该系统设置的专项另 **1通过 / 0失败 / 0跳过**并恢复原设置。首次误用不存在方法名的启动记录实际0项用例，不计入验收。最终 AppStore 修正后的 iPhone / iPad 整套各另 **20通过 / 0失败 / 1自然跳过**，无 runtime warning；最终 AppStore 修正后的 iOS 整套另 **68通过 / 0失败 / 1明确 opt-in 跳过**，无 runtime warning。Mac 最终 UI 在系统 Automation Mode 认证阶段超时，实际0项用例执行；不替代此前 TouchBar 审计失败。听音、VoiceOver 朗读和完整物理 iPhone 验收仍未完成。
- 兼容恢复后的最终源码 iPhone / iPad 完整 UI 各 **20通过 / 0失败 / 1系统 Reduce Transparency 未开启而自然跳过**，无runtime warning。前述真正开启系统设置的各专项仍单独保留。再次检查当前候选常用目录恢复和大字体暗色连播设置截图，控件 / 下一文件名 / 顺序说明可读；没有据此认证整个矩阵的人工 VoiceOver 朗读。
- 用户授权的真实 NAS 只读验证：认证、有限目录发现、三个视频的头 / 中 / 尾 Range 通过。生产 SMBProvider + SMBStreamingServer + FilmPlayer 对较大视频的首次音视频输出及中途跳转 **1通过**。另一视频首次输出成功，跳转专项先出现播放错误，后续诊断复现为正在输出但没有正常时钟、超出原30秒期限，**原失败保留**。第二种失败的 sourceReadFailure=false，iPad 后续也复现。生产 provider / HTTP 的四组512KiB Range 内容均与独立客户端 SHA256 比较通过，但跳转仍失败；同视频走独立 HTTP 传输的对照则首次播放 / 跳转通过，这不是生产验收通过，也不单凭对照认证根因。独立 FFprobe 对初始 / 中段 / 后段解析，以及 FFmpeg 中段音视频解码均 exit0、错误行0。不能只选通过的视频，不能据此认证 NAS 全部通过。
- 后续兼容诊断：原生音频 observer 持续运行、首 PTS 正常，但该视频跳转后输入连续创建50个时钟上下文。加载前使用已锁定组件内的 AVFormat 解析器通过，同参数加载后设置的早先尝试并未证明解析器生效。默认改用 AVFormat 的整套回归实际 iOS **63通过 / 5失败 / 1跳过**、Mac **54通过 / 6失败 / 0跳过**，影响真实片尾阻塞用例，方案已撤回；全部结果保留。
- 当前候选保持默认解析器，仅对 NAS loopback MP4 / M4V / MOV 跳转，在真实新增音视频、输入明显超前、且没有新鲜正常输出时钟时尝试一次兼容恢复，保持媒体 / 外挂字幕、播放设置、音轨选择和 App 会话回调。普通片源等待不触发恢复。早先仅检查 clock=nil 的候选仍失败，保留 `user-nas-fallback-r18-ipad.xcresult`；最新缺失或停滞时钟候选对原失败视频连续 **3次通过**（r19/r20/r21），r21还核实音轨 / 字幕选择。最早恢复候选完整 iOS **68通过 / 0失败 / 1 opt-in跳过**；最终音轨保持候选统一源首轮 iOS **67通过 / 1失败 / 1 opt-in跳过**，倍速预热 normal3.937超过原3.0上限，失败保留。随后停止其他本地构建和NAS专项，以相同源码 / 产品和原断言独占完整复测 **68通过 / 0失败 / 1 opt-in跳过**，无runtime warning；不能仅凭重跑通过就认证首次预热失败根因已解决。最终源码三个已发现 NAS 视频均各1通过 / 0失败 / 0跳过（r21/r22/r23），每个均完成四组独立512KiB字节校验及真实首播 / 跳转；兼容恢复路径的多音轨和外挂字幕仍需专门样片验收。以上不能替代真机、听音 / VoiceOver、Mac UI、CI和分发门禁。
- 最终兼容恢复源码在新建自有 iOS26.5 模拟器上完整播放回归 **68通过 / 0失败 / 1私有NAS opt-in跳过**，共69项，无runtime warning；与iOS27使用相同最终构建产品和原断言。此前旧26.5设备 runner启动失败记录保留，新设备通过不能单凭此认证旧环境故障根因，也不替代精确26.0或物理设备验收。证据 `fallback-final-ios26-fresh-full.xcresult` 及对应summary JSON。
- 最终兼容恢复源码 Mac build-for-testing 通过；本机与远程36个 Swift / 项目 / 版本 / package输入 SHA256全部匹配。后续两次 Mac XCTest 启动均实际0项执行，首次进程采样停在 `_prepareTestConfigurationAndIDESession`，保留全部日志与xcresult；仅终止带本轮session标记的自建进程。尝试重新启动用户 testmanagerd 服务被系统 SIP拒绝，未绕过保护。此前60项通过结果不覆盖这次兼容恢复修正，当前完整Mac回归仍未完成。
- 收尾续验远程 Mac mini可连接，但 `devicectl list devices` 中 iPhone16ProMax 当前为 unavailable；未安装候选。此前设备可连接记录不能作为当前连接或物理验收证明。
- 凭据仅在启动器内存和临时 loopback bootstrap 中使用；未写入源码 / fixture / xcresult。NAS 不保存原视频或截图，仅失败时保留 bounded numeric lifecycle 附件。

证据：`.build/P0Optimization20261006/` 的 `shared-final.log`、`smb-asan.log`、`optimized-ios.xcresult`、`ipad-ui.xcresult`、`ipad-final-controls.xcresult`、`user-nas-ios27-r3.xcresult`、`user-nas-small-r4.xcresult`、`user-nas-small-r5.xcresult` 与 `nas-small-r5-attachments/`；Mac mini 隔离目录 `/Users/chenxu/AetherFilmQA/P0Optimization20261006/.build/{MacPlaybackFinal/,MacUI/}`。iOS26.5 真实 NAS 第二次尝试是模拟器 runner / launchd 环境故障且未执行用例，和真实 NAS 播放失败分开记录。新候选尚无签名公证分发验收，P0 保持开放。

## 2026-10-06 收尾记录（测试执行于2026-10-05）：当前续验以 `375fc63` 为基础，保留会话开始前已有的 SMB cancellation mock 屏障修改；App 与原播放 / UI 断言及期限未改。三平台本地 build-for-testing 均通过，iOS Device 开发签名构建通过。最新 GitHub CI `37215169426` 确实执行了构建和测试：三平台构建成功，但共享 cancellation 测试失败、Mac 原完整播放 **56通过 / 1失败 / 0跳过**、iOS 原完整播放 **62通过 / 3失败 / 0跳过**。第三项 iOS 失败是 4K 测试进程崩溃，原 crash 的故障栈位于 AMSMB2 `smb2_read_data → smb2_service → disconnect → deinit`；不能仅凭测试名称归因为 4K 解码。实际失败记录不支持“只是 GitHub 额度不足”。

本轮真实结果：共享 **45通过 / 8项 SMB3 opt-in 跳过**；单独真实 SMB3 加密 **8通过 / 0失败 / 0跳过**（client / server encrypted frames 各97、plaintext READ 0）；AddressSanitizer 下真实 SMB 集成 **4通过 / 0失败 / 0跳过**；执行器单测 **8通过**。iOS27 与 iOS26.5 ARM64 模拟器的原完整播放各 **65通过 / 0失败 / 0跳过**，逐项身份核对且无 runtime warning。26.5 不等于精确26.0或真机验收。这些通过不改写 CI 旧失败，也不认证偶发 native SMB 崩溃已经修复。

用户明确以远程 Mac mini 替代不可用的 Tart VM。本轮 Mac mini / ARM64 / macOS27.0.1 / Xcode26.5 / SDK26.5 开发测试候选的原完整播放实际 **57通过 / 0失败 / 0跳过**，逐项身份与编译的57方法一致，原 Main Thread Checker 保留；原始日志无 MTC / background UI / 固定 GL 报错，测试前后严格签名验证通过。远程 App / 包 / 原测试 / fixture 的182项文件哈希与源快照一致；临时 Aqua agent 和 SMB fixture 均已清理。该物理27结果不替代未执行的最低 macOS26 / VM / 正式分发验收。

当前源 iPhone / iPad 的 UI 原完整19项分别 **18通过 / 0失败 / 1自然跳过**，各自真实开启系统 Reduce Transparency 的专项另 **1通过 / 0失败 / 0跳过**并恢复原设置。亮 / 暗、大字体 SMB 表单、横屏控制和播放设置的关键截图已人工查看；没有声称全部截图逐张审阅。Mac mini UI 第一次运行在系统授权阶段超时：日志明确 `Writer daemon requires authentication to enable automation mode`，xcresult 记录1项系统初始化失败，实际0项原UI用例执行；没有跳过或豁免旧 TouchBar 审计。后续原完整19项已实际执行，结果 **17通过 / 1失败 / 1自然跳过**、exit65，完整逐项身份、原配置及 Main Thread Checker 保留，严格签名与临时 Aqua agent 清理通过。唯一失败为 `testAccessibilityDescriptions` 对空且 Disabled 系统 TouchBar 的描述审计；独立纯 AppKit 窗口 / 原生按钮对照在同一机器、原审计下也 **0通过 / 1失败 / 0跳过**，同一 TouchBar 问题复现。临时 SwiftUI TouchBar 定制专项仍失败，已撤回，正式 App 源码不含该尝试。对照不豁免正式审计，Mac 真实减少透明度与 VoiceOver 朗读仍待验收。

证据：`.build/Continuation20261005/{logs/,SMB3-r1.json,iOS-Full-r1.xcresult,iOS26-Full-r1.xcresult,MacMiniPlayback-r2/,MacMiniUI-r1/,MacMiniUI-r2/,MacMiniUI-native-control-r1/,MacMiniUI-audit-touchbar-r1/,PhoneUI-r1.xcresult,PadUI-r1.xcresult,PhoneReduce-r1.xcresult,PadReduce-r1.xcresult,source-manifest.json}`。Mac mini 隔离目录 `/Users/chenxu/AetherFilmQA/Continuation20261005-e74ec7cb`；远程网络获取失败后使用原锁定依赖的离线副本，不更改用户现有应用或服务。用户已于2026-10-06授权推送代码，本轮提交包含测试稳定性、远程执行器与验收记录，不包含打 tag 或发布；当前完整 iPhone 真机、用户 NAS / 听音 / 朗读 VoiceOver、Mac UI 与新签名公证安装及公开分发仍待完成。

## 2026-10-04 候选记录（保留原失败与当时状态）

2026-10-04 最新Native8统一候选已加入四项独立片尾回归，原iOS61 / Mac53断言与期限不变，完整套件为iOS65 / Mac57。纯三平台原生编译、六个wrapper目标和正常三切片组件组装均实际exit0；最低26、SDK27、ARM64、302模块与原公开头文件保持。最终私有C4在真实iPhone原三项 **3通过 / 0失败 / 0跳过**、新增四项 **4通过 / 0失败 / 0跳过**；八个排空至停止窗口没有后续有效native30 /31时钟点，原失败记录保留。该专项不是正式无探针组件的完整65 /57、完整UI或分发验收。证据 `.build/NativeAVDrainLifecycleControlsPhysicalApp20261004-r1/ACTUAL_C4_PHYSICAL_CLOSURE.json`、`.build/Native8ProductionCandidate20261004-r2/READY.json`。

此前源码 `6100c1c` 的 CI `37202599510` 已完整核验通过：三平台 ARM64 构建均通过；Mac26.6.2 / SDK26.5 原完整播放 **53通过 / 0失败 / 0跳过**，iOS27 模拟器原完整播放 **61通过 / 0失败 / 0跳过**，源预期方法、原始日志与 xcresult 完整身份一致，无 iOS runtime warning。共享套件实际 **45通过 / 8项 SMB3 opt-in 跳过**，另五项执行器单测通过；日志的“53 tests passed”计入注册的跳过项，不能当成53项均执行。此前 CI 原失败完整保留。证据 `.build/Native7CICommit6100c1cReview20261004-r1/{MAC26_ACTUAL_REVIEW.json,IOS_ACTUAL_REVIEW.json,SHARED_ACTUAL_REVIEW.json}`。

同轮真实 SMB 控制已确认：normal11.403725、video313 / audio545 后自动95%且磁盘读回true；同一HTTP1 / UUID的真实391字节尾读错误后磁盘false且续播11.662保留。完整来源 seek0 有新input回绕和normal0.800060，视频18→35、音频95→192。服务诊断明确总5712事件、仅保留512与省略5200；256对真实entry / return中最长READ约144ms，不能将有限记录解释为整轮传输或旧多秒超时的原因已解决。证据同目录 `SMB_ACTUAL_INTERVAL_REVIEW-r2.json`。

私有 preroll-only 原生修正已在 iPhone12Pro / iOS27.0.1 通过原三项专项 **3通过 / 0失败 / 0跳过**：重播、暂停与倍速片尾跳转、半速自然完成。只将媒体预滚换算成系统时长，保留已有缓存补偿和1×行为；不修改原61、6秒 / 30秒期限或完成门。半速early normal0.805404 / input0.670468，最后normal12.105545 / input12.10236、347视频 / 562音频、完成一次。新增short-GOP严格尾输出两项实际 **1通过 / 1失败 / 0跳过**：2×最后normal11.771539低于新增原门11.8，虽然新音视频与完成一次通过，不能认证尾部全部消费。该失败保留；相同short两项在已知Native7实际 **2通过 / 0失败 / 0跳过**，因此不能用它证明原长GOP缺陷被负向拒绝。原片keyframe仅0秒、short片target11本身为keyframe，独立长GOP覆盖和真实音频排空仍在核对；私有数字探针版不可直接晋升生产。正式 Native7 的59/2真机失败仍保留。证据 `.build/NativeBufferingPrerollRateActualReadonly20261004-r1/REPORT.json`、`.build/NativeBufferingPrerollRatePhysicalApp20261004-r1/Focused3-r1/`。

追加异步排空候选（未晋升生产）在同一 iPhone 的原三项实际 **3通过 / 0失败 / 0跳过**。新增四项初次 **2通过 / 2失败 / 0跳过**，计入30毫秒滤波stride后的第二轮仍 **3通过 / 1失败 / 0跳过**：2×长GOP最后normal12.286767超过12.26。该同一真实回调时刻的AV样本等效媒体点为12.008173，公开normal领先278594微秒；后续排空current510171微秒已越过24480 / 48000样本的510000微秒队列末尾。两轮全部实际音频排空，失败不能归因于尾音未消费。源代码确认normal按计划systemDate锚与rate推进；100毫秒observer加30毫秒stride不能证明它以nominal duration为上界，先前假设被实际结果反证。仅尚未合入的新helper拟按独立ContinuousClock实际seek至观察EOS的墙钟进展限制上界，保留全部原61、lower、真实回调配对、输出增量、6秒期限、最小消费墙钟及完成一次。相同最新源码的已知Native7长GOP对照仍真实 **0通过 / 2失败 / 0跳过**，因提前EOS没有新的normal / input配对被拒绝。证据 `.build/NativeAVSampleDrainTailControlsPhysicalApp20261004-r2/R3_COMPARISON_CLOSURE.json`、`.build/NativeAVDrainActualEndReadonly20261004-r1/{REPORT.json,R3_UPPER_COUNTEREXAMPLE.json}`；两轮失败原件完整保留。

正式发布仍未完成：需要通过无探针新三端组件的统一完整回归、最终UI、新签名分发候选和安装播放、公开下载及官网部署。当前Native7的系统Disabled空TouchBar审计失败未豁免；用户NAS、人工听音与朗读VoiceOver仍未验收。

## 此前候选记录（保留原失败与当时状态）

2026-10-04 当前保存修正将后台写入同步登记到既有有序队列，显式flush等待此前全部提交，保留95% / 会话 / 失败回滚条件。原AppStore14项在SDK27 / iOS27模拟器实际 **14通过 / 0失败 / 0跳过**，包含CI失败的暂停片尾原方法，测试源码未改。播放器长视图表达式拆为画面、生命周期和弹窗三个编译单元，所有修饰器与动作顺序保留；标准SDK27 Mac Release构建exit0。Mac26新CI `37201155076` 的原字幕message表达式仍类型检查超时，分块后的SDK26结果尚待下一提交验证。证据 `.build/AppStoreFlushValidation20261004-r1/{outcome-r2.json,AppStore14-r2.xcresult}`、`.build/CITypecheckFixValidation20261004-r1/body-split-mac-build-r3-outcome.json`。

真机数字探针确认实际音频模块为AVSampleBuffer，原两专项仍 **0通过 / 2失败 / 0跳过**：尾部样本真实入队后数毫秒被flush，两个bounded数字附件均未记录无条件音频Drain入口。该结果不支持此前CoreAudio未知延迟假设；正在查输入结束 / 缓冲关闭分支，原两方法、6秒期限与完成门保持。证据 `.build/Native7PhysicalNativeDrainFileApp20261004-r1/Focused2-r1/`；独立诊断的原stderr全0结果另行保留。

提交 `74e4422` 的CI `37201155076` 最终为失败，独立xcresult确认iOS完整61为 **59通过 / 2失败 / 0跳过**：完整SMB seek0预热和无surface准备后重新附加的实际音频输出等待；旧暂停片尾、自动95%读错控制这次通过，不能据此否认先前失败。两个失败都在实际输出前置门，未到seek0或回滚注错阶段。下一CI启用测试服务的bounded numeric command-handler耗时，原61、样片和期限保持；真实单连接list / 4096字节read / close smoke通过、10对entry / return / MID匹配，服务与临时文件清理。该日志不代表socket发送完成。证据 `.build/Native7CICommitDReview20261004-r1/PLATFORM_FAILURE_REVIEW.json` 和 `.build/SMBFixtureNumericTimingSmoke20261004-r2/ACTUAL_RESULT_READONLY_CONTINUATION.json`。

2026-10-04 提交 `38e187d` 的 CI `37200022745` 已结束，整轮失败。共享测试与 Mac / ARM64 Simulator / iOS Device 三平台构建均通过；Mac26.6.2 / Xcode26.6 / SDK26.5 在字幕导入回调类型检查超时，尚未执行播放。iOS完整61的原始日志记录58通过、3失败、0跳过：暂停片尾已看状态、真实尾部读错撤销的等待、完整SMB seek0预热。原始失败与附件保留，不能据此记作全部通过。证据 `.build/Native7CICommitCReview20261004-r1/{SNAPSHOT-r4.json,macos26-job-api-r2.log,platform-job-api.log}`。

字幕导入成功回调改为显式 `Result<URL, Error>` 私有方法，保留原成功动作、允许类型与修饰器顺序。本机标准 SDK27 / ARM64 Release 构建实际exit0；SDK26的完整编译与播放仍等待修正提交CI，语法parse不是其替代。证据 `.build/CITypecheckFixValidation20261004-r1/file-importer-mac-build-r2-outcome.json`。

2026-10-04 Native7 / 源码 `987ce91` 的完整移动播放结果已闭合：iOS27 与 iOS26.5 模拟器各 **61通过 / 0失败 / 0跳过**；自有26.5实际恢复Shutdown。USB iPhone12Pro / iOS27.0.1 经真实局域网SMB完整61为 **59通过 / 2失败 / 0跳过**。两项失败是重播第二次完成、暂停与2倍速后跳到片尾的自然完成；原6秒期限保持，其他59项（含半速、SMB、4K和已看回滚）通过。全部方法身份、源码 / 输入 / 产品 / 完整原配置和严格签名前后检查通过。证据 `.build/NativeCoreAudioClockCadenceMobileAcceptance20261004-r1/{Full61-iOS27-r1,Full61-iOS26.5-r1,Physical61-r4}/outcome.json`；真机小复核 `Physical61-r4/FAILED_CASE_READONLY_REVIEW.json`。

同一生产App另加已有bounded生命周期记录与失败附件的独立诊断，仅两测试文件setup / teardown增加记录，原两方法、断言与期限保持，实际专项 **0通过 / 2失败 / 0跳过**。1115与1398条事件均无淘汰；两个倍速playing-seek11后仅179 /195ms便出现native EOS，没有新的目标normal时钟，停止input仍是5.932315 /0.678776旧位置。重播第一次虽原门通过，但仅70ms即EOS，不能据此认定片尾真实呈现。原生排空 / 输入统计时序仍待验证；不以时长、seek估值或延长期限绕过完成门。证据 `.build/Native7PhysicalSeekTrace20261004-r1/Focused2-r1/ACTUAL_TIMING_REVIEW.json`。

Native7 当前UI已完整实跑：Phone、Pad各原19项 **18通过 / 0失败 / 1自然跳过**，真实系统减少透明度另各 **1通过 / 0失败 / 0跳过**并恢复设置；Mac原19项 **17通过 / 1失败 / 1自然跳过**，真实减少透明度另 **1通过 / 0失败 / 0跳过**，恢复key不存在 / API false。Mac唯一失败仍是未过滤审计的系统Disabled空TouchBar；没有豁免。所有源 / 输入 / 产品 / 配置 / 严格封签守卫闭合。证据 `.build/NativeCoreAudioClockCadenceUIAcceptance20261004-r1/FINAL_MOBILE_UI_GUARD_CLOSURE.json`、`.build/NativeCoreAudioClockCadenceMacUI20261004-r1/{UI19-Exports-r1,Reduce-ReadOnly-r1}/`。这些结果绑定 `987ce91` 的界面源码。

公开技术组件 `vlckit-8f5ce02-aether-20261004` 已发布；新ZIP、665MB基础源码、精确提交扩展均匿名完整流式下载，长度与SHA256匹配，未发布App。提交 `987ce91` 的 CI `37198775841` 整轮失败：共享通过，Mac26构建在PlayerScreen退出异步表达式类型检查超时，平台任务的Mac构建通过、Simulator误构建x86_64而不能链接ARM64组件。两项构建问题分别以独立退出清理方法、显式Simulator ARCHS=arm64修正，等待新提交CI实证，不能记作Mac26播放通过。

正式 `987ce91` iOS Release归档实际构建exit0，独立34项检查通过：0.1.0/build1、最低26、iPhone/iPad、ARM64、真实Native7 UUID、严格签名 / profile / dSYM / 许可证 / 无夹具；这是开发签名归档，非公开iOS分发。Mac ARM64候选已Developer ID签名、App与DMG两项公证Accepted、票据有效，真实只读挂载卷AetherFilm和内容检查通过；32,380,078字节、SHA `30e45d1b…`。宿主Gatekeeper有既有security override，不代替VM安装与播放；未发布App，后续源码改动须新候选。证据 `.build/FinalNative7IOSRelease20261004-r1/archive-inspection.json` 和 `.build/FormalNative7MacRelease20261004-r1/MOUNT_INSPECTION.json`。

2026-10-04 当前 Native7 的原完整 Mac53 在 macos27 / ARM64 虚拟机实际 **53通过 / 0失败 / 0跳过**，exit0。三平台 CoreAudio 真实输出报告周期从1000ms改为100ms；原正常时钟、片尾11.9秒断言、30秒上限及其他用例全部保持。半速最后normal12.276241、input12.25、实际EOS24.935秒，真实normal周期中位107ms；音视频349 /562、完成一次且无错误。完整53个case身份、原MTC与XCTest配置、源码 / Products / 输入前后守卫、严格封签及自有执行器清理均通过。原Native6失败保留在下方历史记录。证据 `.build/NativeCoreAudioClockCadenceMacVM20261004-r1/Execution-r1/outcome.json` 和 `ReadOnlyReview-r1/ACTUAL_REVIEW.json`（SHA `3f411873…`）。

Native7 三平台增量C对象和六个wrapper目标均实际exit0，最低26.0 / SDK27.0 / ARM64保持；8项补丁、12个受影响源文件和对应源材料核验通过。Root实际整合12个材料文件，并核对74个编译App / 测试 / 夹具路径一致，证据 `.build/Native7FormalIntegration20261004-r1/RESULT.json`。新三切片ZIP为68,726,561字节，SHA `f629ad7f…`。完整全新可移植源重建未执行。新版iOS模拟器与真机播放、Mac26 CI、正式分发仍需各自实际结果。

最终 Native6 r2 的完整UI与减少透明度验收已闭合：iPhone和iPad各原UI19 **18通过 / 0失败 / 1自然跳过**；Mac原UI19 **17通过 / 1失败 / 1自然跳过**。唯一失败为原未过滤描述审计报告的系统Disabled空TouchBar；未删除断言、筛选或给予豁免。三端随后真实开启系统减少透明度，原专项各 **1通过 / 0失败 / 0跳过**，原系统设置全部恢复。完整case、源码 / 产品 / 输入 / 配置 / 严格封签守卫及自有执行器清理已闭合，11张关键原PNG保留。证据 `.build/FinalUIReadOnlyClosure20261004-r1/UI_RESULTS_REPORT.json`（SHA `4a3a57f5…`）。这组UI绑定Native6组件；Native7沿用相同SwiftUI和测试源码，但不能将旧结果写作新版运行结果。

最终共享回归实际 **45通过 / 0失败 / 8项SMB3 opt-in跳过**，exit0；原Mac执行器单元测试 **5/5通过**。独立真实SMB3.1.1加密专项 **8通过 / 0失败 / 0跳过**，exit0；97个客户端与97个服务端加密包、明文READ0，真实阻断与错误协议控制通过，自有服务器和临时目录已清理。证据 `.build/FinalNative6SharedTests20261004-r1.log` 与 `.build/FinalNative6SharedAndSMB3Acceptance20261004-r1/ACTUAL_REVIEW.json`。这认证测试服务器，用户实际NAS、人工听音和VoiceOver验收仍待补充。

## 历史候选与原失败记录

2026-10-04 同一最终 Native6 r2 在 macos27 虚拟机的原完整53项实际 **52通过 / 1失败 / 0跳过**，exit65。唯一失败是 `testHalfSpeedNaturalCompletionDoesNotDoubleDrainTime` 的原片尾输出时钟断言：normal11.747092低于11.9秒；其他52项通过，包括真实95%已看持久化后读错撤销。完整产品、源码、原配置与严格签名前后验证通过，执行器清理退出0；该失败仍阻塞播放验收，正在核对实际EOS与输出时序，不放宽断言。证据 `.build/FinalNative6MacPlaybackVMPrep20261004-r1/Execution-r1/outcome.json`；原完整结果保留在虚拟机 `native6-final-20261004-r2/Mac53-r1.xcresult`。

2026-10-04 最终 Native6 r2 的 iPhone27 原完整UI19实际 **18通过 / 0失败 / 1自然跳过**，exit0；唯一跳过是系统尚未开启减少透明度的原条件，另行真实系统设置专项与iPad / Mac完整UI仍在执行。全部19项身份、原断言和期限保持，产品 / 源码 / 输入前后守卫通过。证据 `.build/FinalNative6PhysicalAndUIAcceptancePrep20261004-r2/PhoneUI19-r1/Exports/case-results.json`。

2026-10-04 最终统一 Native6 r2（SOURCE_READY `35707893…`）同一封签产品，在 iOS27 与自有 iOS26.5 各原完整61实际 **61通过 / 0失败 / 0跳过**、exit0，无Only / Skip过滤。全部方法身份、实际系统 / 设备、源码 / Products / 原RPAC与XCTest配置 / canonical守卫、前后严格签名通过，MTC / background UI / GL打印均0；26.5实际恢复初始Shutdown。新增真实来源失败控制已证明：实际normal输出11.413763秒自动95%、fresh同源input活动、磁盘读回true、同一HTTP3 / 当前唯一UUID完整391字节真实读失败、磁盘读回false且续播11.533秒保留。应用完成0、validator1；native reason1出现并被拒绝，不冒称native无EOS。原60项保持，先前新增不适用前置条件失败保留。Mac与物理设备 / UI / 最低Mac26 / 分发仍须独立证据。结果 `.build/FinalNative6AppCandidate20261004-r2/sim/Results-iOS27-full61-r1/outcome.json`（SHA `ad01c722…`）、`Results-iOS26.5-full61-r1/outcome.json`（SHA `16261d11…`）；专项全文复核 `.build/FinalNative6OutputFaultReadonlyReview20261004-r1/ACTUAL_CONTROL1_PROVENANCE.json`（SHA `c8a06b11…`）。

2026-10-04 统一 Native6 第一轮 iOS27 原完整61实际 **60通过 / 1失败 / 0跳过**、exit65。原54与六个持久化 API 控制全部通过；唯一新增 `testConfirmedSMBSeekAutomatic95WatchedRetractsAfterRealTailReadFailure` 在真实seek11.2后健康确认阶段超时，未进入disktrue / 注错 / diskfalse。独立新增专项同样 **0通过 / 1失败 / 0跳过**；两次完整 case身份、实际设备 / 系统、源码 / Products / 原配置 / canonical守卫、前后严格签名保持，MTC / background UI / GL打印均0。新增测试将demux input>=95%当成实际输出播放进度的前置要求，超出了生产确认合同；片尾阻断后的seek缓冲也未产生新normal / input。该新增场景正在按真实normal输出95%、同源输入活动及真实读失败修正，原60项不改，原失败不豁免。证据 `.build/FinalNative6AppCandidate20261004-r1/sim/Results-iOS27-full61-r1/outcome.json`（SHA `9b784837…`）及 `Results-iOS27-control1-r1/outcome.json`（SHA `a291c4cf…`）。

2026-10-04 用户在 macos27 虚拟机完成系统 UI 自动化认证后，同一窄 UI 产品的减少透明度第三次专项实际 **1通过 / 0失败 / 0跳过**、exit0，用例7.012865秒。系统设置从 key不存在 / API false 切换为true，并在收尾恢复 key不存在 / API false；完整原日志、51项导出附件、运行前后产品 / 配置 / 签名检查保留。前两次认证初始化超时结果仍保留，第三次通过不替代最终 Native6 统一源码验收。证据 `.build/NativeSMBAXTypeUIExecution20261004-r2/MacReduceReview-r3/`。

2026-10-04 最新窄 UI 修正复测：Mac 原完整19实际 **17通过 / 1失败 / 1自然跳过**，唯一失败仍是未过滤的系统空 Disabled TouchBar 描述审计；SMB 原专项已 **1通过 / 0失败 / 0跳过**。iPhone / iPad 各原完整19 **18通过 / 0失败 / 1自然跳过**，真实系统减少透明度各另行 **1通过 / 0失败 / 0跳过**，设置恢复。Mac 同产品的减少透明度两次初始化在启用 automation mode 时超时，均未进入用例，不能算功能失败或通过；原单 key 不存在、API false 均已恢复。原 full19 与失败结果保持，仍需最终统一源码验收。证据 `.build/NativeSMBAXTypeUIExecution20261004-r2/MacUI19Review-r1/Exports/case-results.json`、`MacSMB1Review-r1/Exports/`，及 `.build/NativeSMBAXTypeUIExecution20261004-r1/PhoneReduce-r2/Exports/`。PhoneReduce 首次旧依赖数量检查失败保留；续检独立严格验证全部源码、已知 local refs 和原 remote inventory，没有改 canonical metadata 或将旧失败记作0。

新增自然 SMB 已看回滚控制在 iOS26.5 实际 **0通过 / 1失败 / 0跳过**：30秒健康阶段超时，尚未注入读错误。真实 held391字节使 input 停在10.43091秒，低于新增 compound gate 的95%输入要求；clock 继续至16.065189，不能用它冒充该输入条件。实际并非从未自动已看：seq383在23.5274秒以 accepted/running normal11.565、video316 / audio540更新，随后92条观测为true；但未进入显式 disktrue读回与注错阶段。完整61方法构建、原 RPAC / XCTest 配置、14严格签名与运行前后 source / Products / config / canonical 守卫通过，原 Shutdown 状态已恢复。该执行没有证明自动true后的回滚分支，也未重复在27上运行同一不可达前置条件。证据 `.build/Native5WatchedRealFaultAppCandidate20261004-r2/sim/Results-iOS26.5-integration1-r1/outcome.json`（SHA `7843535f…`）。原54与新增六个 API 控制未改；另行可达的真实播放阶段控制仍在准备。

独立 Native6 真音频渲染时钟候选已通过原半速专项 **1通过 / 0失败 / 0跳过**、exit0：原30秒上限、21.201736秒防提前结束下限和11.9秒片尾断言均保持。12秒影片0.5×实际EOS24.568336秒，最后normal12.072098、input12.065448、displayed349 / audio562、应用完成一次；242个真实normal回调的稳态周期中位0.099999625秒，最后normal到EOS仅0.013717916秒。879条事件无丢弃，14个runtime映像严格封签和源码 / Products / 配置 / canonical守卫均通过。三端组件及统一源码完整回归仍待完成，不用这次单项替代旧Native5完整失败。证据 `.build/Native6ClockCadenceSimApp20261004-r1/ACTUAL_HALF_CLOCK_REVIEW.json`（SHA `f2b25243…`）。

独立已看会话归属修正，在iOS26.5和27各专项 **10通过 / 0失败 / 0跳过**、exit0。四个原SMB / 健康95 / 已有记录 / 手工标记场景加六个真实AppStore与磁盘控制全部通过；健康播放分别在真实normal11.564411和11.570077自动标记，暂停后重读磁盘true。两次原故障场景都拒绝完成且重读磁盘false，但故障前未出现自动95检查点，因此不能称其已实跑原27的“自动true后故障撤销”路径；该路径需要新增独立严格SMB集成控制。源码、Products、配置、canonical与严格签名保持，原26.5模拟器Shutdown状态已恢复。这不是完整60项或真机证据。证据 `.build/Native5WatchedProvenanceAppCandidate20261004-r1/Results-focused10-iOS26-r1/readonly-watched-review.json`（SHA `08c01b87…`）及 `Results-focused10-iOS27-r1/readonly-watched-review.json`（SHA `4813013b…`）。

统一 Native5 的完整UI19实际：macOS27 **16通过 / 2失败 / 1自然跳过**，iPhone和iPad各 **17通过 / 1失败 / 1自然跳过**；各原case均运行一次，前后runtime库存 / 签名守卫通过。三端另行真实开启系统减少透明度，原专项各 **1通过 / 0失败 / 0跳过**，并恢复原系统设置；Mac原单key不存在且NSWorkspace false→true→false均有实际证据。SMB父标识覆盖子字段，并且Mac原生Disclosure / Switch的value实际为NSNumber而非String。两文件窄候选恢复label标识并正规读取原生数值后，iPad原SMB专项1/1通过；Mac已通过原展开、端口和初始加密断言，继续暴露第105行默认开关点击后未切换的问题，仍待修正。另一Mac失败仍是空Disabled系统TouchBar的描述审计，不过滤。全部旧失败保留，新统一UI矩阵尚未通过。证据 `.build/FinalNative5UIExecutionPrep20261004-r1/UI_GATE_ACTUAL_REPORT.json`、`MacReduceReview-r1/`、`NativeValueProbe-r2/`及 `.build/NativeSMBAXTypeUIExecution20261004-r1/MacSMB1Review-r1/`。

同一统一 Native5 已签 App 在自有 iOS26.5 模拟器的完整54项实际 **54通过 / 0失败 / 0跳过**、exit0；原case身份、实际系统、源码 / Products / 配置 / canonical 守卫、签名及原时限均保持，MTC / background UI / GL打印均0。半速本轮最后normal12.076026、input12.069230、EOS约24.388秒；读错拒绝与既有 / 手工已看控制均通过。仅启动本任务模拟器并在结束后恢复原Shutdown状态。这是26.5的完整模拟器证据，不代表26.0、物理设备或macOS26；下述27的两处真实失败仍阻塞发布。证据 `.build/FinalNative5SimulatorAcceptance20261004-r1/Results-iOS26.5-full54-r1/outcome.json`（SHA `21ce554a…`）及 `Boot-iOS26.5-r1/outcome.json`。

2026-10-04 统一 Native5 当前源码的 iOS27 完整54项实际 **52通过 / 2失败 / 0跳过**、xcodebuild exit65。全部54个原case身份、运行设备、源码 / 整体 Products / 配置 / canonical 守卫、前后严格签名通过，MTC / background UI / GL打印均0。失败一：半速自然EOS约24.295秒及时到达且真实input12.054706，但最后normal时钟11.568169未满足原11.9秒片尾断言；先前独立通过不能替代该失败。失败二：健康播放阶段曾自动95%标记已看，随后真实片尾读取错误拒绝EOS，却未撤销本次自动已看；保留既有 / 手工已看两项控制通过。两处仍待修复，不放宽断言或期限、不删除失败；最低系统、Mac、UI和真机统一验收仍未完成。证据 `.build/FinalNative5SimulatorAcceptance20261004-r1/Results-iOS27-full54-r2/outcome.json`（SHA `9fa71eb6…`）及该目录完整 xcresult / 数值附件。

2026-10-04 最新独立播放修正完整回归：iOS27 Air / Native4 的原50项及新增3项已看控制 **53通过 / 0失败 / 0跳过**、exit0，174.328秒；没有 Only / Skip 过滤，全部case身份、源码 / Products / 配置 / canonical守卫稳定，严格签名通过，MTC / background UI / GL均0。健康95%已用真实normal时钟限制确认进度，保留故障状态的拒绝条件；实际在EOS前自动已看、暂停与磁盘重读通过。Root已将精确通过的 FilmPlayer / EOF 与独立通过的 PlayerScreen 修正合入正式源码，统一源码的其他端回归尚待完成。证据 `.build/Native4QualifiedPlaybackReview20261004-r4/full53-review.json`（SHA `552735d4…`）及 `.build/Native4FormalIntegration20261004-r1/RESULT.json`。

半速自然EOF修正已通过独立真实功能回归：同一12秒样片以0.5×从零播放，修正音频输出计时域后实际EOS约24.57秒；真实输出就绪后22.056秒完成，满足新增独立30秒上限及21.202秒防提前结束下限，片尾normal / input均≥11.9秒、音视频继续增长、同一engine仅结束一次且无错误。新增case实际 **1通过 / 0失败 / 0跳过**、exit0；461条事件、219条观测、前后严格签名和源码 / Products / 配置守卫通过。Root已精确合入这项测试，原53项及期限未改，旧60秒只读诊断不加入正式功能套件。三平台C切片及六个wrapper目标已实际构建通过；统一Native5 App的完整54 / 46及UI验收仍待执行。证据 `.build/NativeHalfSpeedEOSRegression20261004-r1/ACTUAL_FUNCTIONAL_REVIEW.json`（SHA `e4c85e2f…`）、`.build/Native5HalfSpeedFormalIntegration20261004-r1/RESULT.json` 与 `.build/NativeAudioOutputDomainCandidate20261004-r1/THREE_SLICE_READY.json`。

原半速失败保留：12秒样片以0.5×播放，输出在约23.6秒停止增长，48.419秒才回调无错误EOS；705条事件和585条观测完整保留。旧诊断执行1/1通过只代表测量完成，不代表功能验收通过；未放宽原30秒或6秒门。证据 `.build/Native4NaturalHalfRateEOFDiagnostic20261004-r1/actual-review.json`（SHA `d025c3b8…`）。

Mac Native4 原完整42实际 **41通过 / 1失败 / 0跳过**、exit65；失败的原seek0等待夹具在1.156秒已有实际running时钟、输入和新增音视频，提示据此清除。当前未传输seek8资格修正在iOS完整53通过，仍需Mac统一源码回归。后续独立SMB标识候选UI19为 **5通过 / 13失败 / 1自然跳过**；另一Apex自动化在本轮启动38秒后进入，真实日志记录其窗口打断，SMB用例尚未进入表单即前景门失败，不能据此判断modifier修正。首次审计在重叠前仍报告空Disabled TouchBar。全部失败不删、不过滤，后续独占验收待执行。证据 `.build/Native4MacPlayback42Acceptance20261004-r1/ACTUAL_PLAYBACK42_REVIEW.json` 与 `.build/SMBNativeControlIdentifierUI19Acceptance20261004-r1/`。

2026-10-04 独立控件隐藏修正已通过实际验收：仅 `PlayerScreen` 两处改为条件渲染，移除隐藏时的原生控件树；原 UI 方法、断言、期限和夹具未改。iPhone 与 iPad / iOS27 各完整19项均 **18通过 / 0失败 / 1自然跳过**，随后通过真实系统设置开启减少透明度，各专项 **1通过 / 0失败 / 0跳过**并恢复设置。四次 xcodebuild 均 exit0，源码 / Products / 配置守卫稳定、严格签名通过，MTC / background UI / GL均0。Root实际查看隐藏、暂停恢复与系统减少透明度截图。证据 `.build/NativeControlsVisibilityIOSAcceptance20261004-r1/ACCEPTANCE_READY.json`（SHA `0f0b19ec…`）。这是该修正的独立验收，不能替代统一源码回归、真机和Mac验收；下方原失败保留。

同日独立播放候选 focused6 实际 **5通过 / 1失败 / 0跳过**、exit65：原源故障 / 健康完成、真实阻断目标的等待提示、重新加载的已有已看记录与播放期间手动标记保留均通过。等待用例实际 seek8，真实现有 HTTP Range及未完成读请求完整覆盖尚未传输的目标帧；附件明确记录既有请求与 fresh请求为空，不要求播放器必须另建HTTP请求。唯一新健康95%自动确认控制在原30秒期限内未通过，正在加只读观测定位；不称完整53项通过。证据 `.build/Native4QualifiedPlaybackCandidate20261004-r2/sim/Results-focused6-r1/outcome.json`（SHA `945aaaad…`）。停止阶段生产确认守卫仍待这项健康控制和最终完整回归验证，原 focused3 的额外 fresh-GET 断言失败也保留。

同日追加清理三个旧 device contrib / 静态链接目录：原分配5375279104字节，实际空闲增加5284077568字节；85份原构建诊断共6713573字节按相对路径与SHA保留。728项 Native4 历史inputPins无目标引用，当前App源码、mirror、canonical和构建输入守卫前后通过，Lua未变。原设备端contrib树无法原地续建，重建需使用保留的源码归档；当前Native4 objects / 框架 / App、样片及原失败结果未删除。证据 `.build/Native4RetiredDeviceContribCleanup20261004-r1/RESULT.json`。

2026-10-04 最新真机完整运行：同源 Native4 的 USB iPhone 12 Pro / iOS27 + 真正局域网 SMB2 夹具，原完整50实际 **49通过 / 1失败 / 0跳过**、xcodebuild exit65。全部原case身份与物理设备匹配；源码、Products、原配置和canonical依赖保持，前后严格签名通过，MTC / background-layer / GL固定打印均0。真实SMB冷续播、片尾健康完成 / 读错、20次seek / 重开、4K及原fromZero回退场景通过。唯一 `testUIInfiniteHeldSourceWaitsWithoutEOSAndCloseClearsStatus` 的提示为nil，原要求仍等待的断言失败；尚待对照真实目标时钟 / 输出判断是否提示过早消失或夹具未保证目标仍阻塞。原失败不删除、不过滤或放宽期限。证据 `.build/FinalNative4PhysicalAcceptance20261004-r1/Results-full50-LAN-r1/outcome.json`（SHA `30c64c26…`）。该夹具不是用户实际NAS，不代表人工听音、完整UI、最低26或公开分发验收。

2026-10-04 当前正式 App 构建与封签：同一次 Native4 源码快照（SOURCE_READY `2cf9983d…`）的 Mac、iOS Simulator、iOS Device 三次 build-for-testing 均 exit0。三端严格签名已完成，原标识 / 权限保持，两份内核均与实际组装产物在非签名字节上相同。Device / Sim各14实际runtime images，Mac16 / UI compiled19；Mac单ARM64 FAT Runner仅签名尺寸字段变化已与真实Xcode模板核对，其他容器与全部原非签名字节保持。原Device零对齐、Sim identifier、dSYM枚举和Mac FAT尺寸检查失败均留存，由独立后处理收尾，未重建或替换产品。第三方源码归档实际流式核对原主资产、三源归档、68项 contrib 归档 / sidecar、八项小输入和 Lua 均通过，未解压大副本。Mac新包传入Tart macos27后全部inventory、方法与签名验证通过。证据 `.build/FormalNative4AppPostSealContinuation20261004-r2/`、`.build/Native4MacFinalGateFinish20261004-r1/`、`.build/Native4VMFinalAcceptance20261004-r1/`。旧十项自建产物共4078489600 allocated bytes已清理，四个原配置与日志 / inventories / 失败结果保留，实际空闲增长3792154624字节；原Native3归档退休后不能直接重跑其历史构建guard，当前Native4输入保持。清理记录 `.build/FinalCleanupExecution20261004-r1/`。

同源 Simulator 完整50实际 **48通过 / 2失败 / 0跳过**、exit65；除了真机同一等待提示用例，`testRealSMBNearTailReadFailureRejectsCompletion` 的 `isWatched=false` 断言失败，EOS和源故障验证仍正确拒绝完成。原日志、断言和期限保留，停止阶段的确认进度候选尚未实际通过。证据 `.build/FinalNative4SimulatorAcceptance20261004-r1/Results-full50-r1/outcome.json`（SHA `ce0f976b…`）。等待用例的真实seek0已恢复输出，提示按真实进度消失；独立夹具候选改为阻断4秒后的字节并跳至未传输的8秒目标，还需实跑证明。

同源 Mac 独占 UI19 实际 **16通过 / 2失败 / 1跳过**、exit65；全部19项活动、23张PNG和完整失败结果逐文件校验并保留。SMB高级选项默认点击落在原生AX标题中点，仍折叠，后续端口和加密操作未执行；描述审计唯一issue为Disabled空TouchBar，不过滤。原日志没有其他App抢焦点的证据；减少透明度因系统实际未开启自然跳过，专项仍待执行。证据 `.build/Native4MacUIResultsReview20261004-r1/REVIEW.json`（SHA `6526cc5a…`）。后续Mac完整42启动前发现另一项UI自动化正在运行，按用户手动错开安排等待，未并行抢占虚拟机。

同源新 iPhone Simulator UI19 实际 **17通过 / 1失败 / 1自然跳过**、exit65，精确19case、iOS27、前后源码 / Products / 配置和严格封签均验证；MTC / background UI / GL打印均0。唯一隐藏控制用例中，正常视频继续推进21.042→22.125秒，截图已经没有按钮，AX仍保留非零frame的playPause；原 `showPlayerControls` 在发出surface tap之前查询 `isHittable` 时失败。独立条件渲染候选会移除实际隐藏的控制树，原断言和期限保持，尚未实跑。自然Reduce Transparency跳过仍须独立专项，原outcome中该字段为false并不取消此门槛。证据 `.build/Native4IOSUI-iPhoneFull-r1/outcome.json`（SHA `ff1bc45e…`）及 `FailureAnalysis/review.json`。新UI正常封签21个可执行映像，5个链接对象未改；与播放包是同源的新构建，不能称复用其App二进制。

最低系统分支首次实际 smoke：使用本任务自建 iPhone Air / iOS26.5，当前 Native4 原 `testCommonContainersProduceVideoAndAudioOutput` **1通过 / 0失败 / 0跳过**、exit0，四种原容器实际输出通过；前后源码 / 已签Products / 原与运行配置保持，严格封签通过，MTC / background UI / GL均0。初次boot等待因实际CoreLocation数据迁移超时，原日志保留；后续bootstatus实际0后才执行测试。证据 `.build/Native4MinimumIOS26Smoke20261004-r1/outcome.json`。这是一项原样片的iOS26.5运行证据，不能称26.0、完整回归、Mac26或物理设备验收。

2026-10-04 Native4正式组件实际完成：Mac / Simulator / Device各四C增量对象及归档16阶段均exit0，七处full payload与仅core TLS110替换之外的内容和顺序保持。三平台wrapper共六target均exit0，分别平台1 / 7 / 2、ARM64 / min26 / SDK27、302个模块定义；原139 / 139 / 141条空成员警告与其他编译警告完整保留。实际三slice XCFramework组装exit0，68723863字节zip的SwiftPM checksum为`2b8a0bd97b8a9022d8a94843eb4268e243edf68f70107e2ce68e76347751d753`，三原框架前后相同。正式Bridge已从固定输入连续两次生成22 / 22相同，四个typed callback的可选调用 / selector及getter / sequence类型在当前Mac / Device / Simulator三消费者实际编译链接均exit0，未启动App或设备；旧五平台证明归档为历史。证据 `.build/Native4ObjectsPrep20261004/`、`.build/Native4WrapperPrep20261004/`、`.build/Native4Assembly20261004/`、`.build/Native4Consumers20261004-r1/`。自有wrapper中间体 / 缓存 / 链接副本以及消费者571822080字节scratch已清理，原日志、源码和证明保留。当前新组件的完整App回归与原停滞恢复仍待实测；远程binary资产尚未发布。

2026-10-04 真机4K匹配对照完成：只修正静态链接日志识别，接收模块libvlc且源文件为`/modules/codec/videotoolbox/decoder.c`、函数为OpenDecoder / DecodeBlock的原消息；原4K方法、三秒期限和样片不变。USB iPhone 12 Pro / iOS27实际 **1通过 / 0失败 / 0跳过**、xcodebuild exit0；1.186秒已有视频decoded / displayed 27 / 27与音频106，VideoToolbox selected、acceptedFrame及capability均为true。测试前后外层与nested严格签名、源码 / 配置 / cache守卫通过，原MTC / GL打印均0。证据 `.build/PhysicalDeviceNative3Acceptance20261004-r1/Results-4k-static-evidence-r2/`。该单项不改写前轮39 / 1 / 10，不代表SMB、完整UI、人工听音、26运行或分发通过。

2026-10-04 新真机结果：USB iPhone 12 Pro / iOS27 上，native3 原完整50方法实际 **39通过 / 1失败 / 10跳过**，exit65；十项SMB因未注入真机可达的fixture bootstrap自然跳过，不能称完整通过。四项原本地跳转状态测试全部通过，包括暂停8秒的新input7.997333 / normal7.966667及显示30→34后清除状态且仍暂停。唯一4K HEVC用例已有实际视频和音频输出，但VideoToolbox证据门未满足；原三秒门和两个失败记录保持。当前静态内核的模块名为libvlc，旧诊断只接收videotoolbox，需匹配控制验证是否漏记，尚未认定硬解通过。构建后清理nested dSYM曾破坏外层资源封签，该失败保留；只重签最外App后11个nested及外层严格验证均0，原非签名代码、两份内核、全部源和配置保持，测试前后校验均通过。证据 `.build/PhysicalDeviceNative3Acceptance20261004-r1/Results-full50-r1/` 与 `.build/SeekPausedPreviewIOSDeviceAppSealRepair20261004-r1/Results-r1/`。本轮不认证听音、完整UI、26运行或分发。

同日固定缓存条件的原生C机制对照已实际执行：原版三次cache miss均满足非EOF / 未读128字节 / 实际上游poll条件，原期限内零返回字节；四源候选三次均产生新Range0、实际poll及正确32字节，十三项候选控制全部通过。普通EOF、短响应从8192恢复、缓存内回退、部分8字节读取和kill控制保持；24项主要原版 / 候选预期均符合、原输入守卫全真。但三次no-drain竞态控制实际也通过，推翻预设的该负向假设，原runner仍exit1 / allExpected=false，未修改其结果。该对照仅证明固定条件的底层机制，不是原App六秒偶发失败的复现或恢复；尚未编入App。证据 `.build/HeldNativeIOMechanism20261004-r2/Results-r2/`、`RESULT-ROOT.json`，第一轮资格错误完整保留。

2026-10-04 用户确认 macOS 首版只支持 Apple Silicon（arm64）。当前 macOS 构建、测试与分发验收不再包含 Intel；下面已有的 universal / x86_64 记录作为历史证据保留。最低 macOS26、iOS / iPadOS26 与真机、原生 UI、真实 SMB 播放验收不变。

当前处于执行验收阶段，尚未发布。构建和部分协议 / 播放测试已有真实结果；失败、未测和未发布分别记录。每项执行后记录命令、环境、结果、证据文件和 commit。

2026-10-04 新执行结果：iOS27 ARM64 native3 候选的原四项跳转测试实际 **4通过 / 0失败 / 0跳过**，原断言和六秒期限保持；暂停到8秒出现实际input7.997333、normal7.966667及新画面后才清除状态，之后仍暂停。同一签名App完整50项实际 **49通过 / 1失败 / 0跳过**（正式44项映射为43/1），唯一失败仍是 `EOFPlaybackTests/testTailPhaseRejectsRealPlaybackFromZero`：原六秒内视频18 / 音频107不增、无新input，正常时钟停在2.878527。原MTC设置保留，固定MTC / background-layer / GL打印均0。证据 `.build/SeekPausedPreviewIOSSimulatorAppStrict4Stage20261004-r3/Results-{strict4,full50}-r1/` 和 `.build/SeekPausedPreviewIOSSimulator{Strict4,Full50}Review20261004/`。完整50中的等待提示诊断不能替代该恢复失败；全部原始失败保留。

随后同一冻结App的两次原单项及一次未过滤完整50回归均通过；最新全组为 **50通过 / 0失败 / 0跳过**。三轮被动线程采样的身份与时间检查通过，但原目标在观察期间已有真实回退及新输出，均为NO_STALL / INCONCLUSIVE，不能宣称修复此前停滞。原失败的HTTP读取起点126134，三轮通过的读取起点6428；相同held391字节不能证明相同缓存历史。原代码、样片、六秒断言和Products均未改；证据 `.build/HeldNative3PassiveDiagnostic20261004/RESULT.md` 与 `Results-{r1,r2,full50-r3}/`。该偶发失败仍待固定缓存条件的底层机制验证。

同日Mac27虚拟机的native3完整UI19实际 **11通过 / 7失败 / 1跳过**，exit65，原plist、断言和检查器未过滤。四项失败的原日志出现外部Apex UI窗口干扰；可访问性审计另有Code-56超时，清除记录另有AX未加载超时，其余失败原因待独占复测核实。原SMB失败的事件和截图另确认0.08归一化点击落在原生箭头外；当前测试改为该元素的标准 `click()`，保留可命中检查、value1和五秒期限。新测试产品已实际编译、链接和签名，19方法及未过滤配置保持；10个ARM64 Mach-O、8个严格签名bundle核验通过，App和内嵌框架保持原字节，仅本轮136880416字节中间产物已清理。原验证工具不支持单ARM64切片FAT Runner而退出1的记录保留，独立切片验证随后退出0；证据 `.build/MacNative3UIRunner20261004-r3/`。独占复测仍待完成，不据此改写原失败。减少透明度项因真实系统API为false按原方法自然跳过，仍需实际开启该设置的验收。运行App确实加载owned native3框架，运行前后代码和签名保持。原运行证据 `.build/MacNative3UIAcceptance20261004/`；原CLI参数被拒的exit64单独保留。该UI运行仍为失败门槛。

iPhone原生内核基线编译在同日实际完成，compiler及nm均exit0、nm stderr为空，6269个native成员均为ARM64 / 平台2 / 最低版本≤26，302个生成模块全部定义，rav1e和GSM真实编译；原r1失败及原始输入保持。证据 `.build/NativeSourceBuildIOSDeviceArm64-r1/Results-ios-device-r2/`。三项暂停修正随后使用真实Device编译参数限定重编并重合归档，14个实际步骤均exit0；完整归档6269项中另外6266项、核心178项中另外175项的内容及顺序保持，839项受保护输入前后相同，新归档SHA256为 `367b2a928f69ad0c3421c7b3cc9f8f672a3a648c747827f19ffdd5e0869fe855`。证据 `.build/SeekPausedPreviewIOSDeviceObjectsCandidate20261004-r1/Results-r1/`。wrapper和实际iPhone安装播放尚待验收；上述编译不代表真机或分发通过。

Device native3 wrapper随后实际构建通过，Static libVLC / VLCKit两个target均exit0；框架为52874192字节、arm64 / iOS平台2 / 最低26 / SDK27，SHA256 `05a8a31bcf6a1d0e5e3b3a3509c9185530de4bb1a1d23868a823eab93b4480aa`，302模块及真实TEXT定义核验通过。原归档与860+1源、63输入保持，本轮中间文件、缓存与静态链接副本已清理；141条空成员警告和两条wrapper警告完整保留。证据 `.build/NativeWrapperIOSDeviceArm64PausedNative3-r1/Results-wrapper-device-native3-r1/`、`.build/SeekPausedPreviewIOSDeviceWrapperReview20261004/`。仅wrapper通过，尚未签名App、真机安装播放或分发验收。

最新 Mac 暂停预览候选（2026-10-03）：在已验证的input / video-output修正之上，decoder限定重编及符号 / 归档八个实际阶段均退出0，其他对象保持；两个wrapper实际target均退出0。新签名产品副本运行四项原始 SeekUIStatusPlaybackTests，实际 **4通过 / 0失败 / 0跳过**，原断言、helper、样片与六秒期限未改，全部受保护源文件与产品前后相同，原始MTC / 后台NSView.layer / 固定GL打印均0。暂停跳转8秒的实际input为7.997333秒、normal为7.966667秒；视频计数32→40后，只有真实normal送达才清除提示，提前到目标的getter和seek结束回调没有清除提示。后续至5.498秒仍暂停、无待处理请求，视频40 / 音频106保持稳定。提交后暂停 / 改速、播放中连续同 / 不同目标及停止 / 换片三项也通过，停止后的旧状态无复活。Root复核实际结果、签名代码不变与具体输出；独立复核完整读取八份附件（trace262/536/512/293，UI40/55/64/108），事件丢弃0，normal与input源 / 送达配对逐条一致。证据 `.build/SeekPausedPreviewDecoderMacObjectCandidate20261003-r2/Results-ih4o7ewp/`、`.build/NativeApertureCandidate20261003/WrapperArm64SeekPausedPreview-r3/Results-wrapper-seek-preview-r3/`、`.build/SeekPausedPreviewDecoderMacProductsCandidate20261003/Results-mac-strict4-r1/`、`.build/SeekPausedPreviewDecoderMacRuntimeReview20261003/`。此结果仅覆盖Mac27 ARM64该候选和原四种场景，未覆盖所有暂停连续flush交错、iOS、最终App、完整UI、最低26与分发；旧native2两项失败、getter探针失败和正式36/36、43/1证据均未改写或豁免。

最新正式结果（2026-10-03）：sample-buffer后端、跨显示队列oracle与完整来源回零控制已合入，同一次冻结的新 macOS 完整 **36/36、0失败、0跳过**；iOS 27 完整 **43通过 / 1失败 / 0跳过**。原 Main Thread Checker 保留，Mac 原始 MTC / NSView.layer / 固定 GL 打印均0；iOS 唯一from2 held-source负向再次发生零新输出 / 无正常running点，旧单次start2通过不能称可靠修复。证据 `.build/FormalVerification20261003-Final36-44/Results-{mac,ios}-full-r1/`、`.build/FormalVerificationFinal36-44IndependentReview/`。

公开格式诊断实际120次成功得到H.264 320×192 / 缺clean-aperture / PAR1:1，输入样片与VT会话为320×180；正常三截图有窄侧边黑条，字幕正确但比例验收未通过。原早期M1健康来源放行候选的正控与恢复各1/1，同engine、唯一seek、真实391字节返回后1.187秒继续输出。但该轮blocked期间已播放缓存+100帧/+334音频，**未复现旧停滞，不能称旧失败已恢复**。这两个实际单项不替代正式完整回归。证据 `.build/SubtitleFormatMetadataExecutionIndependentReview/`、`.build/EarlyHeldSeekZeroRecoveryCandidate20261003-r1/Results-ios-{positive,recovery}-r1/`。当前完整UI、真实设备、视频比例修复与分发仍待完成；下面保留各阶段原始结果。

补充对照（2026-10-03）：同一真实完整 SMB 样片从实际 2 秒段继续至 normal 2.866667 秒后，公开 seek0 的单项匹配对照 **1/1、0失败、0跳过**；2.300 秒内同 engine / generation 有 normal 和 input 双回退、当前 running 2.000076 秒、新40视频帧与167音频缓冲。seek前服务器已读/发送全部796257字节，seek后没有新HTTP事件；不能推导引擎已消费全部字节，也不证明无限 held-tail 恢复。证据 `.build/CompleteSourceMatchedStart2Control20261003/Results-ios-matched2-r1/`。原正式 iOS43/1 与四条失败断言保留。

可见区域补丁目前仅在独立引擎源码候选中。严格 helper 编译和公开 CoreVideo/CoreMedia 元数据、几何边界、内存分配失败测试已通过；macOS arm64 核心实际源码构建退出0，完整静态归档941713880字节，独立22项核验通过。前两轮wrapper的工具读取和旧部署目标失败均保留；第三轮使用既有nm-classic与26.0目标，StaticlibVLC / VLCKit两个实际构建均退出0，独立复核通过。自有H.264 / ASS窗口随后实际退出0：124个公开CM格式均有有效320×180可见区域，编码尺寸仍320×192，硬件解码属性为1。Root亲看首条、下一条和实际跳转后三张原始PNG，中文字幕正确，内容完整16:9且旧窄黑边消失。原12/6/6/6秒阶段时限、全部stdout / stderr保留。这只验证Mac27的该样片，不代表完整App、八方向、4K或26运行验收。证据 `.build/NativeWrapperPrepReview20261003/IndependentActual-r3/`、`.build/NativeApertureVisualCandidate20261003-r2/Results-118_zrg_/`、`.build/NativeApertureVisualRootReview20261003-r2/`。

另已实际重编原最低27的18个GSM对象并重合完整静态归档：五个阶段均退出0，新18个对象最低11，其余6544个对象逐字节保持，全部6562个对象最低版本≤26；逐对象公开符号也一致，独立复核通过。这是GSM限定重编与重合，并非整份核心重新构建。修正归档随后用于第四轮wrapper，两个target实际退出0，完整独立核验通过；正常H.264 / ASS三阶段画面也实际退出0，Root亲看比例、字形与字幕切换正确，全部观察到的VT会话hardware=1，原日志完整保留。新归档的版本检查与Mac27画面验证不等于26运行验收。最终双端引擎、26环境及分发仍待完成。证据 `.build/NativeGSMMinimumCandidate20261003-r2/Results-w02c851a/`、`.build/NativeWrapperPrepReview20261003/IndependentActual-r4-r1/`、`.build/NativeApertureVisualCandidate20261003-r3/Results-x65j0iyr/`、`.build/NativeApertureVisualRootReview20261003-r3/`。完整新Mac UI19包已准备，实际未执行；最近只读检查VM没有chenxu图形会话，iPhone仍需密码解锁。

跳转提示隔离候选的双端实际构建均退出0；各四项本地测试均为2通过 / 2失败 / 0跳过，暂停后显示统计增加但无新的normal / input回调，实际目标帧仍需验证，提示未清除，原六秒超时保留。连续跳转与停止 / 换片均通过。两项SMB UI测试在Mac为1通过 / 1失败：健康匹配控制通过，挂起尾读场景实际从缓存恢复，因此“必须等待”的新测试假设失败；iOS为2/2，真实无新输出时三秒后等待、关闭取消且状态无复活通过。原正式held用例在该候选的一次iOS单项运行为1/1，真实回退与新输出存在，但无核心恢复修复且可能由缓存可用性决定，不能取消正式43/1历史失败或称稳定修复。候选尚未合入；完整UI与真机仍未验收。证据 `.build/SeekUIStatusRuntimeCandidate20261003/Results-{mac,ios}-{local,smb-ui}-*/`、`Results-ios-formal-held-r1/`。

修正归档的同一冻结App另实际完成H.264 / SRT、WebVTT三阶段检查，各退出0；Root和独立复核均亲看六张原PNG，中文字幕、下一条与跳回同步、完整16:9均通过。SRT公开CM格式124个，WebVTT125个，全部可见区域320×180 / PAR1:1有效，观察到的硬件解码属性均1。证据 `.build/NativeApertureTextSubtitleCandidate20261003/Results-{srt,vtt}-*/`、`.build/NativeApertureTextSubtitleRootReview20261003/`、`.build/NativeApertureTextSubtitleExecutionIndependentReview20261003/`。独立暂停时间探针只增加公开getter及附件，原两暂停用例在Mac和iOS均0通过 / 2失败，原断言与六秒期限未改；getter仍返回旧时间，不能据此清除提示或认定目标帧已呈现。证据 `.build/SeekPausedCoreTimeProbe20261003/Results-{mac,ios}-local-core-time-*/`。

iOS Simulator ARM64 可见区域候选的完整核心编译实际退出0，归档822966120字节、6266个原生对象均为arm64 / Simulator平台7 / 最低版本≤26，302个生成模块均有真实定义。原驱动因输入字节变化退出1，`coreBuildPassed=false`原件保留；独立后置核验检查全部5840项，只发现自有Git索引stat缓存和rav1e vendor压缩容器变化，索引语义、33827个vendor文件内容及其顺序完全相同，其他原件守卫通过。后续Static libVLC、VLCKit两个真实wrapper目标均退出0；独立检查确认新框架arm64 / 平台7 / 最低26、302个模块和公开API有定义、861项输入及57项产物保持。原始两个目标分别有139和1025行编译警告；linker临时代码签名不代表bundle资源封签，原strict检查退出1保留。App实播、真机和分发仍待验收。证据 `.build/NativeSourceBuildIOSSimulatorArm64-r1/Results-sim-r1/`、`.build/NativeIOSSimulatorSourcePrep20261003/IndependentPostSource-r1/`、`.build/NativeWrapperIOSSimulatorArm64Diagnostic-r1/Results-wrapper-sim-r1/`、`.build/NativeIOSSimulatorWrapperPrep20261003/IndependentActual-r2/`。

4K HEVC修正归档候选已完成ASS、SRT、WebVTT三组真实运行，均退出0。Root亲看九张原始自有窗口PNG：中文字幕可读、首条 / 下一条 / 真实跳回正确，内容完整16:9；公开CM格式分别121、121、110次均为3840×2160有效可见区域、PAR1:1，观察到的hvc1硬件会话均为1。每格式六份公开字幕快照一致，原12/6/6/6秒阶段期限与完整原始日志保留。新副本使用标准原生签名，旧编译驱动、签名pilot和kernel拒绝启动失败均保留。只验证Mac27该生成样片，未验最终App、方向、EOS、听音、最低26或真机。证据 `.build/NativeAperture4KStandardSealedRuntime-r5/Results-4k-{ass,srt,vtt}-*/`、`.build/NativeAperture4KRootReview20261003/`、`.build/NativeAperture4KStandardExecutionIndependentReview20261003/`；九图与实际执行链的独立复核通过。

暂停预览核心的两个对象修复已实际重编 / 重合归档，Mac两个wrapper目标退出0，独立测试副本签名通过；原两项严格测试实际仍0通过 / 2失败 / 0跳过，六秒等待未改。新附件已出现目标附近的真实input时间与新的显示统计，保持暂停，但仍缺normal source/delivery配对，UI等待未清除；不能据此宣称预览恢复完成。完整产品 / 源码未变，原始检查器与GL固定打印均0。证据 `.build/SeekPausedPreviewMacProductsCandidate20261003/Results-mac-strict2-r1/`。

iOS新引擎另接入全新ARM64测试副本，18个真实运行镜像的默认签名与strict校验均通过，原全部非签名代码 / 数据 / UUID和旧失败副本保持。原完整44项在已分配iOS27模拟器实际为 **43通过 / 1失败 / 0跳过**，exit65，唯一无限held-tail回零负向仍失败；其6秒采样没有新画面 / 音频，未冒称恢复修复。所有原编译输入、产品、xctestrun / 检查器保持，原始MTC / 背景layer / 固定GL打印均0。此引擎仅含可见区域修复，不含暂停核心候选；最终双端引擎、字幕视觉、真机及26运行未验收。证据 `.build/NativeIOSSimulatorAppIntegration20261003-r3/`，旧余量失败r2保留。

| 当前门槛 | 实际状态 | 待完成 |
| --- | --- | --- |
| 正式 Mac 播放 / 应用测试 | Native4 同源构建及封签通过；历史36 / 36通过 | 新完整42及图形验收 |
| 正式 iOS27 播放 / 应用测试 | Native4 真机LAN完整50为49 / 1 / 0；Simulator为48 / 2 / 0；iOS26.5四容器smoke1 / 1 | 未传输目标等待用例、故障收尾观看确认候选、最终App最低iOS26完整回归 |
| NAS协议 | 共享45通过、8 opt-in跳过；专门SMB3八项均通过 | 真实厂商NAS及iPhone播放验收 |
| 字幕与比例 | 修正归档H.264及4K HEVC的ASS、SRT、WebVTT均有首条 / 下一条 / 跳回三阶段实际画面，Root复核比例和中文字形通过 | 对应最终App、方向、片尾及最低26验收 |
| Mac UI / 可访问性 | Native4 同源 UI19为16 / 2 / 1；原失败完整保留 | SMB原生交互、空TouchBar审计问题、真实减少透明度和VoiceOver验收 |
| iOS UI / 真机 | 同源iPhone Simulator UI19为17 / 1 / 1；物理iPhone播放完整50为49 / 1 / 0，SMB与4K已执行 | 隐藏控制原生AX修正、iPad与真实减少透明度、实际NAS和人工验收 |
| CI与分发 | 3210ab2的历史CI绿色；旧签名DMG证据保留 | 最终源码CI、新签名公证包、安装和公开下载 |

## 按阶段保留的历史证据

已核对的历史 CI 为提交 `3210ab28466b4ba0cb0f109e587892e048002be4` / run `37089277731`：整轮成功，共享 **45/45**、iOS 27 **30/30**，均无失败或跳过，三个平台构建通过。旧 Mac Aqua **10/22**（视频0/0）及物理 Mac **17/22**（三项 GL 断言、两项 held-tail 门控失败）原件保留。后续 CA 候选原完整22项为 **20通过、2失败、0跳过**；正式原 `PlayerSurface` 的独立 SwiftUI 实窗与4K HEVC 已有真实画面、CA输出和 hardware=1 属性证据，当前 host 画面结论以这些新证据为准，最终 App / VM 完整验收仍待执行。

片尾复合 oracle 候选 r3 实跑 **14/14、0失败、0跳过**（九项纯验证、两项真实 SMB golden、三项实际负向），审阅后已窄集成正式代码。当前正式源码同一次冻结的 Mac / iOS 测试构建均成功，macOS 完整 **34/34、0失败、0跳过**，116.911秒；iOS完整为 **39通过、3失败、0跳过**，109.424秒；失败为两项真实SMB片尾复合阶段和fromZero负向场景的实际输出停滞，原件保留。Mac原始日志有一次后台 `-[NSView layer]` Main Thread Checker 报告（两处打印），即使 xcresult runtimeWarnings 为空也不能称无运行时警告。ASS / SRT / VTT 轨道选择已通过，但三格式最新正常自有窗口均无可辨识中文，**字幕视觉验收未通过**。

最新隔离候选验证：改用 Apple 原生 sample-buffer 视频图层后，H.264 的 ASS / SRT / VTT 各自首条、下一条及实际跳转回首条共 **九张正常自有窗口画面**均显示正确、可读的中文字幕，Root 已亲看原始 PNG。每组实际模块选中一次、公开 AVSampleBufferDisplayLayer 挂接、所有观察到的 VideoToolbox 会话 hardware=1；不调用 engine snapshot。此时仍为隔离候选，正式代码尚未合入，4K 及新正式全量回归待跑。另一隔离候选仅修正跨显示队列的片尾证据顺序，iOS 两项真实 SMB golden 加十项纯判定 **12/12、0失败、0跳过**，独立复核完成；实际 release / source fault 后 EOS、validator 和持久化原断言均通过。原正式 iOS fromZero 活跃 seek0 在无限 held-tail 条件下的真实输出停滞仍未解决，旧失败保留。

2026-10-03后续进展：上述原生后端与两个oracle helper已正式合入；held来源错误目标反例从真实2秒段开始，再实际seek0，六秒、两类新输出>5、双时钟/输入回退、同engine与真实pending UUID守卫保留；iOS隔离实跑1/1。另增完整SMB来源活跃seek0控制，iOS隔离实跑1/1，实际输入回退与新视频/音频输出成立；文件在seek前已被预读完整，不能据此证明阻塞来源恢复。新正式Mac36 / iOS44产品构建成功，完整执行待完成；原start0早期seek0在无限阻塞条件下停滞的失败保留，并另准备真实健康放行后的恢复测试。

4K原生候选实际hvc1 3840×2160且所有观察会话hardware=1，初始ASS文字可见。原样式未声明ScaledBorderAndShadow，薄描边截图保留；独立作者样式只加该声明为yes，同一App/引擎代码的正常窗口实际显示清晰黑描边，Root亲看，独立19项检查通过。只验初始字幕，不冒称4K下一条、seek或EOS完整通过。H.264正常画面窄侧边黑条的物理比例仍待公开格式元数据核对。

Mac 原生 context、窄窗、播放器关闭和目录往返专项 **3/3**；原生窗口 / sheet 截图专项 **2/2**，原始浅色、深色窄窗和完整 SMB sheet 图片已由 Root 复核。正式 NativeAccessibilityContext / RootView / 原生截图辅助已整合，最终新 App 完整 UI 仍待完成；本次重启的测试 VM 停在登录窗口，需用户手动登录既有 chenxu Aqua 会话。原未过滤描述 audit 仍因空且 Disabled 的系统 TouchBar 失败，原生 Text + Button 最小基线亦复现；过滤方案未获自动审批，原 gate 保留。iPhone / iPad 历史完整 UI 各18通过、1 opt-in跳过，减少透明度专项各1/1，新表单辅助专项各1/1；最终新 App 全组仍待回归。

SMB3 先前两轮 CLI 各8/8属于历史独立协议证据。新增正式脚本和八项 opt-in 测试已集成，本轮专门正式 **8/8、0失败、0跳过**，独立复核15项检查均通过；实际10条SMB3.1.1连接、客户端与服务器各97个加密帧、0个明文READ及0个畸形帧。普通共享全组实际 **45通过、8项SMB3 opt-in跳过、0失败**；专门加密组已单独运行，不能将默认跳过称已执行。尚未发布；新签名 / 公证分发、真机安装 / 播放、TestFlight 和公开下载待验收。

| 层级 | 场景 | macOS | iOS |
| --- | --- | --- | --- |
| 构建 | 最低部署版本 26；Debug / Release；真机 archive | 当前正式源码 Debug / tests构建和完整34/34通过；此前 universal Release 属旧源码，新Release及签名DMG待完成 | 当前正式Simulator Debug / tests构建通过，完整42项39通过 / 3失败；此前device build与Apple Development archive 57项检查属旧源码 |
| 本地 | 导入、取消、重复、中文 / 空格路径、重启访问 | 待测 | 待测 |
| SMB | 共享 / 目录、认证、中文路径、随机读取、Range、错误密码、超时 / 取消、加密失败不回落 | 当前共享45通过及专门SMB3八项通过，独立复核完成；正式Mac34含20次seek / 重开、复合片尾及实际RST均通过；真实NAS待测 | 本地及3210ab2 CI的历史真实SMB / EOF通过；新增正式iOS42的两项真实SMB片尾golden及fromZero失败；SMB3专组不替代iOS真机或真实NAS |
| 播放 | H.264 + AAC MP4；HEVC MOV；MPEG4 + MP3 AVI；多轨 MKV；实际画面 / 音频输出 / 时间推进；4K HEVC | 正式Mac34四种容器与4K实际输出通过，0 GL framebuffer断言；原surface实窗及4K像素 / hardware=1另有证据；正式运行有CA后台NSView.layer警告，完整UI / 真机仍待完成 | 历史四种容器与4K HEVC Simulator实际输出通过；最终正式iOS42中四容器 / 4K输出通过，三项片尾场景失败，真机硬件解码待测 |
| 控制 | 暂停 / 继续、进度跳转、倍速、全屏、结束、切换影片、退出清理 | 正式Mac34暂停 / 连续操作 / seek / EOS / 重播 / 三项真实负向均通过；原surface resize及原生context含关闭通过；最终完整UI待跑 | 本地及3210ab2 CI历史iOS27为30/30；历史UI / 减少透明度专项通过；最终iOS42为39通过 / 3片尾场景失败，新App完整UI与真机待测 |
| 字幕 | SRT / ASS / VTT 中文、内嵌字幕、开关、跳转同步、无字幕 | 正式Mac34轨道选择 / 关闭与坏字幕重试通过；ASS / SRT / VTT最新正常自有窗口均无可辨识中文，视觉未通过；ASS正常首条、下一条及实际seek回首条三画面仍均无中文，不调用engine snapshot | Simulator历史内嵌 / 外挂字幕选择与关闭、章节跳转、坏字幕不中断视频与同片重试通过；视觉同步 / 真机待测 |
| 音轨 | 单 / 多音轨、切换、无音轨、不可解码错误 | 物理 Mac 多轨选择通过；无音轨与不可解码错误待测 | 多轨选择通过；其余 UI / 真机待测 |
| 记录 | 断点、重启恢复、片尾完成、已看、清除；库条目删除不删除原文件 | 当前Domain9 / Library4与正式Mac34中的AppStore8通过；真实源故障位置<duration且watched=false、健康EOS恰一次通过；新App UI续播待验收 | 历史AppStore8与UI回归通过，未确认片尾seek / 源失败 / 旧会话边界通过；最终iOS42为39通过 / 3片尾场景失败 |
| UI | 本地 / 续播空状态；导入入口；SMB 表单校验 / 取消；目录 / 返回 / 空目录；列表筛选；失败重试；格式 / 观看状态；播放入口 | 原Aqua 11通过 /7失败 /1 opt-in跳过保留；原生context窄窗 / 关闭 / 目录往返专项3/3，正式helper已整合；自有窗口截图收尾与最终完整UI待完成 | iPhone与iPad历史各18通过、1 opt-in跳过；减少透明度各另1/1，表单滚动专项各1/1；正式新App完整回归待执行，虚拟NAS不替代真实协议 / 真机 |
| 可访问性 | 动态字体、可访问性描述、VoiceOver、实际系统减少透明度、键盘导航 | 原未过滤描述audit仍失败：空且Disabled的系统TouchBar；最小原生Text+Button亦复现，过滤未获自动审批，gate未改；减少透明度专项 / VoiceOver / 人工验收待完成 | 历史描述audit / 实际减少透明度专项通过；iPad真实最大字号SMB及设置操作2/2；全应用最大字号、VoiceOver / 真机待测 |
| 适配 | 980×680 / 620×440 窗口、浅深色；iPhone 小屏 / 横屏；iPad 分屏 | 原浅深色截图已审；实际620×440内容窗口 / SMB及context专项通过，播放器深色 / 返回通过；正式新helper完整UI与自有窗口截图待验收 | iPhone22张旧截图、iPad完整场景 / 最大字号表单及真实单窗缩放原件已审；最终新App回归与双窗并排待验收 |
| 分发 | 签名、公证、DMG 标签和内容、安装、首启、公开下载 SHA256 | 磁盘 c790607 DMG 为旧候选；VM 54 项仅对应旧 5e12be2；当前源码的新签名 / 公证包、VM、首启 / 播放和公开下载待测 | 不适用 |
| 分发 | 真机安装 / 播放、TestFlight 构建和安装、公开入口 | 不适用 | 当前 archive 57 项通过，Apple Development / get-task-allow=true；手机仍锁定，安装 / 播放 / TestFlight / 公开入口待测 |
| 官网 | 中英介绍、真实截图、系统要求、下载 / 发布链接、线上访问 | 隔离候选 153 项测试及 16 个浏览器场景通过；实际截图、下载与线上部署待完成 | 开发状态页面候选通过；无公开 iOS 安装链接 |

共享代码回归：文件格式 / 自然排序、目录边界、HTTP Range、进度边界、编码往返、损坏 / 未来版本数据、密钥不入普通持久化和源健康。TCP 测试辅助修复后，本地及 fb650378 CI 的原共享测试 **41/41、0 failures、0 skipped**：Domain 9、Library 4、Sources 28。最新 DEBUG 边界新增4项后，本地及 3210ab2 CI 均为 **45/45**；远程 Xcode26.6 / Swift6.3.3 实际编译及执行通过。证据 `.build/SMBSocketQueueFixEvidence/review.json`、`.build/SMBDebugTraceEvidence/review.json`、`.build/CI3210ab2Evidence/review.json`。旧 e4d7ff0 的34/41与原始失败保留。历史半关闭阶段33/33与此前31项日志仍保留。

协议集成使用隔离 SMB2 服务和自己生成的媒体样片，验证认证、读取、HTTP Range、取消、超时与失败路径。WebDAV / Jellyfin 未入选本期，不是本期验收项。

macOS UI 优先在 Tart `macos27` 验证，避免占用用户主机键鼠。自动化结果不替代 iPhone 的硬件解码、声音、4K 和安装验收。测试样片由脚本生成，不提交版权影片。

下列分阶段证据保留各自原提交和结果；当前结论以前述矩阵和文末正式集成记录为准。

## Mac 视频输出对照与正式集成

在独立候选中，仅把 macOS 视频输出选项改为 `caopengllayer`，保留默认解码器与先前已验证的测试窗口准备方式。原重播、4K 和四种容器三项实跑 **3/3、0 跳过**；随后原完整22项实跑 **20 通过、2 失败、0 跳过**，103.010秒，runtimeWarnings 为空。两轮均无固定 GL 断言、异常退出或 crash 附件；完整组的20次 SMB seek / 重开通过，42.195秒。原断言和期限保持，源及188个自有测试产品文件前后不变。证据 `.build/HostMacPlaybackCAEvidence/IndependentFocusedReview/review.json` 和 `IndependentFull22Review/review.json`。

两项失败仍发生在 held-tail 的释放 / 读错注入之前：最后实际 normal clock 为11.006417 / 10.998792，要求大于11.8的条件未满足。原始结果、数字日志和先前失败均保留。固定 libVLC 的 [公开 watch-time 契约](https://github.com/videolan/vlc/blob/005e69e67a8730f128e44bde68437fbb048cf45f/include/vlc/libvlc_media_player.h) 允许依源类型而变化的回调周期；最小报告间隔不保证最后一个回调到达影片时长。正在独立核对测试阶段条件，尚未修改正式 oracle 或宣称尾部故障验收通过。

原 `VLCVideoView.hasVideo` 和名为 `vlcopengllayer` 的 layer 只观察旧的 wrapper 接口。固定引擎当前 CA 模块创建 `VLCVideoLayerView` / `VLCCAOpenGLLayer` 并添加 subview，不走该旧接口；其零值既不认证也不否定当前模块。

独立 SwiftUI 实窗诊断随后通过：先 load，再挂载正式原 `PlayerSurface` 的 `.zero` 原生 view；启动、640×360 → 960×540 → 640×360、seek、两次真实 EOS 和新 engine 重播共七阶段，10.188秒，exit0，无 GL 断言。去重后实际 CA view / layer 各1个，附着本窗口且大小有效；ended 和 validator 各2次。只用公开 `SCShareableContent.currentProcess` 获取本进程可捕获内容，再要求 window ID 和所属 PID 均匹配自己创建的窗口，未操作主机键鼠或捕获桌面。独立 PNG 为1280×784，中央3920/3920抽样像素非黑；Root 亲自检查到合成彩条、运动图形和1.000秒 / frame15时间码。这不替代完整播放器界面或实际听音。原件 `.build/PlainSwiftUISurfaceEvidence/Results-_zt1350s/`。

正式 `FilmPlayer.swift` 现与上述 CA 候选逐字节一致，SHA256 `da5fc6cf1cc2a003234b942d77ca32ad34168e422caa0637d3a66b0c670f21b8`；只纳入 macOS 视频输出选项，正式 surface、桥接源保持。证据 `formal-ca-integration-proof.json`。最终新 App 的完整 UI、片尾复合阶段、当前路径硬件属性、签名包和分发仍待验收。

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

磁盘中的 c790607 DMG 为旧候选，VM 54 项只认证旧 5e12be2 包。当前源码尚无新的签名 / 公证 DMG，也未做新包安装、首启 / 播放或公开下载。真实 iPhone 仍锁定；未更改登录、安全设置或账户。最终源码资产 / 二进制绑定、当前包 VM 验收、真机安装 / 播放、GitHub tag / release 和官网上线均未完成。

## 最新 CI 与 macOS Aqua 验收（2026-10-03）

`fb65037810a241b35b5e09c9e4b9f71a84a0e008` 的 GitHub run `37084529322` **整轮失败**：共享 **41/41、0 failures、0 skipped**，三个平台构建通过；iOS 27.0 正式测试 **26/29、3 个失败 case、0 skipped**。两个真实 SMB 近片尾用例在实际输出到达门控前超时，重复 seek 用例在首个 seek 超时；6 条 failure records 属于这 3 个 case，不是 6 个失败用例。精确 artifact `11260201844` 的 SHA256 与下载 digest 一致，证据 `.build/CITestSocketFixEvidence/review.json`。同一正式产品在本机 iOS 26.5 的原 3 项聚焦回归 **3/3、0 failure、0 skipped，38.298 秒**，源码和产品运行前后字节未变，证据 `.build/PlaybackEvidence/CI-fb650-Focused3/review.json`。本机通过不代替远程失败，也尚不能确定差异根因。官方 iOS 27.0 / 24A434 arm64 runtime 已下载并注册，用新自建设备复现；原设备保留。

Tart `macos27` 当前已有用户 Aqua 图形会话，实际显示器为 1920×1080。SSH 中的空显示报告和截屏权限失败不能证明没有显示设备。测试使用现有同用户 Aqua launchd job；没有修改账户、自动登录、Gatekeeper、TCC 或 Developer Tools 安全设置。最初 SSH 上下文 UI 初始化因 automation mode 超时而未执行 case，保留该结果，不算应用 UI 用例失败。

现有正式 e4 实现的 Aqua UI 全组实际结果 **11 passed、7 failed、1 opt-in skipped，204.137 秒**；系统减少透明度为 false，专项跳过不能算通过。原始 xcresult、日志、summary、截图和可访问性树在 `.build/ReleaseEvidence/candidate-fb650378/GUIReadiness-native-ui-c4fd83c4/Results-AquaUI-20261003-c4fd83c4/`。失败覆盖 accessibility description、窄窗实际仍 980 点、全屏返回后的关闭、原生文件选择器查询、播放时间推进 / 控制层查询和 SMB 表单取消后的状态。浅深色原始列表截图已审核，失败正按应用行为和测试查询分别诊断，尚未修复后重认证。

Mac 正式应用测试共 **21 项**（AppStore 8、EOF 4、Playback 9；8 项音频生命周期测试仅适用于 iOS）。此前 SSH 上下文全组为 **8 passed、13 failed、0 skipped，204.251 秒**，实际视频输出为零，崩溃栈记录 objc_release / autorelease / XCTest。测试 NSWindow 已增加 `isReleasedWhenClosed=false` 以保留 ARC 所有权；仍需在现有 Aqua 会话用新测试 bundle 重跑，不能将测试崩溃修复推导为视频已恢复。

新增 DEBUG 诊断默认关闭，只保存有硬容量上限的数字 / 固定事件枚举，并仅在失败时附加 JSON；不记录片源 URL、路径、认证或错误文本。共享包原 41 项加 4 项诊断边界测试，共 **45/45、0 failure、0 skipped**；Release 编译与符号检查确认该包的诊断 API / recorder 均排除，证据 `.build/SMBDebugTraceEvidence/review.json`。原播放 / 读取断言、超时、Range、取消逻辑、512KiB chunk 和依赖均未改变。此结果只认证诊断边界，不代表 CI 播放问题已解决。

同源新诊断产品在 iOS 26.5 的原三个聚焦用例 **3/3、0 failure、0 skipped，38.824 秒**，结果 `.build/results/AetherFilm-debugtrace-focused3-20261003-0142.xcresult`；官方 iOS 27 对照 **3/3**，完整正式 **29/29、0 failure、0 skipped，82.917 秒**，证据 `.build/PlaybackEvidence/DebugTraceIntegration/27-full29-review.json`。Mac 新 ARC guard 测试 bundle 构建通过，Aqua 实跑仍待完成。

诊断提交 `4d25379` 的 run `37086982680` **整轮失败**。共享在 Xcode 26.6 / Swift 6.3.3 编译 DEBUG Task 时存在重载歧义，尚未执行测试；平台三项构建通过，正式 **27/29、两 EOF 准备 case 失败、0 skipped**，20 次 SMB seek / 重开本轮通过，69.942 秒。精确 artifact `11261102382` 与 digest 一致，证据 `.build/CI4d25379Evidence/review.json`。两项失败没有到达尾部释放 / 读错注入，也没有执行 validator。记录到的 Swift delegate 到 MainActor 最大延迟为 7.53 / 1.83ms，HTTP 发送完成与后续协程恢复较快；上层前缀读取需 0.518–2.247 秒，正常 clock 在最后前缀发送后约 27 / 91ms 出现。未确定 C / context 锁或其他唯一原因，不能把旧 seek 失败标为已修复。

修正仅明确 DEBUG `Task<Void, Never>` 类型，以及测试的阶段：先用既有 12 秒真实冷开片门，随后显式 seek10 / 原 6 秒近尾门；动态选取的尾部字节保持 withheld，原 frame / clock / health / validator 断言保留，并要求 seek 后新视频帧和音频各超过 seek 前基线 5。旧 CI 样片尾部为 410 字节，本地新样片为 391 字节，均由原 ffprobe 脚本选取最后音频包，不能硬编码字节数。另加独立未 held 的 SMB 冷续播10测试，首次观察到正常 clock 与实际画音时即检查起点至少 9.95 秒，以排除从零正常播放到10秒的误通过；原 clock/input >10.06、12 秒准备和 6 秒 EOS 门保留。独立静态复核 `.build/SMBDebugTraceEvidence/PhaseReview/review.json` 绑定 EOF SHA256 `58db08570eb573e3e370844735b069328dddfbacc8fc81913af565701556269c`；未包含首次起点门的早期 30/30 草稿不作最终证明。该改动调整测试准备，不改变生产超时或网络参数。

增强后官方 iOS 27 完整 **30/30、0 failures、0 skipped**，78.575 秒，EOF 5、FilmPlayback 9（含原20 SMB seeks / 重开）、AppStore 8、音频8均通过；三个 SMB EOF 在 iOS 26.5 另行 **3/3**，10.315 秒。冷续播首次正常 clock 为10.133334秒，真实 input 分别为10.134432 /10.148684秒。独立 ignored 副本仅将该测试的 load 参数改为0，保留“请求10”断言与正式代码，在正常 clock0.866667 / input0.915167秒即失败，2.051秒，一失败 case；这是预期负向验证，不是正式产品回归。实际 xcresult 摘要保留于 `.build/PlaybackEvidence/PhaseGuard/{27-full30-summary.json,26.5-EOF3-summary.json,negative-summary.json}`，无 runtime warnings。随后新 CI 与 Mac22 的实际结果如下。

提交 `3210ab28466b4ba0cb0f109e587892e048002be4`，GitHub run `37089277731` attempt1 **整轮 success**，两个 job 的原始日志和精确 checkout 已核对。共享 Xcode26.6 / Swift6.3.3 为 **45/45、0 failures、0 skipped**，2.326秒；macOS App/tests、iOS Simulator App/tests、iOS device 三项构建成功。iPhone Air / arm64 / iOS27.0 /24A434 正式应用测试 **30/30、0 failures、0 skipped**，case 合计163.280秒、suite163.429秒；20 SMB seeks / 重开71.322秒通过，冷续播首个真实 clock10.133334 / input10.135034秒。精确 artifact `11262016795` 为219163字节，SHA256 `2375c339e54aa1dc3e00754d73edda79ecd9437ac7c2dd975faa8d7c75eb6e60` 与官方 digest 相同。原始 ZIP、xcresult、summary、tests、9个导出文件及日志保留于 `.build/CI3210ab2Evidence/`，审核 `review.json` SHA256 `f3ccb74867d1cde6e9d7ea18f5cebf71ae9e25e83a0242432c01ac18185301ed`。xcresult runtimeWarnings 为空，但控制台仍有81次 no-object 音频系统消息、4次 HALC 和2次 skipping token；不是无音频告警或真机听音证明。

Mac 增强后正式22项（AppStore8、EOF5、Playback9）在现有 `gui/501` Aqua ASID100002实跑，原实际输出断言 / 期限未变：**10 passed、12 failed、0 skipped，181.378秒**。失败均未达到实际视频门，decoded/displayed 为0/0，音频和时间可推进；无 crash failures，未重现旧 ARC/window-close 崩溃，runtimeWarnings 为空。原结果及12个附件、Aqua context 与启动核验保留于 `.build/ReleaseEvidence/candidate-fb650378/GUIReadiness-native-ui-c4fd83c4/PhaseGuard22/Results-AquaPlayback22-20261003-c4fd83c4/`；输入测试 ZIP SHA256 `898f407a08891761475d310e2aae472d7de804bc8e2fb1b65b52173364a73716`。这只认证正式22项运行；其中旧继承 UI bundle 不能认证当前修改后的19项 UI。视频黑屏根因尚未确定，正在用原默认参数的 stock / derived 独立进程诊断；不因测试不再崩溃而称播放通过。

## iPad 完整流程与真实最大字号（2026-10-03）

iPad Pro11-inch(M5) / arm64 / iOS27.0 /24A434，自建设备，App executable SHA256 `8b65ca3de49fd697bbb013a2aa0a26a5c7f08dda23c7bd65f9e28e809a52bfcf`。首次原UI辅助完整19项为17通过、1失败、1跳过：SMB加密行尚在Form懒加载视口外，原window0.93拖动落在弹窗外。此失败原件保留，未当作产品连接失败。改为实际modal Form内、键盘上方滚动，并在真正展示行后保留原exists / value0→1断言；原4次尝试及5秒期限不变。正式测试源 SHA256 `48d70cc12483058ec3d015f220f5ecf6c6918d30757c0e1c21d86cca74e7aee2` 的全19项实际为 **18通过、0失败、1 opt-in跳过，310.397秒**；xcresult runtimeWarnings为空。UI-only Runner重编前后61个App文件完全相同，证据 `.build/iPadFullUI-20261003T021128Z-5a39314a/{formal-helper-product-proof.json,formal-helper-full-summary.json}`。真实系统减少透明度专项另为 **1/1、0跳过**，开关实际读回 / 恢复，不能把全组的跳过改写为通过。

同一App、61文件绑定下，实际系统 `accessibility-extra-extra-extra-large`，App内 preferredContentSizeCategory 校验为 `.accessibilityExtraExtraExtraLarge`，没有使用 `--ui-content-size` override。新ignored交互探针实际滚动展示高级选项 / 端口，再按原断言操作：SMB端口0 /65536 /445、加密0→1和取消，及字幕大小1→1.683、音量100→35%、完成返回；**2/2、0失败、0跳过，79.517秒**。原最大字号初轮1通过1失败（高级选项尚未展示）保留；未放宽原断言和4次 /5秒要求。七张原始PNG由执行者及主代理逐张查看，滚动后的Form视口、滑杆及固定完成按钮可达，实际系统字号随后恢复large并读回。证据同目录 `maximum-reveal-interactions-{summary,completion}.json`、`maximum-reveal-same-app-proof.json` 及 `maximum-reveal-interactions-screenshots/001.png` 至 `007.png`。这只关闭上述交互范围的最大字号缺口，不认证全应用最大字号、VoiceOver朗读或分屏。

正式48辅助在iPhone26.5单项曾失败：modal CollectionView容器isHittable=false被筛选排除，后续独立副本的拖动又落在Cell右侧空白或系统输入预测栏。原红结果、AX及数字geometry均保留。新独立Runner / Derived明确校验实际runtime修订，仅调整辅助：选择唯一modal Form、采用Form交集内0.93位置，并按真实inputView / SystemInputAssistantView边界排除键盘遮挡；原4次尝试、5秒期限、端口0 /65536 /445、加密0→1及取消断言全部保留。iPhone26.5 **1/1、0跳过，41.395秒**，iPad27 **1/1、0跳过，41.552秒**。两次共享同一61文件App，未重编App；证据同目录 `input-occlusion-query-{iphone,ipad}-smb-summary.json` 及 `input-occlusion-query-product-proof.json`。已批准正式收纳辅助；随后完整正式UI仍需用包含新外观修复的App重新执行，不能将该两项替代完整回归。

同一iPad App通过原生窗口右下角handle实际缩放，**1/1、0跳过，31.021秒**：窗口从834×1210变为位置(218,207)、大小398×681，播放器实际画面、设置完成和关闭返回列表可操作，之后恢复834×1210。Windowed Apps原已选中，没有改模式。六张原始PNG由执行者及主代理逐张审核，证据 `native-window-resize-review.json` 和 `window-resize-product-proof.json`。该项是单个真实窗口，尚未认证并排双窗口、窄窗SMB操作或两滑杆调整。

## Mac 视频创建与界面诊断（2026-10-03）

同一实际Aqua会话，stock和derived默认播放器分别独立进程采48次，视频decoded/displayed均0/0、音频564，窗口active/key/visible且view640×360。默认路径记录固定引擎的OpenGL view初始化失败。独立创建实验使用原 `macosx.m` 属性数组，NSOpenGLPixelFormat实际返回nil，failedStage1，未尝试NSOpenGLView；无lazy context getter。备用 `--vout=caopengllayer` 两个独立进程仍0视频 /564音频，记录CA format失败、vout启动失败，未出现表示CA Open成功的counter34。原JSON及进程退出记录保留于 `.build/NativeMacUIDiagnostic-c4fd83c4/GLCA/Results-Aqua-20261003-c4fd83c4/`。这些诊断不是放宽后的播放验收，也不能外推真实Mac硬件兼容性。

新OSLog界面诊断3项实际 **0通过、3失败、0跳过，33.244秒**，原结果 `.build/NativeMacUIDiagnostic-c4fd83c4/OSLogAquaUI3/Results-AquaOSLog-20261003-c4fd83c4/` 保留。23条固定子系统日志确认：测试入口的祖先nil颜色偏好下，player实际scheme=light；窄窗在不可见时设为620后，下一runloop实际恢复980×680；辅助SizingView实际非AX元素，不能将另一个无描述NavigationSplitView Group视作该辅助而隐藏。新fixture关闭断言还失败，需区分XCTest合成点击延迟与实际产品行为。正在分别修复外观入口、可见后的测试窗口尺寸和媒体库容器语义，原审计/期限不变；后续修复结果待实跑。

四组合GL独立实验在同一实际Aqua会话完成：一个online/window软件renderer、accelerated0；含Accelerated的两组CGLBadPixelFormat10002，移除Accelerated的两组格式 / context / view均成功。NoRecovery不是本轮拒绝原因，不能再称VM所有GL不可用。纯query工具在host受限sandbox仅见一个offline软件renderer，system只读权限对照则见两个online/window renderer（硬件1、软件1）；未创建host窗口/context或键鼠输入。证据 `.build/MacGLAttributeMatrixProbe/Evidence/{actual-review.json,host-query-review.json}`。内存帧方案只读评估已暂停，未改生产后端。

真实host Mac正式22项也已执行，独立Products副本、原代码与断言未改，去掉UI target并以独立temporary库 / preferences隔离main App；仅程序自建视频窗口、生成样片及loopback SMB，不合成键鼠或修改安全设置。**17通过、5失败、0跳过**，exit65，runtimeWarnings为空。冷SMB10续播2.444秒及20次seek / 重开44.320秒通过；两个held-tail有新增视频 / 音频，但原normal clock>11.8门未达到（最终约11.004秒），没有到达释放tail / 注入读错。另Replay、4K与CommonContainers三项SIGABRT，三份ips和控制台都指向vout_display_opengl_Prepare开头的GL_INVALID_FRAMEBUFFER_OPERATION断言；不同于旧ARC/window-close崩溃，尚不能指认某codec为唯一根因。

原host结果 `.build/HostMacPlayback22-06009614/MacPlayback22.xcresult`，主代理摘要 `root-summary.json`，独立review `IndependentPlaybackReview/review.json` SHA256 `e8e3a69e75819436da8cde8edac383a37d8fb26096c15bde81b48a47d7b46b10`。原171产品、自有重签 / 加Xcode注入库后的188产品、6个core/test源运行前后相等，28个MachO UUID保留；AppStore删除源测试会SecItemDelete一个新随机fixture UUID，未读或创建用户凭据。该副本只认证所绑定的正式22/core，不认证当前全部UI源或最终分发包；真实Mac仍有失败，不能把VM硬件限制当作全部失败解释。

## macOS 独立播放器装载与实际 GPU 对照

2026-10-03，独立自有 NSApp / 640×360 视频窗口在实际 Mac 27.0.1 运行，无 XCTest / UI Runner / 合成输入。初始诊断包复制新 executable 时漏加 bundle Frameworks rpath，两个进程在 DYLD 装载阶段退出、没有播放采样；失败产品与 own PID 对应报告均保留。仅在新诊断副本增加 `@executable_path/../Frameworks` 并重签，executable `__text` 和整个 VLCKit framework 字节未变，不修改正式播放器或引擎选项。

修正后，默认 codec / macosx vout 下 H.264 的原版与派生版各完成48个采样点、正常退出，均 decoded video180 / displayed174 / played audio564；4K HEVC 的两个独立进程各完成48点、正常退出，decoded144 / displayed138和140 / played audio283。所有采样窗口 active / key / visible / attached，四次固定 framebuffer 断言计数均为0。root已独立复核每个结果 hash、48点和实际输出；证据 `.build/HostMacVideoPathProbe/Evidence/root-h264-4k-review.json`，两轮目录 `Results-h264-8_6ih79v` 与 `Results-4k-eg1n0qeq`。

这些数字限定于独立诊断：timeMilliseconds 是原 VLCKit getter / 插值而非正式 raw normalClockPoint，未验收肉眼非黑画面或耳听声音，VT module selection 不认证硬件 session，也不覆盖正式22项的17通过 /5失败。下一步只在隔离测试副本验证窗口准备状态，原测试门限保留。

## 自有进程实际硬件解码属性诊断

2026-10-03，独立 Debug observer 只加载在本轮自有播放器子进程中，在原 `VTDecompressionSessionCreate` 调用成功之后读取 Apple 公开的 [UsingHardwareAcceleratedVideoDecoder 属性](https://developer.apple.com/documentation/videotoolbox/kvtdecompressionpropertykey_usinghardwareacceleratedvideodecoder)。原参数、返回值、生产源与默认 codec / vout 未变；只留 codec / 画幅 / OSStatus / CFBoolean 数字，未保留原始 stderr，也未更改系统配置。代码与 ABI 已独立审查，编译 `-Wall -Wextra -Werror` 和严格签名通过。

H.264 320×180 与 HEVC 3840×2160 各绑定一个真实成功 session，createStatus=0 / queryStatus=0 / hardware=1；两轮均48采样、正常退出，分别 video180 / displayed174 / audio564 和 video144 / displayed137 / audio283，GL断言0。root独立复核结果与源码、observer二进制、固定引擎绑定 hash，证据 `.build/HostVTHardwareObserver/root-actual-review.json`。此为本机对应样片的实际硬件session属性证据，仍限定于instrumented独立诊断，不能替代最终App UI、iPhone真机或分发验收。

## 当前正式整合与最新待验收项（2026-10-03）

**Mac 视频输出与 ASS 视觉分开验收。** CA 候选原22项20通过、2失败，剩余失败均在旧 raw normalClock >11.8 准备门，未进入尾部注入；旧 Aqua 黑屏和物理 Mac GL 退出只代表其绑定的历史产品。正式原 PlayerSurface 的独立 SwiftUI 实窗已通过 load-before-mount、resize、seek、EOS与重播，原件 `.build/PlainSwiftUISurfaceEvidence/Results-_zt1350s/`。4K HEVC原实窗 `.build/PlainSwiftUI4KEvidence/Results-tzsixmky/` 正常退出，真实VideoToolbox session create/query均0、hardware=1，CA附着有效，最大decoded33 / displayed26 / audio111，GL断言0，own-window PNG有真实画面。它限定于自有独立窗口和生成媒体，不认证最终完整App UI或听音。

公开logger与引擎snapshot诊断 `.build/SubtitlePipelineProbeEvidence/Results-la_xwq09/`（4K HEVC）及 `Results-haw5d6kf/`（H.264）均有真实轨道selected、CA输出、正常退出，产品前后不变；两组 `surface.own-window.png` 与 `surface.pipeline.png` 均未显示可辨识中文ASS。样片左上角time/frame小标记已在无外挂字幕的原始视频帧复现，不是字幕成功证据；对照 `.build/PlainSubtitleGeometryEvidence/fixture-2sec.png`。正式font scale=1对应公开API的100%不作猜测性改动；当前ASS视觉仍未通过，不以selected或snapshot保存成功替代字形验收。

**片尾复合阶段已整合，正式全量仍待跑。** `.build/TailPhaseCandidateEvidence/IndependentR3Review/review.json` 独立复核候选r3实际14/14、零失败零跳过：九项纯对抗、两项真实SMB健康 / 读错golden和三项实际fromZero / 暂停 / cancelled-historical负向。阶段要求同会话seek marker之后的新normal source/delivery配对、其时真实output基线与后续新增视频 / 音频、新input和当前active UUID匹配未终结HTTP tail；cache仅作估计。真实末1byte HTTP206内容SHA匹配SMB / bundle，零holds，随后不同HTTP请求391bytes挂起，再own TCP RST清零pending；故障validator一次、无完成、持久化位置小于duration且未看，健康EOS一次。原6秒阶段期限、fault / health / persistence / EOS断言保留。

正式只集成getter nil-clock保护、DEBUG数字trace、复合phase与三负向 / 九pure，以及单列审阅的Mac测试窗口setUp准备；未纳入legacy-surface诊断，桥接和CA选项保持。集成证明 `.build/TailPhaseCandidateEvidence/IndependentR3Review/formal-integration-proof.json` SHA256 `6d6ca1dd1a0d53650fc930bd9f4307d7190269da43f8656733e7c573db83834d`。Root/helper完成最终改动后须重新冻结，并执行完整Mac34 / iOS42；既有14/14不合并成正式34/42通过。复现与runner适配清单 `full-suite-preparation-plan.md` 同目录留存。

**Mac 原生可访问性与完整 UI。** 正式 `NativeAccessibilityContext.swift` SHA256 `0e62d7c70289458c0d5efdde170116704a816e72a39f8b2c2499e0e5f27bfa43`、`RootView.swift` SHA256 `3226a234a1bc277e4f96858759030e53940f16cd18278685838a3a68cfb681bf` 已整合。原生context窄窗、播放器关闭、目录往返专项3/3、零失败零跳过，证据 `.build/NativeMacUIDiagnostic-c4fd83c4/ContextTransitionAqua/Results-AquaContextTransition-20261003-c4fd83c4/`；这是专项范围，未执行原未过滤描述audit，不作完整UI通过。

原描述audit失败和最小原生Text+Button基线失败均保留；后者复现空且Disabled系统TouchBar的相同形态，证据同诊断目录 `NativeAXAqua/Results-AquaNativeAX-20261003-c4fd83c4/` 和 `NativeTextButtonBaselineAqua/Results-AquaNativeTextButtonBaseline-20261003-c4fd83c4/`。过滤该系统元素的方案被自动审批拒绝，未修改正式audit gate或删除失败。自有窗口截图收尾、最终新App完整19项UI、实际减少透明度与VoiceOver边界仍待验收。

**SMB3 正式八项与默认共享回归。** 先前独立CLI两轮各8/8证据 `.build/SMB3SambaEncryptedEvidence/{encrypted-integration-review.json,encrypted-integration-review-v2.json,root-review.json}` 保留，不能转记为新正式测试。正式脚本 `scripts/test_smb3_encryption.py` SHA256 `49684521feb1ce51c6bd9fed675839b29943303dc5bcbfd292e337e67dbe73bc` 与八项测试 `SMB3EncryptionIntegrationTests.swift` SHA256 `b6a7d9699dd22b36adce2e6aa07979c7f8207c6f2a85eef820e8a1bbdec6e422` 已逐字节整合；证明 `.build/SMB3FormalIntegration/integration-proof.json`。

Root已闭合本轮正式专组：脚本exit0、completed=true / testExit0、caseCodes1…8，实际八项通过，独立复核15/15完成，原件 `.build/SMB3FormalIntegration/formal-r2-run1.json`。10个真实SMB3.1.1连接、FD加密SMB97/97、plaintextREAD0 / malformed0和heldFrame1；取消小于1秒由已编译断言验证，未附独立计时值，不复用旧CLI约33微秒。自己的进程组全部停止、临时目录已移除。运行时两辅助目录和八文件未达到700/600的事实保留，隔离root700与hashed passdb600维持，停组后规范并清理；不声称所有运行时条目均700/600。

普通共享全组本轮实际45通过、8项SMB3 opt-in跳过、0失败，原始日志 `.build/SMB3FormalIntegration/normal-shared-with-optin.log` 和逐case复核 `normal-shared-review.json` 保留。正式专组独立15/15检查通过，报告 `.build/SMB3FormalIntegration/execution-review.json` 绑定八个实际已编译方法、包锁定与实际协议结果。此前3210ab2的45/45、零跳过仍是原提交历史，不能套用到新增八项之后的正式源码。新正式SMB3专组不替代真实用户NAS、iOS真机或发布分发验收。

## 当前正式全量与字幕画面复核

同一次源码冻结 `.build/FormalVerification20261003-0524/source-freeze.json` SHA256 `44f293c6b89cfa915fb3fa72fbf2ababc43a0788b99c07d0c9abab5cd5219231`：Mac / iOS测试构建均成功，最低系统26.0，编译实现UUID / TEXT在自有签名副本中保持一致，原产品未改。正式源包括FilmPlayer `55bf5fd9…`、EOF测试 `394da122…`、RootView `3226a234…` 和UI测试 `c02b4828…`。EOF取消测试按样片metadata检查精确起止及长度大于1，不硬编码本机FFmpeg末包391bytes；历史CI的末包实际410bytes，两者均保留动态端点检查。

Root在本任务自有窗口和隔离SMB样片运行全部Mac34，实际34通过、0失败、0跳过，116.911秒；iOS27既有指定模拟器全部42实际39通过、3失败、0跳过，109.424秒。两轮case ID完整、源码和自有及原产品前后未变。原结果 `.build/FormalVerification20261003-0524/Results-{mac,ios}-full-r1/`。Mac有一次CA后台NSView.layer Main Thread Checker报告（两处打印），两轮xcresult runtimeWarnings均为空；二者需分别披露。iOS失败没有进入两个golden的释放 / 注错 / validator阶段，不能宣称这些验收通过；fromZero oracle确实拒绝，但实际新视频 / 音频输出未增长，负向活跃条件未通过。旧Mac候选14/14和本轮正式Mac34不能替代iOS失败。

字幕R4只读诊断保留原播放器 / Surface、固定框架与样片，不调用公开engine snapshot。H.264正常第一条、正常下一条、实际seek回第一条三个自有窗口原PNG由Root逐张复核，均无可辨识中文。对应原始raw clock2.025209 / 6.035876 / 4.010354秒、每阶段公开选轨1 / delay0 / fontScale1、真实VT avc1 hardware=1与实际画音输出；三个窗口捕获成功和功能阶段通过均不等于字幕视觉通过。六个阶段logger点均无已知error100；早先快照后记录的滤镜错误不能套到本轮正常画面。证据 `.build/SubtitleTemporalProbeEvidence/Results-tm2ajnj5/{execution-review.json,root-glyph-review.json}`。三格式字幕最终视觉仍是失败gate，后续GL计数准备尚不作修复或发布证据。

当前仍未发布。最终源码 / 二进制绑定、新签名与公证包、VM安装 / 首启 / 播放、真机安装 / 实播、TestFlight及公开入口继续按各自验收记录推进。
