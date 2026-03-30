import SwiftUI
import CoreLocation
import CoreText

// MARK: - Palette

struct Palette {
    let center: Color
    let mid: Color
    let edge: Color
    let text: Color
    let centerRGB: (Double, Double, Double)
    let midRGB: (Double, Double, Double)
    let edgeRGB: (Double, Double, Double)
    let textRGB: (Double, Double, Double)
}

private func rgb(_ r: Int, _ g: Int, _ b: Int) -> (Double, Double, Double) {
    (Double(r) / 255, Double(g) / 255, Double(b) / 255)
}
private func clr(_ c: (Double, Double, Double)) -> Color { Color(red: c.0, green: c.1, blue: c.2) }
private func blend(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ f: Double) -> (Double, Double, Double) {
    (a.0 + (b.0 - a.0) * f, a.1 + (b.1 - a.1) * f, a.2 + (b.2 - a.2) * f)
}
private func pal(_ c: (Double, Double, Double), _ m: (Double, Double, Double),
                 _ e: (Double, Double, Double), _ t: (Double, Double, Double)) -> Palette {
    Palette(center: clr(c), mid: clr(m), edge: clr(e), text: clr(t),
            centerRGB: c, midRGB: m, edgeRGB: e, textRGB: t)
}
private func blendPal(_ a: Palette, _ b: Palette, _ f: Double) -> Palette {
    pal(blend(a.centerRGB, b.centerRGB, f), blend(a.midRGB, b.midRGB, f),
        blend(a.edgeRGB, b.edgeRGB, f), blend(a.textRGB, b.textRGB, f))
}

private let nightP   = pal(rgb(26,37,47),   rgb(17,24,32),   rgb(8,12,16),     rgb(44,62,80))
private let sunriseP = pal(rgb(255,228,196), rgb(220,180,148), rgb(138,155,168), rgb(240,230,216))
private let dayP     = pal(rgb(255,255,255), rgb(224,229,236), rgb(184,194,204), rgb(232,236,239))
private let sunsetP  = pal(rgb(255,205,168), rgb(201,150,125), rgb(122,139,153), rgb(235,220,211))

private func paletteForTime(_ t: Double) -> Palette {
    if t >= 3 && t < 6  { return blendPal(nightP, sunriseP, (t - 3) / 3) }
    if t >= 6 && t < 9  { return blendPal(sunriseP, dayP, (t - 6) / 3) }
    if t >= 9 && t < 15 { return dayP }
    if t >= 15 && t < 18 { return blendPal(dayP, sunsetP, (t - 15) / 3) }
    if t >= 18 && t < 21 { return blendPal(sunsetP, nightP, (t - 18) / 3) }
    return nightP
}

// MARK: - Font

/// Playfair Display Black — registered via Info.plist UIAppFonts.
/// The variable font file registers as family "Playfair Display".
private func playfairBlack(size: CGFloat) -> Font {
    // Try the bundled Playfair Display first
    if let _ = UIFont(name: "PlayfairDisplay-Black", size: size) {
        return Font.custom("PlayfairDisplay-Black", size: size)
    }
    // Variable font variant
    if let _ = UIFont(name: "PlayfairDisplayRoman-Black", size: size) {
        return Font.custom("PlayfairDisplayRoman-Black", size: size)
    }
    // Fallback: system serif black
    return Font.system(size: size, weight: .black, design: .serif)
}

private func playfairBlackUI(size: CGFloat) -> UIFont {
    if let f = UIFont(name: "PlayfairDisplay-Black", size: size) { return f }
    if let f = UIFont(name: "PlayfairDisplayRoman-Black", size: size) { return f }
    // Variable font: use font descriptor to request Black weight from Playfair Display family
    let desc = UIFontDescriptor(fontAttributes: [
        .family: "Playfair Display",
        .traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.black]
    ])
    return UIFont(descriptor: desc, size: size)
}

