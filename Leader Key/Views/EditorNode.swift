import Foundation

// MARK: - Editor Payload (used by cells to communicate changes)

enum EditorPayload {
  case action(Action)
  case group(Group)
}

// MARK: - Editor Node (tree model for outline view)

class EditorNode: NSObject {
  enum Kind {
    case action(Action)
    case group(Group)
  }

  var id = UUID()
  var kind: Kind
  weak var parent: EditorNode?
  var children: [EditorNode] = []

  var isGroup: Bool {
    if case .group = kind { return true } else { return false }
  }

  init(kind: Kind, parent: EditorNode? = nil) {
    self.kind = kind
    self.parent = parent
    super.init()
  }

  static func action(_ a: Action, parent: EditorNode?) -> EditorNode {
    EditorNode(kind: .action(a), parent: parent)
  }

  static func group(_ g: Group, parent: EditorNode? = nil) -> EditorNode {
    EditorNode(kind: .group(g), parent: parent)
  }

  static func from(group: Group, parent: EditorNode? = nil) -> EditorNode {
    let node = EditorNode.group(group, parent: parent)
    node.children = group.actions.map { child in
      switch child {
      case .action(let a):
        return EditorNode.action(a, parent: node)
      case .group(let g):
        return from(group: g, parent: node)
      }
    }
    return node
  }

  func toGroup() -> Group {
    switch kind {
    case .group(var g):
      g.actions = children.map { $0.toActionOrGroup() }
      return g
    case .action:
      // Root always a group
      return Group(key: nil, actions: children.map { $0.toActionOrGroup() })
    }
  }

  func toActionOrGroup() -> ActionOrGroup {
    switch kind {
    case .action(let a): return .action(a)
    case .group(var g):
      g.actions = children.map { $0.toActionOrGroup() }
      return .group(g)
    }
  }

  func apply(_ payload: EditorPayload) {
    switch (kind, payload) {
    case (.action, .action(let a)): kind = .action(a)
    case (.group, .group(let g)): kind = .group(g)
    default: break
    }
  }

  func deleteFromParent() {
    guard let p = parent else { return }
    if let idx = p.children.firstIndex(where: { $0 === self }) {
      p.children.remove(at: idx)
    }
  }

  func duplicateInParent() {
    guard let p = parent else { return }
    let copy = deepCopy(newParent: p)
    if let idx = p.children.firstIndex(where: { $0 === self }) {
      p.children.insert(copy, at: idx)
    }
  }

  private func deepCopy(newParent: EditorNode?) -> EditorNode {
    let copy = EditorNode(kind: kind, parent: newParent)
    copy.children = children.map { $0.deepCopy(newParent: copy) }
    return copy
  }
}

