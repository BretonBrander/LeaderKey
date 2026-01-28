import Cocoa
import Foundation

final class FavoritesProvider: NSObject, ObservableObject {
  @Published private(set) var favorites: [Action] = []

  private var query: NSMetadataQuery?
  private var excludedPaths = Set<String>()

  func refresh(excluding excluded: Set<String>) {
    let normalized = Set(excluded.map { FavoritesProvider.normalizePath($0) })
    excludedPaths = normalized

    if Thread.isMainThread {
      startQuery()
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.startQuery()
      }
    }
  }

  func clear() {
    favorites = []
    stopQuery()
  }

  deinit {
    stopQuery()
  }

  private func startQuery() {
    stopQuery()

    let query = NSMetadataQuery()
    query.searchScopes = [NSMetadataQueryUserHomeScope]
    query.predicate = NSPredicate(
      format: "(kMDItemLastUsedDate != NULL) && (ANY kMDItemContentTypeTree == %@ || ANY kMDItemContentTypeTree == %@ || ANY kMDItemContentTypeTree == %@)",
      "com.apple.application-bundle",
      "public.folder",
      "public.item"
    )
    query.sortDescriptors = [
      NSSortDescriptor(key: kMDItemLastUsedDate as String, ascending: false)
    ]

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(queryDidFinishGathering(_:)),
      name: .NSMetadataQueryDidFinishGathering,
      object: query
    )

    self.query = query
    query.start()
  }

  private func stopQuery() {
    guard let query else { return }
    NotificationCenter.default.removeObserver(
      self,
      name: .NSMetadataQueryDidFinishGathering,
      object: query
    )
    query.stop()
    self.query = nil
  }

  @objc private func queryDidFinishGathering(_ notification: Notification) {
    guard let query = notification.object as? NSMetadataQuery,
          query == self.query else { return }
    query.disableUpdates()
    let results = query.results.compactMap { $0 as? NSMetadataItem }
    let favorites = selectFavorites(from: results)
    DispatchQueue.main.async { [weak self] in
      self?.favorites = favorites
    }
    stopQuery()
  }

  private func selectFavorites(from results: [NSMetadataItem]) -> [Action] {
    var selections: [Type: Action] = [:]

    for item in results {
      guard selections.count < 3 else { break }
      guard let path = item.value(forAttribute: kMDItemPath as String) as? String else { continue }
      let normalizedPath = FavoritesProvider.normalizePath(path)
      guard !excludedPaths.contains(normalizedPath) else { continue }
      guard FileManager.default.fileExists(atPath: normalizedPath) else { continue }

      let contentTypes = item.value(forAttribute: kMDItemContentTypeTree as String) as? [String] ?? []

      let type: Type?
      if contentTypes.contains("com.apple.application-bundle") {
        type = .application
      } else if contentTypes.contains("public.folder") {
        type = .folder
      } else if contentTypes.contains("public.item") {
        type = .file
      } else {
        type = nil
      }

      guard let resolvedType = type else { continue }
      guard selections[resolvedType] == nil else { continue }

      selections[resolvedType] = Action(key: nil, type: resolvedType, value: normalizedPath)
    }

    return [
      selections[.application],
      selections[.folder],
      selections[.file],
    ].compactMap { $0 }
  }

  private static func normalizePath(_ path: String) -> String {
    URL(fileURLWithPath: path).standardizedFileURL.path
  }
}