// MARK: - Computed scene state

struct SceneState {
    let displayHour: Int
    let t: Double
    let dx: Double
    let dy: Double
    let elevation: Double
    let opacityMultiplier: Double
    let isDaytime: Bool
    let solarAltitude: Double
    let hasSolarData: Bool
    let palette: Palette
    let celestialX: Double
    let celestialY: Double
    let minuteAngle: Double
    let simDisplay: String
    let realDisplay: String
}

private func computeScene(now: Date, isSimulating: Bool, simulatedTime: Double,
                           lat: Double?, lon: Double?) -> SceneState {
    let cal = Calendar.current
    let hour = cal.component(.hour, from: now)
    let minute = cal.component(.minute, from: now)
    let second = cal.component(.second, from: now)
    let actualT = Double(hour) + Double(minute) / 60.0 + Double(second) / 3600.0
    let t = isSimulating ? simulatedTime : actualT

    var dh = isSimulating ? (Int(simulatedTime) % 12) : (hour % 12)
    if dh == 0 { dh = 12 }

    let hasSolar = lat != nil && lon != nil
    var dx: Double, dy: Double, elevation: Double, isDaytime: Bool
    var solarAz: Double = 0, solarAlt: Double = 0

    if hasSolar {
        let solarDate: Date
        if isSimulating {
            solarDate = cal.date(bySettingHour: Int(simulatedTime),
                                 minute: Int(simulatedTime.truncatingRemainder(dividingBy: 1) * 60),
                                 second: 0, of: now) ?? now
        } else { solarDate = now }

        let pos = calculateSolarPosition(date: solarDate, latitude: lat!, longitude: lon!)
        solarAz = pos.azimuth; solarAlt = pos.altitude
        isDaytime = pos.altitude > 0

        if isDaytime {
            let shadowAzRad = ((pos.azimuth + 180).truncatingRemainder(dividingBy: 360)) * .pi / 180
            dx = sin(shadowAzRad); dy = -cos(shadowAzRad)
            elevation = pos.altitude / 90
        } else {
            let nightT = t < 6 ? t + 24 : t
            let celAngle = ((nightT - 18) / 12) * .pi
            dx = cos(celAngle + .pi); dy = sin(celAngle + .pi)
            elevation = max(0, sin(celAngle))
        }
    } else {
        isDaytime = t >= 6 && t < 18
        let celAngle: Double
        if isDaytime { celAngle = ((t - 6) / 12) * .pi }
        else { let nightT = t < 6 ? t + 24 : t; celAngle = ((nightT - 18) / 12) * .pi }
        dx = cos(celAngle + .pi); dy = sin(celAngle + .pi)
        elevation = max(0, sin(celAngle))
    }

    let opMul = min(1.0, elevation * 8)
    let palette = paletteForTime(t)

    let cx: Double, cy: Double
    if hasSolar {
        let azRad = solarAz * .pi / 180
        cx = 0.5 + sin(azRad) * 0.4
        cy = 0.5 - max(0, solarAlt / 90) * 0.4
    } else {
        let celAngle = isDaytime
            ? ((t - 6) / 12) * .pi
            : (((t < 6 ? t + 24 : t) - 18) / 12) * .pi
        cx = 0.5 + cos(celAngle) * 0.4
        cy = 0.5 + sin(celAngle) * 0.4 - elevation * 0.4
    }

    let minuteFrac = isSimulating
        ? simulatedTime.truncatingRemainder(dividingBy: 1)
        : (Double(minute) + Double(second) / 60.0) / 60.0

    let simH = Int(simulatedTime)
    let simM = Int(simulatedTime.truncatingRemainder(dividingBy: 1) * 60)

    return SceneState(
        displayHour: dh, t: t, dx: dx, dy: dy, elevation: elevation,
        opacityMultiplier: opMul, isDaytime: isDaytime,
        solarAltitude: solarAlt, hasSolarData: hasSolar,
        palette: palette, celestialX: cx, celestialY: cy,
        minuteAngle: minuteFrac * 2 * .pi,
        simDisplay: String(format: "%02d:%02d", simH, simM),
        realDisplay: String(format: "%02d:%02d", hour, minute)
    )
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var status: String = ""
    private let mgr = CLLocationManager()

    override init() { super.init(); mgr.delegate = self; mgr.desiredAccuracy = kCLLocationAccuracyKilometer }
    func request() { status = "LOCATING…"; mgr.requestWhenInUseAuthorization(); mgr.requestLocation() }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        if let l = locs.first { latitude = l.coordinate.latitude; longitude = l.coordinate.longitude; status = "" }
    }
    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) { status = "LOCATION UNAVAILABLE" }
    func locationManager(_ m: CLLocationManager, didChangeAuthorization s: CLAuthorizationStatus) {
        switch s {
        case .authorizedWhenInUse, .authorizedAlways: mgr.requestLocation()
        case .denied, .restricted: status = "LOCATION DENIED"
        default: break
        }
    }
}

