import Cocoa

class CommandRunner {
  static func run(_ command: String) {
    let task = Process()
    let pipe = Pipe()
    let errorPipe = Pipe()

    task.standardOutput = pipe
    task.standardError = errorPipe
    task.launchPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/sh"
    task.arguments = ["-c", command]

    do {
      try task.run()
      task.waitUntilExit()

      if task.terminationStatus != 0 {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let error = String(data: errorData, encoding: .utf8) ?? ""
        let output = String(data: outputData, encoding: .utf8) ?? ""

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Command failed with exit code \(task.terminationStatus)"
        alert.informativeText = [error, output].joined(separator: "\n").trimmingCharacters(
          in: .whitespacesAndNewlines)
        alert.runModal()
      }
    } catch {
      let alert = NSAlert()
      alert.alertStyle = .critical
      alert.messageText = "Failed to run command"
      alert.informativeText = error.localizedDescription
      alert.runModal()
    }
  }

  /// Runs a shell script file with the given arguments
  static func runScript(path: String, arguments: [String] = []) {
    let fileManager = FileManager.default
    let expandedPath = (path as NSString).expandingTildeInPath

    // Validate script exists
    guard fileManager.fileExists(atPath: expandedPath) else {
      let alert = NSAlert()
      alert.alertStyle = .critical
      alert.messageText = "Script not found"
      alert.informativeText = "The script file does not exist: \(path)"
      alert.runModal()
      return
    }

    // Build the command with properly escaped path and arguments
    var commandParts = [shellEscape(expandedPath)]
    commandParts.append(contentsOf: arguments.map { shellEscape($0) })
    let command = commandParts.joined(separator: " ")

    run(command)
  }

  /// Escapes a string for safe use in shell commands
  static func shellEscape(_ string: String) -> String {
    // If string contains no special characters, return as-is
    let safeChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./"))
    if string.unicodeScalars.allSatisfy({ safeChars.contains($0) }) {
      return string
    }
    // Otherwise, wrap in single quotes and escape any single quotes within
    let escaped = string.replacingOccurrences(of: "'", with: "'\"'\"'")
    return "'\(escaped)'"
  }
}
