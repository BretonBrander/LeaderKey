import Cocoa
import Combine
import CryptoKit
import Defaults

class UserConfig: ObservableObject {
  @Published var root = emptyRoot {
    didSet {
      if !isLoading && root != emptyRoot && root != oldValue {
        saveConfigAsync()
      }
    }
  }
  @Published var validationErrors: [ValidationError] = []
  // O(1) lookup for row validation; keys are path strings like "1/0/3"
  @Published var validationErrorsByPath: [String: ValidationErrorType] = [:]

  let fileName = "config.json"
  private let alertHandler: AlertHandler
  private let fileManager: FileManager
  private var lastReadChecksum: String?
  private var isLoading = false
  private let configIOQueue = DispatchQueue(label: "ConfigIO", qos: .userInitiated)
  private var saveWorkItem: DispatchWorkItem?

  init(
    alertHandler: AlertHandler = DefaultAlertHandler(),
    fileManager: FileManager = .default
  ) {
    self.alertHandler = alertHandler
    self.fileManager = fileManager
  }

  // MARK: - Public Interface

  func ensureAndLoad() {
    ensureValidConfigDirectory()
    ensureConfigFileExists()
    loadConfig()
  }

  func reloadFromFile() {
    Events.send(.willReload)
    loadConfig(suppressAlerts: true)
    Events.send(.didReload)
  }

