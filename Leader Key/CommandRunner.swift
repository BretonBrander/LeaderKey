import Cocoa

/// Result of a command execution
enum CommandResult {
  case success
  case failure(title: String, details: String)
}

class CommandRunner {
  /// Default alert handler for showing errors
  static var alertHandler: AlertHandler = DefaultAlertHandler()

  /// Runs a shell command asynchronously (non-blocking)
  static func run(_ command: String) {
    runAsync(command) { result in
      if case .failure(let title, let details) = result {
        DispatchQueue.main.async {
          alertHandler.showAlert(style: .critical, message: title, informativeText: details, buttons: ["OK"])
        }
      }
    }
  }

  /// Runs a shell command asynchronously with completion handler
  static func runAsync(_ command: String, completion: @escaping (CommandResult) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
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

          let details = [error, output].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
          completion(.failure(
            title: "Command failed with exit code \(task.terminationStatus)",
            details: details
          ))
        } else {
          completion(.success)
        }
      } catch {
        completion(.failure(
          title: "Failed to run command",
          details: error.localizedDescription
        ))
      }
    }
  }

  /// Runs a shell script file with the given arguments asynchronously
  static func runScript(path: String, arguments: [String] = []) {
    let fileManager = FileManager.default
    let expandedPath = (path as NSString).expandingTildeInPath

    // Validate script exists (sync check is fine, it's fast)
    guard fileManager.fileExists(atPath: expandedPath) else {
      DispatchQueue.main.async {
        alertHandler.showAlert(
          style: .critical,
          message: "Script not found",
          informativeText: "The script file does not exist: \(path)",
          buttons: ["OK"]
        )
      }
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
