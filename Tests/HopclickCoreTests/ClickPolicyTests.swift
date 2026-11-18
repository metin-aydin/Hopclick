import CoreGraphics
import XCTest
@testable import HopclickCore

/// Two 1000×800 displays side by side: left (main) at x 0, right at x 1000.
private let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
private let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
private let displays = [left, right]
private let own: Int32 = 1

private func window(_ id: UInt32, pid: Int32, _ rect: CGRect, layer: Int = 0, owner: String = "") -> WindowInfo {
    WindowInfo(id: id, pid: pid, layer: layer, bounds: rect, ownerName: owner)
}

private let editor = window(10, pid: 100, CGRect(x: 50, y: 50, width: 600, height: 500))
private let browser = window(20, pid: 200, CGRect(x: 1100, y: 50, width: 700, height: 600))

private func context(_ point: CGPoint, _ windows: [WindowInfo], front: Int32? = 100, scope: Scope = .acrossDisplays,
                     modifier: Bool = false) -> ClickContext {
    ClickContext(point: point, windows: windows, displays: displays, frontmostPID: front, ownPID: own, scope: scope,
                 commandOrControlHeld: modifier)
}

final class ClickPolicyTests: XCTestCase {
    func testClickOnOtherDisplayActivatesWindowThere() {
        let decision = ClickPolicy.decide(context(CGPoint(x: 1300, y: 300), [editor, browser]))
        XCTAssertEqual(decision, .activate(browser, clickDisplay: right))
    }

    func testClickOnFocusedDisplayIsLeftToMacOS() {
        let other = window(30, pid: 300, CGRect(x: 700, y: 100, width: 200, height: 200))
        let decision = ClickPolicy.decide(context(CGPoint(x: 800, y: 150), [editor, other, browser]))
        XCTAssertEqual(decision, .pass(.sameDisplay))
    }

    func testEverywhereScopeActsOnSameDisplay() {
        let other = window(30, pid: 300, CGRect(x: 700, y: 100, width: 200, height: 200))
        let decision = ClickPolicy.decide(context(CGPoint(x: 800, y: 150), [editor, other], scope: .everywhere))
        XCTAssertEqual(decision, .activate(other, clickDisplay: left))
    }

    func testCommandOrControlClickIsLeftAlone() {
        let decision = ClickPolicy.decide(context(CGPoint(x: 1300, y: 300), [editor, browser], modifier: true))
        XCTAssertEqual(decision, .pass(.modifierHeld))
    }

    func testOpenMenuBlocksActivation() {
        let menu = window(5, pid: 100, CGRect(x: 60, y: 60, width: 200, height: 300), layer: WindowLayer.popUpMenu)
        let decision = ClickPolicy.decide(context(CGPoint(x: 1300, y: 300), [menu, editor, browser]))
        XCTAssertEqual(decision, .pass(.menuOpen))
    }

    func testMenuBarIsLeftAlone() {
        let bar = window(3, pid: 50, CGRect(x: 1000, y: 0, width: 1000, height: 24), layer: WindowLayer.mainMenu)
        let decision = ClickPolicy.decide(context(CGPoint(x: 1300, y: 10), [bar, editor, browser]))
        XCTAssertEqual(decision, .pass(.menuBar))
    }

    func testFullDisplayBackdropIsLookedThrough() {
        let dock = window(4, pid: 60, right, layer: 20, owner: "Dock")
        let cursor = window(2, pid: 0, CGRect(x: 1295, y: 295, width: 20, height: 20), layer: 2_147_483_630)
        let decision = ClickPolicy.decide(context(CGPoint(x: 1300, y: 300), [cursor, dock, editor, browser]))
        XCTAssertEqual(decision, .activate(browser, clickDisplay: right))
    }

    func testFloatingPanelIsNotATarget() {
        let panel = window(6, pid: 400, CGRect(x: 1200, y: 200, width: 300, height: 300), layer: 3)
        let decision = ClickPolicy.decide(context(CGPoint(x: 1300, y: 300), [panel, editor, browser]))
        XCTAssertEqual(decision, .pass(.overlayWindow))
    }

    func testEmptyDesktopAreaPasses() {
        let decision = ClickPolicy.decide(context(CGPoint(x: 1900, y: 750), [editor, browser]))
        XCTAssertEqual(decision, .pass(.noWindowUnderCursor))
    }

    func testOwnWindowsAreNeverTargets() {
        let mine = window(7, pid: own, CGRect(x: 1200, y: 200, width: 300, height: 300))
        let decision = ClickPolicy.decide(context(CGPoint(x: 1300, y: 300), [editor, mine, browser]))
        XCTAssertEqual(decision, .pass(.ownApplication))
    }

    func testAlreadyFrontWindowOfFrontmostAppPasses() {
        let decision = ClickPolicy.decide(context(CGPoint(x: 1300, y: 300), [browser, editor], front: 200,
                                                  scope: .everywhere))
        XCTAssertEqual(decision, .pass(.alreadyFrontWindow))
    }

    func testSecondWindowOfFrontmostAppOnOtherDisplayIsActivated() {
        let editorRight = window(11, pid: 100, CGRect(x: 1100, y: 100, width: 500, height: 400))
        let decision = ClickPolicy.decide(context(CGPoint(x: 1300, y: 300), [editor, editorRight]))
        XCTAssertEqual(decision, .activate(editorRight, clickDisplay: right))
    }

    func testFocusDisplayFallsBackToTopmostWindowWhenFrontAppHasNone() {
        // Finder frontmost after a desktop click: no Finder window, focus follows the topmost window (editor, left).
        let decision = ClickPolicy.decide(context(CGPoint(x: 1300, y: 300), [editor, browser], front: 999))
        XCTAssertEqual(decision, .activate(browser, clickDisplay: right))
    }

    func testWindowsToRestoreOnlyWhereTargetAppAlsoHasAWindow() {
        let browserLeft = window(21, pid: 200, CGRect(x: 100, y: 100, width: 400, height: 400))
        let windows = [editor, browserLeft, browser]
        let restore = ClickPolicy.windowsToRestore(targetPID: 200, clickDisplay: right, windows: windows,
                                                   displays: displays)
        XCTAssertEqual(restore, [editor])
        XCTAssertEqual(ClickPolicy.windowsToRestore(targetPID: 200, clickDisplay: right, windows: [editor, browser],
                                                    displays: displays), [])
    }

    func testDisplayMostlyCovering() {
        let straddling = CGRect(x: 900, y: 0, width: 300, height: 100)
        XCTAssertEqual(Geometry.display(mostlyCovering: straddling, in: displays), right)
    }
}

final class VersionTests: XCTestCase {
    func testCompare() {
        XCTAssertTrue(Version.isNewer("0.1.10", than: "0.1.9"))
        XCTAssertTrue(Version.isNewer("v1.0.0", than: "0.9.9"))
        XCTAssertFalse(Version.isNewer("1.0.0", than: "1.0.0"))
        XCTAssertFalse(Version.isNewer("1.0.0-beta", than: "1.0.0"))
        XCTAssertEqual(Version.compare("1.2", "1.2.0"), 0)
    }
}