// MARK: - Sundial View

struct SundialView: View {
    @State private var now = Date()
    @State private var isSimulating = false
    @State private var simulatedTime: Double = 12.0
    @StateObject private var locMgr = LocationManager()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let s = computeScene(now: now, isSimulating: isSimulating, simulatedTime: simulatedTime,
                             lat: locMgr.latitude, lon: locMgr.longitude)

        GeometryReader { geo in
            let vmin = min(geo.size.width, geo.size.height)

            ZStack {
                // Background gradient
                RadialGradient(
                    colors: [s.palette.center, s.palette.mid, s.palette.edge],
                    center: UnitPoint(x: s.celestialX, y: s.celestialY),
                    startRadius: 0, endRadius: vmin * 1.4
                )

                // Sundial numeral with shadows — rendered via Core Graphics
                SundialCanvas(
                    text: "\(s.displayHour)",
                    dx: s.dx, dy: s.dy,
                    elevation: s.elevation,
                    opacityMultiplier: s.opacityMultiplier,
                    isDaytime: s.isDaytime,
                    textColorRGB: s.palette.textRGB,
                    solarAltitude: s.solarAltitude,
                    hasSolarData: s.hasSolarData,
                    vmin: vmin
                )

                // Minute orbiting dot
                Canvas { ctx, size in
                    let cx = size.width / 2
                    let cy = size.height / 2 - vmin * 0.09 * 0.45
                    let orbitR = vmin * 0.34
                    let dotX = cx + sin(s.minuteAngle) * orbitR
                    let dotY = cy - cos(s.minuteAngle) * orbitR
                    let r = vmin * 0.006
                    ctx.fill(Path(ellipseIn: CGRect(x: dotX - r, y: dotY - r, width: r*2, height: r*2)),
                             with: .color(s.palette.text))
                }

                // Simulation controls
                if isSimulating {
                    VStack {
                        Spacer()
                        Text("Simulated: \(s.simDisplay)")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(s.palette.text)
                        HStack(spacing: 40) {
                            Button { simulatedTime = max(0, simulatedTime - 0.5) } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 28))
                                    .foregroundColor(s.palette.text)
                            }
                            .buttonStyle(.plain)

                            Text(s.simDisplay)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(s.palette.text)
                                .frame(width: 140)

                            Button { simulatedTime = min(23.99, simulatedTime + 0.5) } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 28))
                                    .foregroundColor(s.palette.text)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer().frame(height: geo.size.height * 0.15)
                    }
                }

                // Bottom: time / toggle
                VStack {
                    Spacer()
                    Button { isSimulating.toggle() } label: {
                        Text(isSimulating ? "BACK TO REAL TIME" : s.realDisplay)
                            .font(.system(size: 12, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(s.palette.text)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, geo.size.height * 0.04)
                }

                // Location status
                if !locMgr.status.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            Text(locMgr.status)
                                .font(.system(size: 11, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(s.palette.text.opacity(0.5))
                                .padding(.top, 24).padding(.trailing, 32)
                        }
                        Spacer()
                    }
                }
            }
        }
        .onReceive(timer) { _ in now = Date() }
        .onAppear { locMgr.request() }
    }
}

