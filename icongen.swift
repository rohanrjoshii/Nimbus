import AppKit

// Renders Nimbus's app icon (1024×1024) to Sources/AppIconSource.png.
// A dark squircle, an aurora "nimbus" glow, a glossy Dynamic-Island pill,
// and a luminous waveform. Run: swift icongen.swift

let S = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: S, pixelsHigh: S,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
let nsctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = nsctx
let cg = nsctx.cgContext
let space = CGColorSpaceCreateDeviceRGB()
let W = CGFloat(S), H = CGFloat(S)

func grad(_ colors: [NSColor], _ locs: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors.map { $0.cgColor } as CFArray, locations: locs)!
}
func radial(_ center: CGPoint, _ radius: CGFloat, _ color: NSColor, _ alpha: CGFloat) {
    cg.drawRadialGradient(grad([color.withAlphaComponent(alpha), color.withAlphaComponent(0)], [0, 1]),
                          startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

// Apple icon grid: 824×824 rounded rect centered in 1024, corner ≈ 0.225·side.
let margin: CGFloat = 100
let rect = CGRect(x: margin, y: margin, width: W - 2*margin, height: H - 2*margin)
let corner = rect.width * 0.225
let squircle = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

cg.saveGState()
cg.addPath(squircle); cg.clip()

// Background: deep indigo → near-black
cg.drawLinearGradient(
    grad([NSColor(srgbRed: 0.17, green: 0.10, blue: 0.36, alpha: 1),
          NSColor(srgbRed: 0.03, green: 0.03, blue: 0.07, alpha: 1)], [0, 1]),
    start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

// Aurora "nimbus" glow
radial(CGPoint(x: W*0.34, y: H*0.66), 440, NSColor(srgbRed: 0.13, green: 0.83, blue: 0.93, alpha: 1), 0.55) // cyan
radial(CGPoint(x: W*0.70, y: H*0.40), 450, NSColor(srgbRed: 0.62, green: 0.34, blue: 0.97, alpha: 1), 0.55) // purple
radial(CGPoint(x: W*0.52, y: H*0.52), 300, NSColor(srgbRed: 0.95, green: 0.35, blue: 0.75, alpha: 1), 0.28) // pink

// Dynamic-Island pill
let pw: CGFloat = 560, ph: CGFloat = 170
let prect = CGRect(x: (W - pw)/2, y: H*0.5 - ph/2, width: pw, height: ph)
let ppath = CGPath(roundedRect: prect, cornerWidth: ph/2, cornerHeight: ph/2, transform: nil)

cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -16), blur: 44, color: NSColor.black.withAlphaComponent(0.6).cgColor)
cg.addPath(ppath)
cg.setFillColor(NSColor(srgbRed: 0.04, green: 0.04, blue: 0.06, alpha: 1).cgColor)
cg.fillPath()
cg.restoreGState()

cg.saveGState()
cg.addPath(ppath); cg.clip()
cg.drawLinearGradient(
    grad([NSColor(srgbRed: 0.13, green: 0.13, blue: 0.17, alpha: 1),
          NSColor(srgbRed: 0.02, green: 0.02, blue: 0.03, alpha: 1)], [0, 1]),
    start: CGPoint(x: 0, y: prect.maxY), end: CGPoint(x: 0, y: prect.minY), options: [])
cg.restoreGState()

cg.saveGState()
cg.addPath(ppath)
cg.setLineWidth(2.5)
cg.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
cg.strokePath()
cg.restoreGState()

// Luminous waveform inside the pill
let barW: CGFloat = 30, gap: CGFloat = 22
let heights: [CGFloat] = [72, 122, 94, 142, 86]
let totalW = CGFloat(heights.count)*barW + CGFloat(heights.count - 1)*gap
var x = (W - totalW)/2
let cy = prect.midY
let wfGrad = grad([NSColor(srgbRed: 0.20, green: 0.86, blue: 0.93, alpha: 1),
                   NSColor(srgbRed: 0.64, green: 0.37, blue: 0.98, alpha: 1)], [0, 1])
for h in heights {
    let br = CGRect(x: x, y: cy - h/2, width: barW, height: h)
    let bp = CGPath(roundedRect: br, cornerWidth: barW/2, cornerHeight: barW/2, transform: nil)
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: 18, color: NSColor(srgbRed: 0.4, green: 0.7, blue: 1, alpha: 0.7).cgColor)
    cg.addPath(bp); cg.clip()
    cg.drawLinearGradient(wfGrad, start: CGPoint(x: br.minX, y: 0), end: CGPoint(x: br.maxX, y: 0), options: [])
    cg.restoreGState()
    x += barW + gap
}

cg.restoreGState() // end squircle clip

// Inner top sheen + hairline border for glass depth
cg.saveGState()
cg.addPath(squircle); cg.clip()
cg.drawLinearGradient(
    grad([NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)], [0, 1]),
    start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: H*0.7), options: [])
cg.restoreGState()

cg.addPath(squircle)
cg.setLineWidth(3)
cg.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
cg.strokePath()

NSGraphicsContext.restoreGraphicsState()

let out = "Sources/AppIconSource.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("✅ wrote \(out)")