  func saveConfig() {
    // Check for file conflicts before saving
    if let lastChecksum = lastReadChecksum, exists {
      let currentChecksum = getCurrentFileChecksum()
      if currentChecksum != lastChecksum {
        let result = alertHandler.showAlert(
          style: .warning,
          message: "Configuration file changed on disk",
          informativeText:
            "The configuration file has been modified outside of the app. Choose 'Read from File' to load the external changes, or 'Overwrite' to save your current changes.",
          buttons: ["Overwrite", "Cancel", "Read from File"]
        )

        switch result {
        case .alertThirdButtonReturn:  // Read from File (rightmost, default)
          reloadFromFile()
          return
        case .alertFirstButtonReturn:  // Overwrite
          break  // Continue with save
        default:  // Cancel
          return
        }
      }
    }

    setValidationErrors(ConfigValidator.validate(group: root))

    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [
        .prettyPrinted, .withoutEscapingSlashes, .sortedKeys,
      ]
      let jsonData = try encoder.encode(root)

      try writeFile(data: jsonData)

      // Update checksum after successful write using data directly
      lastReadChecksum = calculateChecksum(jsonData)
    } catch {
      handleError(error, critical: true)
    }
  }

  private func saveConfigAsync() {
    // Cancel any pending save
    saveWorkItem?.cancel()

    // Create a new debounced save work item
    let currentRoot = root
    let workItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }

      // Perform file I/O on background queue
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]

      do {
        let jsonData = try encoder.encode(currentRoot)

        // Check conflicts on background queue first, then switch to main for UI
        if let lastChecksum = self.lastReadChecksum, self.exists {
          let currentChecksum = self.getCurrentFileChecksum()
          if currentChecksum != lastChecksum {
            DispatchQueue.main.async {
              let result = self.alertHandler.showAlert(
                style: .warning,
                message: "Configuration file changed on disk",
                informativeText:
                  "The configuration file has been modified outside of the app. Choose 'Read from File' to load the external changes, or 'Overwrite' to save your current changes.",
                buttons: ["Overwrite", "Cancel", "Read from File"]
              )

              switch result {
              case .alertThirdButtonReturn:  // Read from File
                self.reloadFromFile()
                return
              case .alertFirstButtonReturn:  // Overwrite
                break  // Continue with save
              default:  // Cancel
                return
              }

              // Continue with save after conflict resolution
              self.performSaveWithData(jsonData, currentRoot: currentRoot)
            }
            return
          }
        }

        DispatchQueue.main.async {
          self.performSaveWithData(jsonData, currentRoot: currentRoot)
        }
      } catch {
        DispatchQueue.main.async {
          self.handleError(error, critical: true)
        }
      }
    }

    saveWorkItem = workItem

    // Execute with 300ms debounce
    configIOQueue.asyncAfter(deadline: .now() + .milliseconds(300), execute: workItem)
  }

  private func performSaveWithData(_ jsonData: Data, currentRoot: Group) {
    // Validation on main queue
    let validationErrors = ConfigValidator.validate(group: currentRoot)
    setValidationErrors(validationErrors)

    // Back to background for file write
    configIOQueue.async { [weak self] in
      guard let self = self else { return }

      do {
        try self.writeFile(data: jsonData)

        DispatchQueue.main.async {
          // Update checksum on main queue using data directly
          self.lastReadChecksum = self.calculateChecksum(jsonData)
        }
      } catch {
        DispatchQueue.main.async {
          self.handleError(error, critical: true)
        }
      }
    }
  }

  // MARK: - Directory Management

  static func defaultDirectory() -> String {
    let appSupportDir = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let path = (appSupportDir.path as NSString).appendingPathComponent(
      "Leader Key")
    do {
      try FileManager.default.createDirectory(
        atPath: path, withIntermediateDirectories: true)
    } catch {
      fatalError("Failed to create config directory")
    }
    return path
  }

  private func ensureValidConfigDirectory() {
    let dir = Defaults[.configDir]
    let defaultDir = Self.defaultDirectory()

    if !fileManager.fileExists(atPath: dir) {
      alertHandler.showAlert(
        style: .warning,
        message:
          "Config directory does not exist: \(dir)\nResetting to default location."
      )
      Defaults[.configDir] = defaultDir
    }
  }

  // MARK: - File Operations

  var path: String {
    (Defaults[.configDir] as NSString).appendingPathComponent(fileName)
  }

  var url: URL {
    URL(fileURLWithPath: path)
  }

  var exists: Bool {
    fileManager.fileExists(atPath: path)
  }

  private func ensureConfigFileExists() {
    guard !exists else { return }

    do {
      try bootstrapConfig()
    } catch {
      handleError(error, critical: true)
    }
  }

  private func bootstrapConfig() throws {
    guard let data = defaultConfig.data(using: .utf8) else {
      throw NSError(
        domain: "UserConfig",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to encode default config"]
      )
    }
    try writeFile(data: data)
  }

  private func writeFile(data: Data) throws {
    try data.write(to: url, options: .atomic)
  }

  private func readFile() throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
  }

  private func calculateChecksum(_ content: String) -> String {
    let data = Data(content.utf8)
    return calculateChecksum(data)
  }

  private func calculateChecksum(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.compactMap { String(format: "%02x", $0) }.joined()
  }

  private func getCurrentFileChecksum() -> String? {
    guard exists else { return nil }
    do {
      let content = try readFile()
      return calculateChecksum(content)
    } catch {
      return nil
    }
  }

  // Background queue version
  private func getCurrentFileChecksumAsync(completion: @escaping (String?) -> Void) {
    configIOQueue.async { [weak self] in
      guard let self = self else {
        DispatchQueue.main.async { completion(nil) }
        return
      }

      let checksum = self.getCurrentFileChecksum()
      DispatchQueue.main.async { completion(checksum) }
    }
  }

  // MARK: - Config Loading

  private func loadConfig(suppressAlerts: Bool = false) {
    isLoading = true

    guard exists else {
      root = emptyRoot
      validationErrors = []
      isLoading = false
      return
    }

    configIOQueue.async { [weak self] in
      guard let self = self else { return }

      do {
        let configString = try self.readFile()

        guard let jsonData = configString.data(using: .utf8) else {
          throw NSError(
            domain: "UserConfig",
            code: 1,
            userInfo: [
              NSLocalizedDescriptionKey: "Failed to encode config file as UTF-8"
            ]
          )
        }

        let decoder = JSONDecoder()
        let decodedRoot = try decoder.decode(Group.self, from: jsonData)
        let checksum = self.calculateChecksum(configString)
        let validationErrors = ConfigValidator.validate(group: decodedRoot)

        DispatchQueue.main.async {
          self.root = decodedRoot
          self.lastReadChecksum = checksum
          self.setValidationErrors(validationErrors)
          self.isLoading = false

        }
      } catch {
        DispatchQueue.main.async {
          self.handleError(error, critical: false)
          self.isLoading = false
        }
      }
    }
  }

  // MARK: - Validation

  func validateWithoutAlerts() {
    setValidationErrors(ConfigValidator.validate(group: root))
  }

  func finishEditingKey() {
    validateWithoutAlerts()
    // Config saves automatically via didSet on root
  }

  // MARK: - Error Handling

  private func handleError(_ error: Error, critical: Bool) {
    alertHandler.showAlert(
      style: critical ? .critical : .warning, message: "\(error)")
    if critical {
      root = emptyRoot
      validationErrors = []
    }
  }
}

// MARK: - Validation helpers
extension UserConfig {
  private func pathKey(_ path: [Int]) -> String { path.map(String.init).joined(separator: "/") }

  func setValidationErrors(_ errors: [ValidationError]) {
    validationErrors = errors
    var map: [String: ValidationErrorType] = [:]
    for e in errors {
      map[pathKey(e.path)] = e.type
    }
    validationErrorsByPath = map
  }

  func validationError(at path: [Int]) -> ValidationErrorType? {
    validationErrorsByPath[pathKey(path)]
  }
}
