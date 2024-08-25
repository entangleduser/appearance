import Foundation
@_exported import Solar
import Time

extension Solar {
 /// A module that makes projections about the current solar cycle at a
 /// consistent rate or set interval if needed.
 /// - Note: This is intended be exported to a library in the future.
 @dynamicMemberLookup
 struct Projector<ID: Hashable>: Acrylic.Module {
  subscript<A>(
   dynamicMember keyPath: KeyPath<PhasePredictions, A>
  ) -> A { predictions![keyPath: keyPath] }

  var id: ID?

  /// The number of times to update during a cycle.
  @Context
  var location: Location = .unknown
  @Context
  var rate: TimeInterval?
  /// The seconds to wait before perform an update, consistent with the next
  /// cycle
  /// This value is ignored if rate is already set.
  @Context
  var interval: TimeInterval?
  @Context
  var intensity: Double?
  @Context
  var predictions: PhasePredictions?

  var errorHandler: ((SolarProjectorError) -> ())?
  let perform: (Self) async throws -> ()

  private let clock: DateClock = .date
  private let elipson: Double = .leastNonzeroMagnitude

  init(
   id: ID?,
   location: Context<Location>,
   predictions: Context<PhasePredictions?>? = nil,
   rate: Context<TimeInterval?>? = nil,
   interval: Context<TimeInterval?>? = nil,
   intensity: Context<Double?>? = nil,
   perform: @escaping (Self) async throws -> ()
  ) {
   self.id = id
   _location = location

   if let predictions {
    _predictions = predictions
   }

   if let rate {
    _rate = rate
   }
   if let interval {
    _interval = interval
   }
   if let intensity {
    _intensity = intensity
   }

   self.perform = perform
  }

  init(
   location: Context<Location>,
   predictions: Context<PhasePredictions?>? = nil,
   rate: Context<TimeInterval?>? = nil,
   interval: Context<TimeInterval?>? = nil,
   intensity: Context<Double?>? = nil,
   onError errorHandler: ((SolarProjectorError) -> ())? = nil,
   perform: @escaping (Self) async throws -> ()
  ) where ID == EmptyID {
   _location = location

   if let predictions {
    _predictions = predictions
   }

   if let rate {
    _rate = rate
   }
   if let interval {
    _interval = interval
   }
   if let intensity {
    _intensity = intensity
   }

   if let errorHandler {
    self.errorHandler = errorHandler
   }

   self.perform = perform
  }

  var void: some Acrylic.Module {
   // start the repeat cycle at normal or custom intervals
   Repeat.Async {
    let now = Date.now
    self.predictions =
     Solar.PhasePredictions(for: now, x: location.x, y: location.y)

    if let predictions {
     let (sunrise, sunset) = (predictions.sunrise, predictions.sunset)

     let update = {
      if let rate {
       now.update(from: sunset, to: sunrise, by: rate)
      } else if let interval {
       now.update(from: sunset, to: sunrise, interval: interval)
      } else {
       now.update(from: sunset, to: sunrise)
      }
     }

     if self.intensity != nil {
      let intensity = now.intensity(from: sunrise, to: sunset, with: elipson)
      if self.intensity != intensity { await $intensity.updateState() }
     }

     let date = update()

     #if DEBUG
     print("it is", predictions.isDaytime ? "daytime" : "nightime")
     print("\(sunrise.formatted()) < sunrise/sunset > \(sunset.formatted())")
     print(
      """
      updating in \
      \(Duration.seconds(date.timeIntervalSince(now)).timerView)
      """
     )
     #endif

     /// handle error or continue with normal update
     if let errorHandler {
      do {
       try checkUpdateWithError(date, since: now)
       try await perform(self)
      } catch let error as SolarProjectorError {
       errorHandler(error)
      } catch {
       throw error
      }
     } else {
      checkUpdateWithFatalError(date, since: now)
      try await perform(self)
     }

     try await clock.sleep(until: date)

     return true
    } else if let errorHandler {
     errorHandler(.unableToPredict(location))
    } else {
     #if DEBUG
     let error = SolarProjectorError.unableToPredict(location)
     print(error.description)
     throw error
     #else
     fatalError(
      SolarProjectorError.unableToPredict(location).description
     )
     #endif
    }
    // set intensity to the undetermined state
    await $intensity.updateState(.none)
    return false
   }
  }
 }
}

