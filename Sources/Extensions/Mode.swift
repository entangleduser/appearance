@_exported import struct Appearance.Mode
import ScreenCaptureKit

extension Mode {
 /// A module that sets the system appearance immediately.
 struct Set: AsyncFunction {
  let mode: Mode
  let transition: Bool

  init(
   to mode: Mode,
   transition: Bool
  ) {
   self.mode = mode
   self.transition = transition
  }

  func callAsFunction() async throws {
   try await Mode.set(to: mode, transition: transition)
  }
 }

 /// A module that toggles the system appearance at regular intervals.
 struct Auto: Module {
  @Context
  var location: Location = .unknown
  @Context
  var predictions: Solar.PhasePredictions!

  var authorizationLevel: Location.AuthorizationLevel = .authorizedAlways

  @Context
  var rate: TimeInterval?
  @Context
  var interval: TimeInterval?
  @Context
  var intensity: Double?
  let transition: Bool

  var perform: ((Solar.Projector<Self.ID>) async throws -> ())?

  init(
   location: Context<Location>? = nil,
   predictions: Context<Solar.PhasePredictions?>? = nil,
   authorizationLevel: Location.AuthorizationLevel = .authorizedAlways,
   rate: Context<TimeInterval?>? = nil,
   interval: Context<TimeInterval?>? = nil,
   intensity: Context<Double?>? = nil,
   transition: Bool,
   perform: ((Solar.Projector<Self.ID>) async throws -> ())? = nil
  ) {
   if let location {
    _location = location
   }

   if let predictions {
    _predictions = predictions
   }

   self.authorizationLevel = authorizationLevel

   if let rate {
    _rate = rate
   }
   if let interval {
    _interval = interval
   }
   if let intensity {
    _intensity = intensity
   }

   self.transition = transition
   if let perform {
    self.perform = perform
   }
  }

  init(
   location: Context<Location>? = nil,
   predictions: Context<Solar.PhasePredictions?>? = nil,
   authorizationLevel: Location.AuthorizationLevel = .authorizedAlways,
   rate: Context<TimeInterval?>? = nil,
   interval: Context<TimeInterval?>? = nil,
   intensity: Context<Double?>? = nil,
   transition: Bool,
   perform: @escaping () async throws -> ()
  ) {
   self.init(
    location: location,
    predictions: predictions,
    authorizationLevel: authorizationLevel,
    rate: rate,
    interval: interval,
    intensity: intensity, transition: transition,
    perform: { _ in try await perform() }
   )
  }

   var void: some Module {
   if location.isInvalid {
    Locator(
     $location,
     authorizationLevel: authorizationLevel,
     unknownInterval: .seconds(2.5)
    )
   }

   Solar.Projector<Self.ID>(
    id: id,
    location: $location,
    predictions: $predictions,
    rate: $rate,
    interval: $interval,
    intensity: $intensity,
    perform: {
     @MainActor solar in
     let mode: Mode = solar.isDaytime ? .light : .dark
     let current: Mode = .systemTheme
     try await perform?(solar)
     guard mode != current else {
      #if DEBUG
      print("current mode (\(mode)) already set")
      #endif
      return
     }
     #if DEBUG
     print("switching to \(mode) mode")
     #endif
     try await Mode.set(
      to: mode, transition: transition
     )
    }
   )
  }
 }
}

extension Mode {
 @MainActor(unsafe)
 static func set(to mode: Self, transition: Bool) async throws {
  if transition, await canCaptureScreen {
   setSystem(to: mode)
  } else {
   let source = script(with: mode)
   guard
    let appScript = NSAppleScript(source: source) else {
    fatalError("invalid source for script '\(source)'")
   }

   var dictionary: NSDictionary?
   try withUnsafeMutablePointer(to: &dictionary) {
    let ptr = AutoreleasingUnsafeMutablePointer<NSDictionary?>($0)
    appScript.executeAndReturnError(ptr)
    if let dictionary = $0.pointee {
     throw AppearanceModeError(
      message:
      dictionary["NSAppleScriptErrorMessage"] as! String
     )
    }
    $0.pointee = nil
   }
  }
 }

 @MainActor
 static func setSystem(to mode: Self) {
  guard
   let transition =
   NSGlobalPreferenceTransition.transition() as? NSGlobalPreferenceTransition
  else { fatalError("unable to initialize global transition") }
  transition.postChangeNotification(0) {
   SLSSetAppearanceThemeLegacy(mode == .dark)
  }
 }

 static var systemTheme: Self {
  SLSGetAppearanceThemeLegacy() ? .dark : .light
 }

 static func checkScreenCaptureStatus() {
  Task { _ = await canCaptureScreen }
 }

 /// Requests screen permission to gradually transition appearance.
 static var canCaptureScreen: Bool {
  get async {
   do {
    // If the app doesn't have screen recording permission, this call generates
    // an exception.
    try await SCShareableContent.excludingDesktopWindows(
     false,
     onScreenWindowsOnly: true
    )
    return true
   } catch {
    return false
   }
  }
 }
}
