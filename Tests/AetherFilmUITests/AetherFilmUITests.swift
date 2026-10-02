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

        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["取消", "Cancel"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "The system file picker should open.")
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
        let connect = element("smb.connect")
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        XCTAssertFalse(connect.isEnabled)

        replaceText(in: "smb.host", with: "nas.example.invalid")
        XCTAssertFalse(connect.isEnabled, "A host alone must not allow connection.")
        replaceText(in: "smb.share", with: "Videos")
        XCTAssertTrue(connect.isEnabled)

        activate(element("smb.advanced"))
        XCTAssertTrue(element("smb.port").waitForExistence(timeout: 5))
        replaceText(in: "smb.port", with: "0")
        XCTAssertFalse(connect.isEnabled)
        replaceText(in: "smb.port", with: "65536")
        XCTAssertFalse(connect.isEnabled)
        replaceText(in: "smb.port", with: "445")
        XCTAssertTrue(connect.isEnabled)
        let encryption = element("smb.encryption")
        XCTAssertTrue(encryption.exists)
        XCTAssertEqual(encryption.value as? String, "0")
        activate(encryption)
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
        XCTAssertTrue(element("player.close").waitForExistence(timeout: 15))
        XCTAssertTrue(element("player.playPause").waitForExistence(timeout: 15))
        XCTAssertFalse(element("player.error").exists)
        capture("Player opened from local video")
        activate(element("player.close"))
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    func testPlaybackAdvancesAndCreatesContinueRecord() {
        launch("--ui-fixtures")
        XCTAssertTrue(firstMediaRow.waitForExistence(timeout: 15))
        activate(firstMediaRow)
        let elapsed = element("player.time")
        XCTAssertTrue(elapsed.waitForExistence(timeout: 15))
        let initialTime = elapsed.label
        let advanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", initialTime), object: elapsed)
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 12), .completed,
                       "The decoded video must advance instead of only showing controls.")
        activate(element("player.playPause"))
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
        XCTAssertTrue(element("browser.loading").waitForExistence(timeout: 5), "Retry must begin a fresh directory request.")
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
        openSMBConnection()
        XCTAssertTrue(element("smb.host").waitForExistence(timeout: 5))
        XCTAssertTrue(element("smb.cancel").isHittable)
        capture("Large text SMB form")
    }

    func testReducedTransparencyKeepsControlsReadable() throws {
        #if os(macOS)
        let reducedTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        #else
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
        try app.performAccessibilityAudit(for: [.sufficientElementDescription])
    }

    private func launch(_ arguments: String...) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-test-session=\(session)",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + arguments
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private var firstMediaRow: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "media.row.")).firstMatch
    }

    private func activate(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        #if os(macOS)
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

    private func waitForValueContaining(_ text: String, in element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", text), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func assertContentInsideWindow(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)), file: file, line: line)
        XCTAssertGreaterThan(element.frame.width, 0, file: file, line: line)
        XCTAssertGreaterThan(element.frame.height, 0, file: file, line: line)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