// MARK: - Error Handling
enum SolarProjectorError: LocalizedError, CustomStringConvertible {
 init?(_ date: Date, since reference: Date) {
  let interval = date.timeIntervalSince(reference)
  if interval < .leastNonzeroMagnitude {
   // invalidate if longer than 24 hours which is up from midnight or noon
   // at the least
   self = .invalidDate(date, true)
  } else if interval > 86400 {
   // invalidate if longer than 24 hours which is up from midnight or noon
   // at the least
   self = .invalidDate(date, false)
  } else {
   return nil
  }
 }

 case invalidDate(Date, Bool), unableToPredict(Location)
 var localizedDescription: String? { description }
 var description: String {
  switch self {
  case .invalidDate(let date, let soon):
   """
   Update at \(date.formatted()) occurs too \(soon ? "soon" : "late"), maybe \
   the hours cycle of your system's clock is not being accounted for.
   """
  case .unableToPredict(let location):
   "Unable to prediction current phase with location: \(location)"
  }
 }
}

extension Solar.Projector {
 /// Checks the update intervale or terminates the program
 @_transparent
 func checkUpdateWithFatalError(_ date: Date, since reference: Date) {
  if let error = SolarProjectorError(date, since: reference) {
   fatalError(error.description)
  }
 }

 /// Checks the update intervale or throws an error
 @_transparent
 func checkUpdateWithError(_ date: Date, since reference: Date) throws {
  if let error = SolarProjectorError(date, since: reference) {
   throw error
  }
 }
}

// MARK: Extensions
private extension Date {
 func intensity(
  from sunrise: Date, to sunset: Date, with elipson: Double
 ) -> Double {
  let constant =
   self < sunrise
    ? timeIntervalSince(sunset) /
    (sunrise.timeIntervalSince(self) - sunset.timeIntervalSince(self))
    : timeIntervalSince(sunrise) /
    (sunset.timeIntervalSince(self) - sunrise.timeIntervalSince(self))
  return max(0, min(1, Darwin.log(constant * (2 + elipson))))
 }

 func update(from sunset: Date, to sunrise: Date, by rate: Double) -> Self {
  let isDaylight = self > sunrise
  // the projected date is sunrise during twilight hours
  // or sunset to show that there is still time left in the day
  let (projected, other) = isDaylight ? (sunset, sunrise) : (sunrise, sunset)
  // the seconds until the projected date
  let seconds = projected.timeIntervalSince(self)

  let a = projected.timeIntervalSinceReferenceDate
  let b = other.timeIntervalSinceReferenceDate

  // adjust when waiting for sunrise because the projected date will be less
  // and subracting a greater interval will cause a negative value
  let range = self < sunrise ? (b - a) : (a - b)
  // divide by rate which is convenient for creating an increasing number
  // of samples for continuous updates
  let interval: TimeInterval = range / rate

  let remainder = seconds.remainder(dividingBy: interval)

  return advanced(by: interval + remainder)
 }

 func update(from sunset: Date, to sunrise: Date, interval: Double) -> Self {
  // the seconds until the projected date
  let seconds = (self > sunrise ? sunset : sunrise).timeIntervalSince(self)

  //   adjust when waiting for sunrise because the projected date will be less
  //   and subracting a greater interval will cause a negative value
  // let range = self < sunrise ? -seconds : seconds

  // find the offset that will be added to the interval
  let remainder = seconds.remainder(dividingBy: interval)

  return advanced(by: interval + remainder)
 }

 func update(from sunset: Date, to sunrise: Date) -> Self {
  advanced(by: (self > sunrise ? sunset : sunrise).timeIntervalSince(self))
 }
}