// MARK: - Core Graphics Sundial Renderer (UIViewRepresentable)

/// Uses Core Graphics directly for proper shadow rendering.
/// SwiftUI Canvas `.shadow()` + `.colorMultiply(.clear)` doesn't work —
/// CG gives us real NSShadow / CGContext.setShadow support.
struct SundialCanvas: UIViewRepresentable {
    let text: String
    let dx: Double, dy: Double, elevation: Double
    let opacityMultiplier: Double
    let isDaytime: Bool
    let textColorRGB: (Double, Double, Double)
    let solarAltitude: Double
    let hasSolarData: Bool
    let vmin: CGFloat

    func makeUIView(context: Context) -> SundialCGView {
        let v = SundialCGView()
        v.backgroundColor = .clear
        v.isOpaque = false
        return v
    }

    func updateUIView(_ view: SundialCGView, context: Context) {
        view.text = text
        view.dx = dx; view.dy = dy; view.elevation = elevation
        view.opacityMultiplier = opacityMultiplier
        view.isDaytime = isDaytime
        view.textColorRGB = textColorRGB
        view.solarAltitude = solarAltitude
        view.hasSolarData = hasSolarData
        view.vmin = vmin
        view.setNeedsDisplay()
    }
}

class SundialCGView: UIView {
    var text: String = "12"
    var dx: Double = 0; var dy: Double = 1; var elevation: Double = 0.5
    var opacityMultiplier: Double = 1
    var isDaytime: Bool = true
    var textColorRGB: (Double, Double, Double) = (0.9, 0.9, 0.9)
    var solarAltitude: Double = 45
    var hasSolarData: Bool = false
    var vmin: CGFloat = 1080

