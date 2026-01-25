import Foundation

extension Action {
  static func isExecutableScript(_ url: URL) -> Bool {
    let scriptExtensions = ["sh", "bash", "zsh", "py", "rb", "pl", "swift"]
    return scriptExtensions.contains(url.pathExtension.lowercased())
  }

  static func createFrom(url: URL) -> Action {
    let path = url.path
    let filename = url.deletingPathExtension().lastPathComponent
    let firstLetter = String(filename.prefix(1)).lowercased()

    let type: Type
    if path.hasSuffix(".app") {
      type = .application
    } else if isExecutableScript(url) {
      type = .script
    } else {
      var isDirectory: ObjCBool = false
      if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
        isDirectory.boolValue
      {
        type = .folder
      } else {
        type = .file
      }
    }

    return Action(
      key: firstLetter.isEmpty ? nil : firstLetter,
      type: type,
      value: path
    )
  }
}
