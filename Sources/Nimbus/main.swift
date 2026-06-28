import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Run as an accessory app (hides Dock icon and keeps it as a menu bar / floating overlay utility)
app.setActivationPolicy(.accessory)

app.run()
