@_exported import Acrylic
import Configuration
import Persistence
import ServiceManagement

/// A module that controls the appearance of the system.
struct AutoAppearance: ContextModule {
 static var shared = AutoAppearance()
 let configuration: Configuration = .default

 @DefaultContext(.mode)
 var mode: Mode {
  willSet {
   // update state, or else the menu will remain inconsistent
   Task { @MainActor in await contextWillChange.send() }
  }
  didSet {
   // call void function as active so the switch statement can be rebuilt
   // it's idle by default to prevent unessesecary rebuilds
   guard oldValue != mode else { return }
   callContext(with: .active)
  }
 }

 @DefaultContext(.location)
 var location: Location
 @Context
 var predictions: Solar.PhasePredictions!
 @Context
 var authorizationLevel: Location.AuthorizationLevel = .authorizedAlways
 @StandardDefault(.transition)
 var transition

 var void: some Module {
  switch mode {
  case .dark, .light:
   Mode.Set(to: mode, transition: transition)
  default:
   Mode.Auto(
    location: $location, predictions: $predictions,
    authorizationLevel: authorizationLevel,
    transition: transition
   ) { @MainActor solar in
    /// update after making predictions available
    await contextWillChange.send()
    self.location = solar.location
    assert(DefaultContext(.location).wrappedValue == solar.location)
   }
  }
 }
}

// MARK: - Launch
// source: https://github.com/sindresorhus/LaunchAtLogin-Modern
extension AppearanceApp {
 static let launchStatusObserver = LaunchStatusObserver()
 static let launchStatusLog = Configuration.log(
  category: "loginStatus", level: .error
 )

 static var shouldLaunchAutomatically: Bool {
  get { SMAppService.mainApp.status == .enabled }
  set {
   launchStatusObserver.objectWillChange.send()

   do {
    if newValue {
     if SMAppService.mainApp.status == .enabled {
      try? SMAppService.mainApp.unregister()
     }

     try SMAppService.mainApp.register()
    } else {
     try SMAppService.mainApp.unregister()
    }
   } catch {
    launchStatusLog(
     """
     Failed to \(newValue ? "enable" : "disable") launch at login: \
     \(error.localizedDescription)
     """,
     with: .error
    )
   }
  }
 }

 final class LaunchStatusObserver: ObservableObject {
  var isEnabled: Bool {
   get { AppearanceApp.shouldLaunchAutomatically }
   set {
    AppearanceApp.shouldLaunchAutomatically = newValue
   }
  }
 }
}

// MARK: - Default Keys
struct TransitionKey: StandardUserDefaultsKey {
 static let defaultValue = false
}

extension StandardUserDefaultsKey where Self == TransitionKey {
 static var transition: Self { Self() }
}

struct ModeKey: RawValueConvertibleKey {
 static let defaultValue: Mode = .auto
}

extension UserDefaultsKey where Self == ModeKey {
 static var mode: Self { Self() }
}

extension Location: JSONCodable {}
extension Location: Infallible {
 public static let defaultValue = unknown
}

struct LocationKey: InfallibleCodableDefaultsKey {
 static let defaultValue: Location = .unknown
}

extension UserDefaultsKey where Self == LocationKey {
 static var location: Self { Self() }
}
