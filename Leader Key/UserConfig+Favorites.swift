import Foundation

extension UserConfig {
  func actionValues(for types: Set<Type>) -> Set<String> {
    var values = Set<String>()

    func collect(from items: [ActionOrGroup]) {
      for item in items {
        switch item {
        case .action(let action):
          if types.contains(action.type) {
            values.insert(action.value)
          }
        case .group(let group):
          collect(from: group.actions)
        }
      }
    }

    collect(from: root.actions)
    return values
  }
}
