import SwiftUI

struct ContentView: View {
 @ObservedObject
 private var launchStatus = AppearanceApp.launchStatusObserver
 @ContextAlias()
 private var module: AutoAppearance

 var body: some View {
  Group {
   Picker(selection: $module.mode) {
    ForEach(Mode.allCases) {
     Text($0.rawValue.capitalized).tag($0.rawValue)
    }
   } label: {
    Text("Appearance")
   }
   .pickerStyle(.inline)

   if module.mode == .auto, let predictions = module.predictions {
    let isDaytime = predictions.isDaytime

    let sunsetSection = Section {
     #if DEBUG
     Text(
      "\(predictions.sunset.formatted(date: .omitted, time: .standard))"
     )
     #else
     Text(
      "\(predictions.sunset.formatted(date: .omitted, time: .shortened))"
     )
     #endif
    } header: {
     Text(isDaytime ? "Sunset" + .space + "􀄩" : "Sunset")
    }
    let sunriseSection = Section {
     #if DEBUG
     Text(
      "\(predictions.sunrise.formatted(date: .omitted, time: .standard))"
     )
     #else
     Text(
      "\(predictions.sunrise.formatted(date: .omitted, time: .shortened))"
     )
     #endif
    } header: {
     Text(!isDaytime ? "Sunrise" + .space + "􀄨" : "Sunrise")
    }

    Group {
     if predictions.isDaytime {
      sunsetSection
      sunriseSection
     } else {
      sunriseSection
      sunsetSection
     }
    }
    .font(.system(size: 11.5))
    .fontWeight(.semibold)
   }

   Divider()
   Menu("Settings") {
    Toggle("Launch at login", isOn: $launchStatus.isEnabled)
    Toggle("Allow transitions", isOn: $module.transition)
    
    Divider()
    Button("Location…") {
     openLocationPanel()
    }
   }

   Divider()
   Button("Quit \(module.configuration.name)", role: .destructive) {
    NSApplication.shared.terminate(nil)
   }
   .keyboardShortcut("q", modifiers: .command)
   .font(.system(size: 11.5))
  }
  .font(.system(size: 13))
 }
}
