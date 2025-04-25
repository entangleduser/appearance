import SwiftUI

struct LocationView: View {
 @ContextAlias()
 private var module: AutoAppearance

 var body: some View {
  Location.InputForm(location: $module.location) {
   if module.mode == .auto {
    try await module.callContext(with: .active)
   }
  }
  .padding(11.5)
  .frame(width: 192, height: 91)
 }
}

private extension Location {
 struct InputForm: View {
  @Binding
  var location: Location
  let onUpdate: () async throws -> Void

  @State
  private var inputLocation: Location = .unknown
  @State
  private var x: String = .empty
  @State
  private var y: String = .empty

  private var xBinding: Binding<String> {
   Binding(
    get: { x },
    set: {
     if let value = Double($0), value.isNormal {
      inputLocation.x = value
      x = $0
     } else if $0.notEmpty {
      if $0 == "-" { return self.x = $0 }

      let x = inputLocation.x
      if x.isNormal {
       self.x = x.description
      }
     } else {
      x = .empty
      inputLocation.x = .infinity
     }
    }
   )
  }

  private var yBinding: Binding<String> {
   Binding(
    get: { y },
    set: {
     if let value = Double($0), value.isNormal {
      inputLocation.y = value
      y = $0
     } else if $0.notEmpty {
      if $0 == "-" { return self.y = $0 }

      let y = inputLocation.y
      if y.isNormal {
       self.y = y.description
      }
     } else {
      y = .empty
      inputLocation.y = .infinity
     }
    }
   )
  }

  var body: some View {
   VStack(spacing: 11.5) {
    GroupBox {
     HStack(alignment: .center, spacing: 4.5) {
      TextField(.empty, text: xBinding, prompt: Text("x"))
      Divider()
       .frame(height: 13)
      TextField(.empty, text: yBinding, prompt: Text("y"))
     }
     .textFieldStyle(.plain)
     .frame(height: 13)
    } label: {
     HStack {
      Text("Coordinates")
       .font(.caption)
       .foregroundStyle(.secondary)
       .offset(x: -7)
      Spacer()
     }
    }
    .fontWeight(.semibold)
    .task {
     inputLocation = location
     let x = location.x
     let y = location.y
     if x.isNormal {
      self.x = location.x.description
     }
     if y.isNormal {
      self.y = location.y.description
     }
    }
    .onChange(of: location) { oldValue, newValue in
     if oldValue != newValue {
      if newValue == .unknown {
       x = .empty
       y = .empty
      } else {
       inputLocation = newValue
       let x = newValue.x
       let y = newValue.y

       if x.isNormal {
        self.x = location.x.description
       } else {
        self.x = .empty
       }
       if y.isNormal {
        self.y = location.y.description
       } else {
        self.y = .empty
       }
      }
     }
    }
    HStack {
     let sameInput = inputLocation == location
     let invalidDescription = invalidDescription()
     Text(invalidDescription?.capitalized ?? "Custom")
      .font(.caption)
      .fontWeight(.semibold)
      .foregroundStyle(
       inputLocation == .unknown
        ? Color(nsColor: .tertiaryLabelColor)
        : inputLocation == .denied
        ? .red
        : invalidDescription != nil ? Color.red : .primary
      )
      .padding(.leading, 4.5)
     Spacer()
     Button("Update") {
      location = inputLocation

      Task { try await onUpdate() }
      closeLocationPanel()
     }
     .buttonStyle(.accessoryBarAction)
     .controlSize(.small)
     .font(.caption)
     .foregroundStyle(.secondary)
     .fontWeight(.regular)
     .disabled(
      invalidDescription == nil ? sameInput : invalidDescription! == "invalid"
     )
    }
   }
  }

  /// A description that only returns a string if `inputLocation` is invalid.
  func invalidDescription() -> String? {
   switch inputLocation {
   case .unknown: "unknown"
   case .denied: "denied"
   case let location where location.isInvalid: "invalid"
   default: nil
   }
  }
 }
}

// MARK: - Panel

private extension InterfaceID {
 static let locationPanel: Self = "panel.location"
}

private extension Panel {
 static let location = Panel(id: .locationPanel, rootView: LocationView())
}

extension View {
 @_transparent
 func openLocationPanel() {
  Panel.open(.location)
 }

 @_transparent
 func closeLocationPanel() {
  Panel.close(.location)
 }
}