    private func lerpRGB(_ warm: (Int, Int, Int), _ cool: (Int, Int, Int), _ f: Double) -> (CGFloat, CGFloat, CGFloat) {
        let r = CGFloat(Double(warm.0) + Double(cool.0 - warm.0) * f) / 255
        let g = CGFloat(Double(warm.1) + Double(cool.1 - warm.1) * f) / 255
        let b = CGFloat(Double(warm.2) + Double(cool.2 - warm.2) * f) / 255
        return (max(0, min(1, r)), max(0, min(1, g)), max(0, min(1, b)))
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let size = bounds.size
        let fontSize = vmin * 0.45

        let altFactor = hasSolarData && isDaytime ? min(max(solarAltitude / 45, 0), 1) : 1.0
        let aoRGB = isDaytime ? lerpRGB((120,60,10), (0,5,15), altFactor) : (CGFloat(180.0/255), CGFloat(210.0/255), CGFloat(255.0/255))
        let shadowRGB = isDaytime ? lerpRGB((180,110,40), (10,20,40), altFactor) : (CGFloat(200.0/255), CGFloat(230.0/255), CGFloat(255.0/255))

        let minShadowLen = 0.05 * vmin
        let shadowLen = minShadowLen + pow(1 - elevation, 2.5) * 1.5 * Double(vmin)

        // Build attributed string with Playfair Display
        let font = playfairBlackUI(size: fontSize)
        let textColor = UIColor(red: textColorRGB.0, green: textColorRGB.1, blue: textColorRGB.2, alpha: 1)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()
        let origin = CGPoint(x: (size.width - textSize.width) / 2,
                             y: (size.height - textSize.height) / 2)

        // Helper: draw a blurred, colored copy of the text at an offset.
        // We draw text in the shadow color, with CG shadow set to create the blur.
        // The trick: use a TINY shadow offset (0.01) so CG doesn't skip it,
        // and position the text so shadow lands where we want.
        func drawBlurredText(offsetX: CGFloat, offsetY: CGFloat, color: UIColor, blur: CGFloat) {
            ctx.saveGState()
            // Position the text far offscreen, but set the shadow offset to bring it back
            // This way only the shadow (blurred version) is visible on the canvas
            let offscreenShift: CGFloat = 5000
            ctx.setShadow(offset: CGSize(width: offsetX + offscreenShift, height: offsetY),
                          blur: blur,
                          color: color.cgColor)
            let drawAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let str = NSAttributedString(string: text, attributes: drawAttrs)
            str.draw(at: CGPoint(x: origin.x - offscreenShift, y: origin.y))
            ctx.restoreGState()
        }

        // 1. Ambient occlusion
        let aoColor = UIColor(red: aoRGB.0, green: aoRGB.1, blue: aoRGB.2, alpha: 1)
        drawBlurredText(offsetX: 0, offsetY: 0,
                        color: aoColor.withAlphaComponent(CGFloat(0.9 * opacityMultiplier)),
                        blur: 0.015 * vmin)
        drawBlurredText(offsetX: CGFloat(dx * 0.005 * Double(vmin)),
                        offsetY: CGFloat(dy * 0.005 * Double(vmin)),
                        color: aoColor.withAlphaComponent(CGFloat(0.7 * opacityMultiplier)),
                        blur: 0.025 * vmin)

        // 2. Directional penumbra (20 steps)
        let shadowColor = UIColor(red: shadowRGB.0, green: shadowRGB.1, blue: shadowRGB.2, alpha: 1)
        let numSteps = 20
        for i in 1...numSteps {
            let progress = Double(i) / Double(numSteps)
            let easeProgress = 1 - pow(1 - progress, 2.5)
            let distance = easeProgress * shadowLen
            let blur = distance * 0.15 + 0.005 * Double(vmin)
            let baseOp = isDaytime ? 0.8 : 0.5
            let stepOp = min(max(baseOp * pow(1 - progress, 1.5) * opacityMultiplier, 0), 1)

            drawBlurredText(
                offsetX: CGFloat(dx * distance),
                offsetY: CGFloat(dy * distance),
                color: shadowColor.withAlphaComponent(CGFloat(stepOp)),
                blur: CGFloat(blur)
            )
        }

        // 3. Volumetric highlight (lit edge)
        let hlColor = isDaytime ? UIColor.white : UIColor(red: 200/255, green: 230/255, blue: 255/255, alpha: 1)
        let hA = CGFloat(min(max(0.95 * opacityMultiplier, 0), 1))
        drawBlurredText(offsetX: CGFloat(-dx * 0.006 * Double(vmin)),
                        offsetY: CGFloat(-dy * 0.006 * Double(vmin)),
                        color: hlColor.withAlphaComponent(hA),
                        blur: 0.01 * vmin)
        drawBlurredText(offsetX: CGFloat(-dx * 0.002 * Double(vmin)),
                        offsetY: CGFloat(-dy * 0.002 * Double(vmin)),
                        color: hlColor.withAlphaComponent(hA),
                        blur: 0.003 * vmin)

        // 4. Core shadow on unlit side
        let cA = CGFloat(isDaytime ? 0.4 * opacityMultiplier : 0.8 * opacityMultiplier)
        let coreColor = isDaytime ? UIColor.black.withAlphaComponent(cA)
            : UIColor(red: 0, green: 5/255, blue: 15/255, alpha: cA)
        drawBlurredText(offsetX: CGFloat(dx * 0.008 * Double(vmin)),
                        offsetY: CGFloat(dy * 0.008 * Double(vmin)),
                        color: coreColor,
                        blur: 0.015 * vmin)

        // 5. The actual numeral — on top, no shadow
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 0)
        attrStr.draw(at: origin)
        ctx.restoreGState()
    }
}
