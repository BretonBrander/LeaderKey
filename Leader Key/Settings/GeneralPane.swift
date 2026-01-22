import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings
import SwiftUI

struct GeneralPane: View {
  private let contentWidth = 850.0
  @EnvironmentObject private var config: UserConfig
  @Default(.configDir) var configDir
  @Default(.theme) var theme
  @Default(.useCustomColors) var useCustomColors
  @Default(.customAccentColor) var customAccentColorData
  @Default(.customBackgroundColor) var customBackgroundColorData

  /// Binding to convert between stored Data and SwiftUI Color for accent
  private var accentColorBinding: Binding<Color> {
    Binding(
      get: {
        if let nsColor = NSColor.fromArchivedData(customAccentColorData) {
          return Color(nsColor)
        }
        return Color.accentColor
      },
      set: { newColor in
        if let cgColor = newColor.cgColor,
          let nsColor = NSColor(cgColor: cgColor)
        {
          customAccentColorData = nsColor.archivedData
        }
      }
    )
  }

  /// Binding to convert between stored Data and SwiftUI Color for background
  private var backgroundColorBinding: Binding<Color> {
    Binding(
      get: {
        if let nsColor = NSColor.fromArchivedData(customBackgroundColorData),
          nsColor != .clear
        {
          return Color(nsColor)
        }
        return Color.gray.opacity(0.3)
      },
      set: { newColor in
        if let cgColor = newColor.cgColor,
          let nsColor = NSColor(cgColor: cgColor)
        {
          customBackgroundColorData = nsColor.archivedData
        }
      }
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      // Config section outside Settings.Container for full-width layout
      VStack(alignment: .leading, spacing: 8) {
        Text("Config")
          .font(.headline)
          .foregroundStyle(.secondary)

        // AppKit-backed editor for maximum smoothness
        ConfigOutlineEditorView(root: $config.root)
          .frame(height: 500)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .inset(by: 1)
              .stroke(Color.primary, lineWidth: 1)
              .opacity(0.1)
          )

        if !config.validationErrors.isEmpty {
          ValidationWarningView(errors: config.validationErrors)
            .transition(.opacity)
        }

        HStack {
          // Left-aligned buttons
          HStack(spacing: 8) {
            Button(action: {
              config.root.actions.append(.action(Action(key: "", type: .application, value: "")))
            }) {
              Image(systemName: "rays")
              Text("Add Action")
            }

            Button(action: {
              config.root.actions.append(.group(Group(key: "", actions: [])))
            }) {
              Image(systemName: "folder")
              Text("Add Group")
            }

            Divider()
              .frame(height: 20)

            Button("Read from file") {
              config.reloadFromFile()
            }
          }

          Spacer()

          // Right-aligned buttons
          HStack(spacing: 8) {
            Button(action: {
              NotificationCenter.default.post(name: .lkExpandAll, object: nil)
            }) {
              Image(systemName: "chevron.down")
              Text("All")
            }

            Button(action: {
              NotificationCenter.default.post(name: .lkCollapseAll, object: nil)
            }) {
              Image(systemName: "chevron.right")
              Text("All")
            }

            Button(action: {
              NotificationCenter.default.post(name: .lkSortAZ, object: nil)
            }) {
              Image(systemName: "arrow.up.arrow.down")
              Text("Sort")
            }
          }
        }

        Divider()
          .padding(.vertical, 8)
      }
      .padding(.horizontal, 20)

      Settings.Container(contentWidth: contentWidth) {
        Settings.Section(title: "Shortcut") {
          KeyboardShortcuts.Recorder(for: .activate)
        }

        Settings.Section(title: "Theme") {
          Picker("Theme", selection: $theme) {
            ForEach(Theme.all, id: \.self) { value in
              Text(Theme.name(value)).tag(value)
            }
          }.frame(maxWidth: 170).labelsHidden()
        }

        Settings.Section(title: "Custom Colors") {
          HStack(spacing: 12) {
            Toggle("", isOn: $useCustomColors)
              .labelsHidden()
              .toggleStyle(.checkbox)

            HStack(spacing: 4) {
              SquareColorPicker(selection: backgroundColorBinding)
                .disabled(!useCustomColors)
              Text("Background")
                .foregroundStyle(useCustomColors ? .primary : .secondary)
            }

            HStack(spacing: 4) {
              SquareColorPicker(selection: accentColorBinding)
                .disabled(!useCustomColors)
              Text("Accent")
                .foregroundStyle(useCustomColors ? .primary : .secondary)
            }

            Button("Reset") {
              customAccentColorData = NSColor.controlAccentColor.archivedData
              customBackgroundColorData = NSColor.clear.archivedData
            }
            .disabled(!useCustomColors)
          }
        }

        Settings.Section(title: "App") {
          LaunchAtLogin.Toggle()
        }
      }
    }
  }
}

