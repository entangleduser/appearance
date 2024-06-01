import Acrylic
import SwiftUI

@main
struct AppearanceApp: App {
 @ContextAlias(AutoAppearance.self, true)
 var module

 var body: some Scene {
  MenuBarExtra(
   module.configuration.name, systemImage: {
    switch module.mode {
    case .dark: "moon.fill"
    case .light: "sun.max"
    default: "moon.stars"
    }
   }(),
   content: ContentView.init
  )
 }

 init() {
  guard
   NSRunningApplication
    .runningApplications(
     withBundleIdentifier: module.configuration.identifier.unsafelyUnwrapped
    ).count == 1 else {
   let alert = NSAlert()
   alert.messageText =
    """
    \(module.configuration.name) already started. \
    Only one instance can be open at a time.
    """
   alert.runModal()
   exit(1)
  }
  
  if module.transition { Mode.checkScreenCaptureStatus() }
 }
}
