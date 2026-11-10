import AppKit

// Menu-bar only app: no storyboard, no @main. LSUIElement in Info.plist keeps
// it out of the Dock; the accessory policy does the same for bare-binary runs.
let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
