import XCTest
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class AetherFilmUITests: XCTestCase {
    private var app: XCUIApplication!
    private var session = ""

    override func setUp() async throws {
        continueAfterFailure = false
        session = UUID().uuidString
    }

    override func tearDown() async throws {
        #if os(iOS)
        XCUIDevice.shared.orientation = .portrait
        #endif
        guard let app else { return }
        if testRun?.failureCount ?? 0 > 0 {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Failure accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            capture("Failure screenshot")
        }
        app.terminate()
    }

    func testLocalEmptyStateAndImportEntry() {
        launch("--ui-empty")
        let empty = element("library.empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 15))
        XCTAssertTrue(element("library.empty.action").isHittable)
        activate(element("library.empty.action"))

        #if os(macOS)
        let panel = app.sheets.matching(identifier: "open-panel").firstMatch
        let cancel = panel.buttons.matching(identifier: "CancelButton").firstMatch
        #else
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["取消", "Cancel"])).firstMatch
        #endif
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "The system file picker should open.")
        #if os(macOS)
        XCTAssertTrue(panel.exists)
        #endif
        activate(cancel)
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        capture("Local empty state")
    }

    func testContinueEmptyStateReturnsToLocalFiles() {
        launch("--ui-empty")
        XCTAssertTrue(element("library.empty").waitForExistence(timeout: 15))
        selectContinueWatching()
        XCTAssertTrue(element("continue.empty").waitForExistence(timeout: 5))
        activate(element("continue.empty.action"))
        XCTAssertTrue(element("library.empty").waitForExistence(timeout: 5))
    }

    func testSMBRequiredFieldsPortValidationAndCancel() {
        launch("--ui-empty")
        openSMBConnection()
        let connect = app.buttons.matching(NSPredicate(format: "identifier == %@", "smb.connect")).firstMatch
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        XCTAssertFalse(connect.isEnabled)

        replaceText(in: "smb.host", with: "nas.example.invalid")
        XCTAssertFalse(connect.isEnabled, "A host alone must not allow connection.")
        replaceText(in: "smb.share", with: "Videos")
        XCTAssertTrue(connect.isEnabled)

        #if os(macOS)
        let advanced = app.disclosureTriangles.matching(identifier: "smb.advanced").firstMatch
        XCTAssertTrue(advanced.exists && advanced.isHittable)
        // Let XCTest use the native hittable point; the AX frame includes padding beside the triangle.
        advanced.click()
        XCTAssertTrue(waitForValueContaining("1", in: advanced, timeout: 5))
        #else
        activate(element("smb.advanced"))
        #endif
        XCTAssertTrue(element("smb.port").waitForExistence(timeout: 5))
        replaceText(in: "smb.port", with: "0")
        XCTAssertFalse(connect.isEnabled)
        replaceText(in: "smb.port", with: "65536")
        XCTAssertFalse(connect.isEnabled)
        replaceText(in: "smb.port", with: "445")
        XCTAssertTrue(connect.isEnabled)
        let encryption = element("smb.encryption")
        #if os(iOS)
        revealAboveKeyboard(encryption)
        #endif
        XCTAssertTrue(encryption.exists)
        XCTAssertEqual(nativeValueString(encryption.value), "0")
        #if os(iOS)
        let nativeSwitch = encryption.switches.firstMatch
        XCTAssertTrue(nativeSwitch.exists)
        activate(nativeSwitch)
        #else
        activate(encryption)
        #endif
        XCTAssertTrue(waitForValueContaining("1", in: encryption, timeout: 5))

        capture("SMB connection form")
        activate(element("smb.cancel"))
        XCTAssertTrue(waitUntilMissing(element("smb.host"), timeout: 5))
        XCTAssertTrue(element("library.empty").exists)
    }

    func testFixtureFormatAndPlaybackEntry() {
        launch("--ui-fixtures")
        let row = firstMediaRow
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertTrue(String(describing: row.value).contains("MP4") || app.staticTexts["MP4"].exists)
        activate(row)
        showPlayerControls()
        XCTAssertTrue(element("player.close").waitForExistence(timeout: 15))
        XCTAssertTrue(element("player.playPause").waitForExistence(timeout: 15))
        #if os(iOS)
        let pauseFrame = element("player.playPause").frame
        XCTAssertGreaterThanOrEqual(pauseFrame.width, 44)
        XCTAssertGreaterThanOrEqual(pauseFrame.height, 44)
        #endif
        XCTAssertFalse(element("player.error").exists)
        showPlayerControls()
        capture("Player opened from local video")
        showPlayerControls()
        activate(element("player.close"))
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    func testPlaybackAdvancesAndCreatesContinueRecord() {
        launch("--ui-fixtures")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        activate(firstMediaRow)
        showPlayerControls()
        let elapsed = element("player.time")
        XCTAssertTrue(elapsed.waitForExistence(timeout: 15))
        #if os(macOS)
        let initialTime = playbackTimeText(elapsed)
        let advanced = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard elapsed.exists else { return false }
            let text = self.playbackTimeText(elapsed)
            return !text.isEmpty && self.seconds(in: text) > self.seconds(in: initialTime)
        }, object: nil)
        #else
        let initialTime = elapsed.label
        let advanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND label != %@ AND label != ''", initialTime), object: elapsed)
        #endif
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 12), .completed,
                       "The decoded video must advance instead of only showing controls.")
        showPlayerControls()
        activate(element("player.playPause"))
        XCTAssertTrue(waitForValueContaining("已暂停", in: element("player.playPause"), timeout: 5))
        showPlayerControls()
        activate(element("player.close"))
        selectContinueWatching()
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 5))
        XCTAssertFalse(element("continue.empty").exists)
        capture("Continue watching with saved progress")

        app.terminate()
        app.launch()
        selectContinueWatching()
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15), "Progress must survive relaunch in the isolated test session.")
    }

    func testPlaybackControlsHideAndReappear() {
        launch("--ui-fixtures")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        activate(firstMediaRow)
        showPlayerControls()
        let controls = element("player.playPause")
        let seek = element("player.seek")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: seek)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        showPlayerControls()
        let beforeSkip = seconds(in: playbackTimeText(element("player.time")))
        let skipPoint = element("player.surface").coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
        #if os(macOS)
        skipPoint.doubleClick()
        #else
        skipPoint.doubleTap()
        #endif
        let skipped = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let elapsed = self.element("player.time")
            guard elapsed.exists else { return false }
            return self.seconds(in: self.playbackTimeText(elapsed)) >= beforeSkip + 8
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [skipped], timeout: 5), .completed,
                       "Double tapping the actual video area should skip forward ten seconds.")
        showPlayerControls()
        let duration = seconds(in: playbackTimeText(element("player.duration")))
        let position = seconds(in: playbackTimeText(element("player.time")))
        XCTAssertGreaterThan(duration, 0)
        // SwiftUI's Slider thumb is not always exposed as an accessibility child.
        // Locate it using the actual timeline and track geometry instead of empty track space.
        #if os(iOS)
        let thumbInset = 18.5 / seek.frame.width
        #else
        let thumbInset = 8.0 / seek.frame.width
        #endif
        let thumbOffset = thumbInset + min(1, position / max(1, duration)) * (1 - thumbInset * 2)
        #if os(macOS)
        seek.coordinate(withNormalizedOffset: CGVector(dx: thumbOffset, dy: 0.5))
            .click(forDuration: 0.05, thenDragTo: seek.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 5)
        #else
        seek.coordinate(withNormalizedOffset: CGVector(dx: thumbOffset, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: seek.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 5)
        #endif
        XCTAssertTrue(controls.exists && controls.isHittable,
                      "Holding the scrubber beyond the idle timeout must not hide the active controls.")
        capture("Controls after five second scrub hold")
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false OR hittable == false"), object: controls)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 8), .completed,
                       "Playing video should hide idle controls automatically.")
        capture("Playback with controls hidden")
        showPlayerControls()
        XCTAssertTrue(controls.isHittable)
        activate(controls)
        XCTAssertTrue(waitForValueContaining("已暂停", in: controls, timeout: 5))
        let stillVisible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false OR hittable == false"), object: controls)
        XCTAssertEqual(XCTWaiter.wait(for: [stillVisible], timeout: 4), .timedOut,
                       "Paused video should keep its controls visible.")
        capture("Paused playback controls")
        activate(element("player.close"))
    }

    func testPlaybackRateAndSettingsCanReturnToVideo() {
        launch("--ui-fixtures")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        activate(firstMediaRow)
        showPlayerControls()
        XCTAssertTrue(waitForValueContaining("正在播放", in: element("player.playPause"), timeout: 10))
        activate(element("player.playPause"))
        XCTAssertTrue(waitForValueContaining("已暂停", in: element("player.playPause"), timeout: 5))
        activate(element("player.rate"))
        activate(menuAction("1.5×"))
        XCTAssertTrue(waitForValueContaining("1.5", in: element("player.rate"), timeout: 5))
        activate(element("player.rate"))
        activate(menuAction("1×"))
        activate(element("player.options"))
        XCTAssertTrue(app.navigationBars["播放设置"].waitForExistence(timeout: 5)
                      || app.staticTexts["播放设置"].exists)
        XCTAssertTrue(app.buttons["关闭字幕"].exists)
        capture("Playback settings")
        activate(element("player.options.done"))
        showPlayerControls()
        XCTAssertTrue(element("player.close").isHittable)
        activate(element("player.close"))
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 5))
    }

    #if os(macOS)
    func testFullScreenVideoFillsActualDisplayAndReturnsToWindow() throws {
        let screen = try XCTUnwrap(NSScreen.main?.frame)
        launch("--ui-fixtures", "--ui-width=620", "--ui-height=440")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        activate(firstMediaRow)
        showPlayerControls()
        activate(element("player.fullscreen"))
        let surface = element("player.surface")
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            surface.frame.width >= screen.width * 0.9 && surface.frame.height >= screen.height * 0.9
        }, object: surface)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 10), .completed,
                       "The actual video surface should fill the display, not remain a centered sheet.")
        capture("Mac full screen video")
        showPlayerControls()
        activate(element("player.fullscreen"))
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            surface.frame.width < screen.width * 0.9
        }, object: surface)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
        showPlayerControls()
        activate(element("player.close"))
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 5))
    }
    #else
    func testPhoneLandscapePlaybackKeepsControlsInsideScreen() {
        launch("--ui-fixtures")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        activate(firstMediaRow)
        showPlayerControls()
        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            window.frame.width > window.frame.height
        }, object: window)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 10), .completed)
        showPlayerControls()
        assertContentInsideWindow(element("player.close"))
        assertContentInsideWindow(element("player.playPause"))
        XCTAssertTrue(element("player.options").isHittable)
        capture("iPhone landscape video controls")
        activate(element("player.close"))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 5))
    }
    #endif

    func testMarkWatchedUpdatesRowAndSurvivesRelaunch() {
        launch("--ui-fixtures")
        let row = firstMediaRow
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        openContextMenu(on: row)
        activate(menuAction("标记为已看"))
        XCTAssertTrue(waitForValueContaining("已看", in: row, timeout: 5))
        capture("Watched video")

        app.terminate()
        app.launch()
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertTrue(waitForValueContaining("已看", in: row, timeout: 5))
    }

    func testClearViewingRecordAndRemoveEntryKeepsOtherRows() {
        launch("--ui-fixtures")
        let row = firstMediaRow
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        let itemID = row.identifier
        openContextMenu(on: row)
        activate(menuAction("标记为已看"))
        XCTAssertTrue(waitForValueContaining("已看", in: row, timeout: 5))
        openContextMenu(on: row)
        activate(menuAction("清除观看记录"))
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT value CONTAINS %@", "已看"), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 5), .completed)

        openContextMenu(on: row)
        activate(menuAction("从本地列表移除"))
        XCTAssertTrue(waitUntilMissing(element(itemID), timeout: 5))
        XCTAssertTrue(firstMediaRow.exists, "The second fixture video must remain available.")
    }

    func testNASFailureOffersRetryAndKeepsNavigationAvailable() {
        launch("--ui-source-error")
        XCTAssertTrue(element("browser.error").waitForExistence(timeout: 15))
        let retry = element("browser.error.action")
        XCTAssertTrue(retry.isEnabled)
        activate(retry)
        let loading = element("browser.loading")
        XCTAssertTrue(loading.exists || loading.waitForExistence(timeout: 5),
                      "Retry must begin a fresh directory request.")
        capture("NAS directory loading after retry")
        XCTAssertTrue(element("browser.error").waitForExistence(timeout: 10))
        XCTAssertFalse(firstMediaRow.exists)
        selectLocalFiles()
        XCTAssertTrue(element("library.empty").waitForExistence(timeout: 5))
        capture("Recoverable NAS directory failure")
    }

    func testNASDirectoryNavigationEmptyAndBack() {
        launch("--ui-source-fixtures")
        let prefix = "media.row.33CCCCCC-4444-5555-8888-AAAABBBBCCCC:"
        let movies = element(prefix + "Movies")
        XCTAssertTrue(movies.waitForExistence(timeout: 15))
        activate(movies)
        let empty = element(prefix + "Movies/Empty")
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        XCTAssertTrue(element("browser.up").exists)
        activate(empty)
        XCTAssertTrue(element("browser.empty").waitForExistence(timeout: 10))
        capture("Empty NAS subdirectory")

        activate(element("browser.up"))
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        activate(element("browser.up"))
        XCTAssertTrue(movies.waitForExistence(timeout: 10))
        selectLocalFiles()
        XCTAssertTrue(element("library.empty").waitForExistence(timeout: 5))
        XCTAssertFalse(movies.exists, "Changing source must discard the previous source's directory rows.")
    }

    func testUnavailableNASVideoCanRetryAndClose() {
        launch("--ui-source-fixtures")
        let video = element("media.row.33CCCCCC-4444-5555-8888-AAAABBBBCCCC:Episode 01.mp4")
        XCTAssertTrue(video.waitForExistence(timeout: 15))
        activate(video)
        XCTAssertTrue(element("player.error").waitForExistence(timeout: 10))
        let retry = app.buttons["重新播放"].firstMatch
        XCTAssertTrue(retry.isHittable)
        capture("Unavailable NAS video with retry")
        activate(retry)
        XCTAssertTrue(element("player.error").waitForExistence(timeout: 5))
        showPlayerControls()
        activate(element("player.close"))
        XCTAssertTrue(video.waitForExistence(timeout: 5))
    }

    func testCurrentListFilterShowsNoResults() {
        launch("--ui-fixtures")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        #if os(iOS)
        if !search.isHittable { app.swipeDown() }
        #endif
        activate(search)
        search.typeText("no-match-123456789")
        XCTAssertTrue(element("browser.noResults").waitForExistence(timeout: 5))
        XCTAssertFalse(firstMediaRow.exists)
        capture("File filter with no matches")
    }

    func testLightAppearanceAtStandardSize() {
        launch("--ui-fixtures", "--ui-appearance=light")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        XCTAssertTrue(firstMediaRow.isHittable)
        assertContentInsideWindow(firstMediaRow)
        capture("Light file browser")
    }

    func testDarkAppearanceAtNarrowSize() {
        launch("--ui-fixtures", "--ui-appearance=dark", "--ui-width=620", "--ui-height=440")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        XCTAssertTrue(firstMediaRow.isHittable)
        assertContentInsideWindow(firstMediaRow)
        #if os(macOS)
        XCTAssertLessThanOrEqual(app.windows.firstMatch.frame.width, 650,
                                 "The launch fixture must exercise the smallest supported window.")
        #endif
        capture("Dark narrow file browser")
        openSMBConnection()
        XCTAssertTrue(element("smb.host").waitForExistence(timeout: 5))
        XCTAssertTrue(element("smb.cancel").isHittable)
        capture("Dark narrow SMB sheet")
    }

    func testLargeTextKeepsFileAndSourceActionsReachable() {
        launch("--ui-fixtures", "--ui-content-size=accessibility3")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        XCTAssertTrue(firstMediaRow.isHittable)
        capture("Large text file browser")
        openSMBConnection()
        XCTAssertTrue(element("smb.host").waitForExistence(timeout: 5))
        XCTAssertTrue(element("smb.cancel").isHittable)
        capture("Large text SMB form")
    }

    func testReducedTransparencyKeepsControlsReadable() throws {
        #if os(macOS)
        let reducedTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        #else
        let restoreSystemPreference = enableReducedTransparencyForDedicatedRun()
        defer { restoreSystemPreference?() }
        let reducedTransparency = UIAccessibility.isReduceTransparencyEnabled
        #endif
        guard reducedTransparency else {
            throw XCTSkip("Enable the system Reduce Transparency setting for its dedicated UI run; launch arguments do not change this setting.")
        }
        launch("--ui-fixtures")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        XCTAssertTrue(firstMediaRow.isHittable)
        capture("Reduced transparency file browser")
    }

    func testAccessibilityDescriptions() throws {
        launch("--ui-fixtures")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        #if os(macOS)
        try app.performAccessibilityAudit(for: [.sufficientElementDescription]) { issue in
            let details = XCTAttachment(string: "\(issue.compactDescription)\n\(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "No associated element")")
            details.name = "Accessibility audit issue element"
            details.lifetime = .keepAlways
            self.add(details)
            return false // Record every audit issue; diagnostic output never filters failures.
        }
        #else
        try app.performAccessibilityAudit(for: [.sufficientElementDescription])
        #endif
    }

    private func launch(_ arguments: String...) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-test-session=\(session)",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + arguments
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        // Media IDs include sandbox paths; XCTest's string identifier query caps at 128 characters.
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", identifier)).firstMatch
    }

    private var firstMediaRow: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "media.row.")).firstMatch
    }

    private func activate(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: 5), file: file, line: line)
        #if os(macOS)
        let identifier = element.identifier
        if identifier.hasPrefix("player.") {
            let hittable = element.isHittable
            XCTAssertTrue(hittable, "The playback control must be visible at the click.", file: file, line: line)
            let frame = element.frame
            XCTAssertFalse(frame.isEmpty || frame.isInfinite || frame.isNull,
                           "The playback control must have a real visible frame.", file: file, line: line)
            let evidence = XCTAttachment(string: "\(identifier) frame=\(frame) hittable=\(hittable)")
            evidence.name = "Playback control before click"
            evidence.lifetime = .keepAlways
            add(evidence)
            if identifier == "player.close" {
                let window = app.windows.firstMatch
                let windowFrame = window.frame
                window.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                    .withOffset(CGVector(dx: frame.midX - windowFrame.minX,
                                         dy: frame.midY - windowFrame.minY)).click()
                return
            }
        }
        element.click()
        #else
        element.tap()
        #endif
    }

    private func selectContinueWatching() {
        selectSection(sidebar: "sidebar.continue", menu: "source.continue")
    }

    private func selectLocalFiles() {
        selectSection(sidebar: "sidebar.local", menu: "source.local")
    }

    private func selectSection(sidebar: String, menu: String) {
        if element(sidebar).exists {
            activate(element(sidebar))
        } else {
            activate(element("source.menu"))
            activate(element(menu))
        }
    }

    private func openSMBConnection() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        if element("sidebar.connectSMB").exists {
            activate(element("sidebar.connectSMB"))
        } else if element("library.connectSMB").exists {
            activate(element("library.connectSMB"))
        } else {
            activate(element("library.addMenu"))
            activate(element("library.connectSMB"))
        }
    }

    private func replaceText(in identifier: String, with value: String) {
        let field = app.textFields.matching(identifier: identifier).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        activate(field)
        #if os(macOS)
        field.typeKey("a", modifierFlags: .command)
        field.typeText(value)
        #else
        let current = field.value as? String ?? ""
        let deleteCount = current == field.placeholderValue ? 0 : current.count
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: deleteCount) + value)
        #endif
    }

    private func openContextMenu(on row: XCUIElement) {
        #if os(macOS)
        row.rightClick()
        #else
        row.press(forDuration: 1.2)
        #endif
    }

    private func showPlayerControls() {
        let controls = element("player.playPause")
        if controls.exists && controls.isHittable { return }
        activate(element("player.surface"))
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: controls)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 5), .completed,
                       "Tapping the video surface should reveal the native playback controls.")
    }

    private func playbackTimeText(_ element: XCUIElement) -> String {
        #if os(macOS)
        // SwiftUI Text exposes its visible text as AXValue in AppKit, rather than AXLabel.
        if let value = element.value as? String, !value.isEmpty { return value }
        #endif
        return element.label
    }

    #if os(iOS)
    private func revealAboveKeyboard(_ control: XCUIElement, navigation title: String = "连接 SMB") {
        for attempt in 0..<4 {
            let window = app.windows.firstMatch
            let windowFrame = window.frame
            let forms = app.collectionViews.allElementsBoundByIndex.filter {
                $0.exists && $0.label != "Sidebar" && $0.identifier != "browser.list" && $0.frame.height > 100
            }
            XCTAssertEqual(forms.count, 1, "The empty-source fixture must select its unique actual modal Form.")
            guard forms.count == 1, let form = forms.first else { return }
            let formFrame = form.frame
            let keyboard = app.keyboards.firstMatch
            let keyboardTop = keyboard.exists ? keyboard.frame.minY : windowFrame.maxY
            let intersection = formFrame.intersection(windowFrame)
            guard !intersection.isNull, !intersection.isEmpty,
                  intersection.width.isFinite, intersection.height.isFinite,
                  intersection.width > 0, intersection.height > 0 else {
                XCTFail("The native modal Form must have a valid visible intersection with the window.")
                return
            }
            let inputViews = app.otherElements.matching(NSPredicate(
                format: "identifier == %@ OR identifier == %@", "inputView", "SystemInputAssistantView"))
                .allElementsBoundByIndex
            var inputOcclusionTop = keyboardTop
            for inputView in inputViews where inputView.exists {
                let frame = inputView.frame
                guard frame.minX.isFinite, frame.minY.isFinite,
                      frame.width.isFinite, frame.height.isFinite,
                      frame.width > 0, frame.height > 0,
                      frame.maxX > intersection.minX, frame.minX < intersection.maxX,
                      frame.maxY > intersection.minY, frame.minY < intersection.maxY else { continue }
                inputOcclusionTop = min(inputOcclusionTop, frame.minY)
            }
            let visibleBottom = min(keyboardTop, inputOcclusionTop, intersection.maxY)
            if control.exists && control.frame.maxY < visibleBottom && control.isHittable { return }
            let navigation = app.navigationBars[title].firstMatch
            let visibleTop = max(intersection.minY, navigation.exists ? navigation.frame.maxY : intersection.minY)
            let startY = visibleBottom - 64
            let endY = visibleTop + 30
            guard startY.isFinite, endY.isFinite, startY > endY else {
                XCTFail("The native modal Form must have enough visible height above the keyboard to scroll.")
                return
            }
            let x = intersection.minX + intersection.width * 0.75
            guard x > intersection.minX else {
                XCTFail("The native modal Form must have enough visible width to scroll inside its bounds.")
                return
            }
            let attachment = XCTAttachment(string: "attempt=\(attempt) form=\(formFrame) visible=\(intersection) keyboardTop=\(keyboardTop) start=(\(x),\(startY)) end=(\(x),\(endY)) existsBefore=\(control.exists)")
            attachment.name = "Actual native modal Form scroll geometry"
            attachment.lifetime = .keepAlways
            add(attachment)
            let origin = window.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: x - windowFrame.minX, dy: startY - windowFrame.minY))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x - windowFrame.minX, dy: endY - windowFrame.minY)))
        }
        XCTFail("The native form control should be reachable above the keyboard.")
    }

    /// Opt in only on a dedicated simulator. Standard regression runs never change system preferences.
    private func enableReducedTransparencyForDedicatedRun() -> (() -> Void)? {
        guard ProcessInfo.processInfo.environment["AETHERFILM_UI_CHANGE_ACCESSIBILITY"] == "1",
              !UIAccessibility.isReduceTransparencyEnabled else { return nil }
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        settings.launch()
        openSetting("Accessibility", identifier: "ACCESSIBILITY", in: settings)
        openSetting("Display & Text Size", identifier: "DISPLAY_AND_TEXT", in: settings)
        let toggle = settings.switches["Reduce Transparency"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        // Settings exposes the entire row as a Switch; tap its actual trailing native switch.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Native Reduce Transparency setting"
        attachment.lifetime = .keepAlways
        add(attachment)
        return {
            settings.activate()
            if toggle.value as? String == "1" {
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            }
            XCTAssertEqual(toggle.value as? String, "0", "Restore the dedicated simulator's original preference.")
            settings.terminate()
        }
    }

    private func openSetting(_ label: String, identifier: String, in settings: XCUIApplication) {
        let entry = settings.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR identifier == %@", label, identifier)).firstMatch
        for _ in 0..<8 {
            if entry.exists && entry.isHittable { entry.tap(); return }
            settings.swipeUp()
        }
        let hierarchy = XCTAttachment(string: settings.debugDescription)
        hierarchy.name = "System Settings hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTFail("The native Settings entry \(label) should be reachable.")
    }
    #endif

    private func menuAction(_ label: String) -> XCUIElement {
        #if os(macOS)
        app.menuItems[label].firstMatch
        #else
        app.buttons[label].firstMatch
        #endif
    }

    private func waitUntilMissing(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func nativeValueString(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        return (value as? NSNumber)?.stringValue
    }

    private func waitForValueContaining(_ text: String, in element: XCUIElement, timeout: TimeInterval) -> Bool {
        if element.exists && (element.value as? String)?.contains(text) == true { return true }
        let predicate: NSPredicate
        if let expected = Int(text) {
            let number = NSNumber(value: expected)
            if element.exists && (element.value as? NSNumber) == number { return true }
            predicate = NSPredicate(format: "exists == true AND (value == %@ OR value CONTAINS %@)", number, text)
        } else {
            predicate = NSPredicate(format: "exists == true AND value CONTAINS %@", text)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func seconds(in label: String) -> Double {
        label.split(separator: ":").reduce(0) { $0 * 60 + (Double($1) ?? 0) }
    }

    private func assertContentInsideWindow(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.insetBy(dx: -1, dy: -1).contains(element.frame),
                      "The complete control or row should remain inside the visible window.", file: file, line: line)
        XCTAssertGreaterThan(element.frame.width, 0, file: file, line: line)
        XCTAssertGreaterThan(element.frame.height, 0, file: file, line: line)
    }

    private func capture(_ name: String) {
        #if os(macOS)
        let sheet = app.sheets.firstMatch
        let subject = sheet.exists ? sheet : app.windows.firstMatch
        let frame = subject.frame
        let screenshot = subject.screenshot()
        let geometry = XCTAttachment(string: "Native own-element screenshot type=\(subject.elementType.rawValue) frame=\(frame)")
        geometry.name = "Native screenshot window geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
        #else
        let screenshot = XCUIScreen.main.screenshot()
        #endif
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
