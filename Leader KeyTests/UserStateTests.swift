import XCTest

@testable import Leader_Key

final class UserStateTests: XCTestCase {
  var userConfig: UserConfig!
  var subject: UserState!

  override func setUp() {
    super.setUp()
    userConfig = UserConfig()
    userConfig.root = Group(
      key: nil,
      label: "Root",
      actions: [
        .action(Action(key: "a", type: .application, value: "/Applications/App1.app")),
        .action(Action(key: "b", type: .application, value: "/Applications/App2.app")),
        .group(
          Group(
            key: "c",
            label: "Subgroup",
            actions: [
              .action(Action(key: "d", type: .application, value: "/Applications/App3.app")),
              .action(Action(key: "e", type: .application, value: "/Applications/App4.app")),
            ]
          )),
      ]
    )
    subject = UserState(userConfig: userConfig)
  }

  override func tearDown() {
    subject = nil
    userConfig = nil
    super.tearDown()
  }

  // MARK: - Selection Bounds Tests

  // Test that selectedItem safely returns nil for out-of-bounds indices
  func testSelectedItemReturnsNilForOutOfBoundsIndex() {
    subject.selectedIndex = 99
    XCTAssertNil(subject.selectedItem, "Out of bounds index should return nil, not crash")

    subject.selectedIndex = -1
    XCTAssertNil(subject.selectedItem, "Negative index should return nil, not crash")
  }

  // Test that selection correctly identifies different item types
  func testSelectedItemDistinguishesActionsFromGroups() {
    // Select an action
    subject.selectedIndex = 0
    if case .action(let action) = subject.selectedItem {
      XCTAssertEqual(action.key, "a")
    } else {
      XCTFail("Index 0 should be an action")
    }

    // Select a group
    subject.selectedIndex = 2
    if case .group(let group) = subject.selectedItem {
      XCTAssertEqual(group.key, "c")
      XCTAssertEqual(group.actions.count, 2, "Group should have its nested actions")
    } else {
      XCTFail("Index 2 should be a group")
    }
  }

  // MARK: - Navigation State Tests

  // Test that navigating into a group changes the available actions
  func testNavigationChangesCurrentActions() {
    // At root level, should have 3 items
    XCTAssertEqual(subject.currentActions.count, 3)

    // Navigate into the subgroup
    guard case .group(let subgroup) = userConfig.root.actions[2] else {
      XCTFail("Expected a group at index 2")
      return
    }
    subject.navigateToGroup(subgroup)

    // Should now show the subgroup's 2 items
    XCTAssertEqual(subject.currentActions.count, 2)

    // Selection in subgroup should return subgroup items
    subject.selectedIndex = 0
    if case .action(let action) = subject.selectedItem {
      XCTAssertEqual(action.key, "d", "First item in subgroup should be 'd'")
    } else {
      XCTFail("Expected action 'd' in subgroup")
    }
  }

  // Test that navigating resets selection to prevent stale state
  func testNavigationResetsSelection() {
    // Select item 2 at root
    subject.selectedIndex = 2

    // Navigate into a group
    let group = Group(key: "x", label: "Test", actions: [])
    subject.navigateToGroup(group)

    // Selection should be reset to avoid pointing at wrong item
    XCTAssertNil(
      subject.selectedIndex,
      "Selection should reset when navigating to prevent invalid selection state")
  }

  // Test multi-level navigation builds correct path
  func testMultiLevelNavigationPath() {
    let level1 = Group(key: "1", label: "Level 1", actions: [])
    let level2 = Group(key: "2", label: "Level 2", actions: [])

    subject.navigateToGroup(level1)
    XCTAssertEqual(subject.navigationPath.count, 1)
    XCTAssertEqual(subject.currentGroup?.key, "1")

    subject.navigateToGroup(level2)
    XCTAssertEqual(subject.navigationPath.count, 2)
    XCTAssertEqual(subject.currentGroup?.key, "2")
  }

  // MARK: - Clear State Tests

  // Test that clear() fully resets all navigation state
  func testClearResetsAllState() {
    // Set up some state
    subject.selectedIndex = 1
    subject.display = "test"
    subject.navigateToGroup(Group(key: "x", label: "Test", actions: []))

    subject.clear()

    XCTAssertNil(subject.selectedIndex, "Selection should be cleared")
    XCTAssertNil(subject.display, "Display should be cleared")
    XCTAssertTrue(subject.navigationPath.isEmpty, "Navigation path should be cleared")
    XCTAssertNil(subject.currentGroup, "Current group should be nil after clear")
  }

  // MARK: - Edge Cases

  // Test behavior with nil userConfig (defensive programming)
  func testCurrentActionsWithNilUserConfig() {
    let state = UserState(userConfig: nil)
    XCTAssertTrue(state.currentActions.isEmpty, "Should return empty array, not crash")
    XCTAssertNil(state.selectedItem, "Should return nil when no config")
  }

  // Test behavior with empty group
  func testSelectionInEmptyGroup() {
    let emptyConfig = UserConfig()
    emptyConfig.root = Group(key: nil, label: "Empty", actions: [])
    let state = UserState(userConfig: emptyConfig)

    // Even with a selection index set, should return nil safely
    state.selectedIndex = 0
    XCTAssertNil(state.selectedItem, "Should return nil for empty actions list")
    XCTAssertTrue(state.currentActions.isEmpty)
  }

  // Test that currentGroup correctly reflects navigation state
  func testCurrentGroupReflectsNavigation() {
    // Initially no group (at root)
    XCTAssertNil(subject.currentGroup)

    // Navigate to subgroup
    guard case .group(let subgroup) = userConfig.root.actions[2] else {
      XCTFail("Expected a group")
      return
    }
    subject.navigateToGroup(subgroup)

    // currentGroup should be the subgroup
    XCTAssertEqual(subject.currentGroup?.key, "c")
    XCTAssertEqual(subject.currentGroup?.label, "Subgroup")
  }

  // MARK: - Real Usage Scenarios

  // Simulate user navigating down through items and into a group
  func testTypicalNavigationFlow() {
    // User activates Leader Key - starts at root with no selection
    XCTAssertNil(subject.selectedIndex)
    XCTAssertEqual(subject.currentActions.count, 3)

    // User presses down arrow - selects first item
    subject.selectedIndex = 0
    XCTAssertNotNil(subject.selectedItem)

    // User presses down twice more - selects the group
    subject.selectedIndex = 2
    guard case .group(let group) = subject.selectedItem else {
      XCTFail("Should have group selected")
      return
    }

    // User presses right arrow - enters group
    subject.navigateToGroup(group)
    XCTAssertNil(subject.selectedIndex, "Selection resets on navigation")
    XCTAssertEqual(subject.currentActions.count, 2, "Now showing subgroup items")

    // User presses down - selects first subgroup item
    subject.selectedIndex = 0
    if case .action(let action) = subject.selectedItem {
      XCTAssertEqual(action.key, "d")
    } else {
      XCTFail("Expected action 'd'")
    }

    // User presses escape/clears - returns to initial state
    subject.clear()
    XCTAssertNil(subject.selectedIndex)
    XCTAssertTrue(subject.navigationPath.isEmpty)
    XCTAssertEqual(subject.currentActions.count, 3, "Back at root")
  }
}
