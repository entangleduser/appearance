import SwiftUI

final class Panel: NSPanel {
 static var storage: [InterfaceID: Panel] = .empty
 var id: InterfaceID = .empty
 convenience init<A: View>(
  id: InterfaceID,
  title: String? = nil,
  rootView: A
 ) {
  self.init(
   contentRect: .zero,
   styleMask: [.titled, .closable, .hudWindow],
   backing: .buffered,
   defer: false
  )
  self.id = id
  animationBehavior = .documentWindow
  titlebarAppearsTransparent = true
  self.title = title ?? id.secondary.unsafelyUnwrapped.capitalized
  isReleasedWhenClosed = false
  contentView = NSHostingView(rootView: rootView)
  Self.storage[id] = self
 }

 @inline(__always)
 static func open(_ panel: Panel) {
  precondition(isKnownUniquelyReferenced(&storage[panel.id, default: panel]))
  storage[panel.id, default: panel].open()
 }

 @inline(__always)
 static func close(_ panel: Panel) {
  precondition(isKnownUniquelyReferenced(&storage[panel.id, default: panel]))
  storage[panel.id, default: panel].close()
 }

 @inline(__always)
 func open() {
  NSApp.runModal(for: self)
 }

 override func close() {
  NSApp.stopModal()
  super.close()
  Self.storage[id] = nil
 }
}
