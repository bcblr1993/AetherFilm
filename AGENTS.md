# AetherFilm project guidance

- Use Chinese for user communication. Keep public API symbols and code in English.
- Minimum macOS / iOS deployment targets are 26.0; do not raise them for visual styling.
- Read `docs/PRODUCT.md` before expanding scope. First release stays small.
- Keep domain, library and source services in the shared Swift package; SwiftUI views call observable app state.
- Use system native Liquid Glass controls. Keep content readable and support Reduce Transparency, Dynamic Type and VoiceOver.
- Preserve user files. Library removal never deletes the original video. Secrets stay in Keychain and never in Git, logs, fixture recordings or screenshots.
- Pin third party dependencies and record licenses / corresponding source before distributing binaries.
- Test actual playback, protocol errors, persistence, both platform builds and the full UI state matrix. Prefer Tart `macos27` for desktop UI work; do not manipulate host keyboard / mouse.
- Generated projects must be reproducible from the checked-in specification. Version data must have one source of truth.
- Do not call a release complete with missing real-device or distribution evidence. Follow `docs/RELEASE.md` and update `docs/TEST_MATRIX.md` truthfully.

## 每次发布后的磁盘清理（必须执行）
- 构建前检查本项目产物占用及磁盘可用空间；空间不足先清理已确认可删除的旧产物，不能继续堆积。
- 每次新版本发布并完成适用平台的签名公证、官网更新、应用内升级与功能验收后，必须清理本项目之前版本遗留的可再生成构建产物及测试临时文件，不能只发布不收尾，避免持续占用磁盘。
- 清理范围包括已确认归属本项目且不再使用的旧预览包、解包后的旧测试 App、旧构建中间产物、临时 DMG 挂载目录、重复下载和解压副本、测试夹具、测试进程及 VM 内对应临时文件。测试产生的偏好设置须恢复，临时挂载须卸载。仍在使用的构建和其他任务的环境不得清理。
- 清理前必须列出具体路径并检查实际内容、归属及用途，记录占用；禁止仅凭名称、版本号或宽泛通配符递归删除。用户已授权上述明确的项目构建与测试临时文件清理，无需逐次重复确认；归属或保留需求不明确的文件先确认。
- 源码、Git 历史、历版正式安装包与正式源码归档、签名及公证记录、必要的验收报告和发布截图必须保留；签名密钥、凭据、用户数据和其他项目文件禁止清理。删除旧构建目录时必须先将其中需要保留的正式产物及证据妥善归档并验证，不能整目录直接删除。
- 应用内升级验收所需的上一正式版本基线必须保留到升级测试通过；之后可以清理其解包和安装的测试副本，但保留正式安装包以便回归及回滚。当前版本仅保留必要的预览包、正式发布产物和验收证据，去除重复临时副本。
- 发布收尾必须验证保留产物可用、临时挂载已卸载、测试进程已退出、VM 环境已恢复，并报告清理路径、实际释放空间及当前磁盘剩余空间。未完成清理及验证，不得宣称发布流程全部完成。项目发布清理授权不改变应用面向用户的清理确认与安全规则。
