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
}
