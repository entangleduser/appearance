@_exported import Location

struct Locator: Module {
 @usableFromInline
 var priority: TaskPriority?
 private let authorizationLevel: Location.AuthorizationLevel?
 private var unknownInterval: Duration?
 private var deniedInterval: Duration?
 private var interval: Duration?
 private var results: ((Location) -> Modules)?

 @Context
 private var location: Location = .unknown

 init(
  _ location: Context<Location>,
  authorizationLevel: Location.AuthorizationLevel? = nil,
  priority: TaskPriority? = nil,
  alwaysAsk: Bool = false,
  interval: Duration? = nil,
  unknownInterval: Duration? = nil,
  deniedInterval: Duration? = nil,
  @Modular results: @escaping (Location) -> Modules
 ) {
  if let authorizationLevel, alwaysAsk {
   Location.checkAuthorization(authorizationLevel)
  }
  _location = location
  self.priority = priority
  self.authorizationLevel = authorizationLevel
  self.interval = interval
  self.unknownInterval = unknownInterval
  self.deniedInterval = deniedInterval
  self.results = results
 }

 init(
  _ location: Context<Location>,
  authorizationLevel: Location.AuthorizationLevel? = nil,
  priority: TaskPriority? = nil,
  alwaysAsk: Bool = false,
  interval: Duration? = nil,
  unknownInterval: Duration? = nil,
  deniedInterval: Duration? = nil
 ) {
  if let authorizationLevel, alwaysAsk {
   Location.checkAuthorization(authorizationLevel)
  }
  _location = location
  self.priority = priority
  self.authorizationLevel = authorizationLevel
  self.interval = interval
  self.unknownInterval = unknownInterval
  self.deniedInterval = deniedInterval
 }

 init(
  _ location: Context<Location>,
  authorizationLevel: Location.AuthorizationLevel? = nil,
  priority: TaskPriority? = nil,
  alwaysAsk: Bool = false,
  interval: Duration? = nil,
  unknownInterval: Duration? = nil,
  deniedInterval: Duration? = nil,
  @Modular results: @escaping () -> Modules
 ) {
  self.init(
   location,
   authorizationLevel: authorizationLevel,
   priority: priority,
   alwaysAsk: alwaysAsk,
   interval: interval,
   unknownInterval: unknownInterval,
   deniedInterval: deniedInterval,
   results: { _ in results() }
  )
 }

 var void: some Module {
  if let authorizationLevel, location.isInvalid {
   Repeat.Async(priority: priority) {
    let request = try await Location.requestAsync(authorizationLevel)

    defer { self.location = request }

    switch request {
    case .unknown:
     // retry or fallthrough when unknown
     if let unknownInterval {
      try await sleep(for: unknownInterval)
     } else {
      return false
     }
    case .denied:
     // retry when denied but still required
     if let deniedInterval {
      try await sleep(for: deniedInterval)
     } else {
      // assign denied without repeating
      return false
     }
    case let request where request.isValid:
     // repeat module with the valid location and set the value
     return false
    default: break
    }
    return true
   }
  } else {
   results?(location)

   if let authorizationLevel, let interval {
    Perform.Async(priority: priority) {
     try await sleep(for: interval, clock: .continuous)
     let request = try await Location.requestAsync(authorizationLevel)
     try await $location(request)
    }
   }
  }
 }
}
