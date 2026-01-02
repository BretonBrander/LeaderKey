import Combine
import Foundation
import SwiftUI

final class UserState: ObservableObject {
  var userConfig: UserConfig!

  @Published var display: String?
  @Published var isShowingRefreshState: Bool
  @Published var navigationPath: [Group] = []
  @Published var selectedIndex: Int? = nil

  /// Callback for when an item is tapped in the cheatsheet
  var onItemTapped: ((ActionOrGroup) -> Void)?

  var currentGroup: Group? {
    return navigationPath.last
  }

  var currentActions: [ActionOrGroup] {
    currentGroup?.actions ?? userConfig?.root.actions ?? []
  }

  var selectedItem: ActionOrGroup? {
    guard let idx = selectedIndex, idx >= 0, idx < currentActions.count else { return nil }
    return currentActions[idx]
  }

  init(
    userConfig: UserConfig!,
    lastChar: String? = nil,
    isShowingRefreshState: Bool = false
  ) {
    self.userConfig = userConfig
    display = lastChar
    self.isShowingRefreshState = isShowingRefreshState
    self.navigationPath = []
  }

  func clear() {
    display = nil
    navigationPath = []
    isShowingRefreshState = false
    selectedIndex = nil
  }

  func navigateToGroup(_ group: Group) {
    navigationPath.append(group)
    selectedIndex = nil
  }
}