struct GeneralPane_Previews: PreviewProvider {
  static var previews: some View {
    return GeneralPane()
      .environmentObject(UserConfig())
  }
}

/// Compact banner that surfaces validation issues directly in the settings UI.
private struct ValidationWarningView: View {
  private let errors: [ValidationError]
  private let maxVisibleErrors = 3

  init(errors: [ValidationError]) {
    self.errors = errors
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(warningTitle)
        .font(.callout)
        .fontWeight(.semibold)

      VStack(alignment: .leading, spacing: 2) {
        ForEach(Array(errors.prefix(maxVisibleErrors))) { error in
          Text("• \(error.message)")
            .font(.caption)
        }

        if errors.count > maxVisibleErrors {
          Text("• …and \(errors.count - maxVisibleErrors) more issues")
            .font(.caption)
        }

        Text(
          "Configuration saves continue, but shortcuts tied to these keys may misbehave until fixed."
        )
        .font(.caption)
        .padding(.top, 4)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .textBackgroundColor))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.red.opacity(0.6), lineWidth: 1)
    )
    .cornerRadius(8)
    .foregroundColor(.red)
  }

  private var warningTitle: String {
    let count = errors.count
    let issueText = count == 1 ? "1 issue" : "\(count) issues"
    let pronoun = count == 1 ? "it" : "they"
    return "Configuration has \(issueText). Some shortcuts may not work until \(pronoun) are fixed."
  }
}

/// A square color picker button that opens the system color panel
private struct SquareColorPicker: View {
  @Binding var selection: Color
  @Environment(\.isEnabled) private var isEnabled

  private static var colorObserverKey: UInt8 = 0
  private let size: CGFloat = 14

  var body: some View {
    Button {
      openColorPanel()
    } label: {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(selection)
        .frame(width: size, height: size)
        .overlay(
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .opacity(isEnabled ? 1 : 0.5)
  }

  private func openColorPanel() {
    let panel = NSColorPanel.shared
    panel.showsAlpha = false
    panel.mode = .wheel

    // Clear old target/action FIRST to prevent triggering old observer
    panel.setTarget(nil)
    panel.setAction(nil)

    // Create and attach the new observer BEFORE setting the color
    let observer = ColorPanelObserver(binding: $selection)
    objc_setAssociatedObject(panel, &Self.colorObserverKey, observer, .OBJC_ASSOCIATION_RETAIN)
    panel.setTarget(observer)
    panel.setAction(#selector(ColorPanelObserver.colorChanged(_:)))

    // NOW set the current color (after observer is in place)
    if let cgColor = selection.cgColor,
      let nsColor = NSColor(cgColor: cgColor)
    {
      panel.color = nsColor
    }

    panel.orderFront(nil)
  }
}

/// Observer class to handle color panel changes
private class ColorPanelObserver: NSObject {
  private let binding: Binding<Color>

  init(binding: Binding<Color>) {
    self.binding = binding
  }

  @objc func colorChanged(_ sender: NSColorPanel) {
    binding.wrappedValue = Color(sender.color)
  }
}
