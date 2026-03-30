// Solar position calculation using the NOAA/Jean Meeus algorithm.
// Port of solar_position.dart → Swift
//
// Returns azimuth and altitude in meteorological convention:
//   azimuth:  0 = North, 90 = East, 180 = South, 270 = West (clockwise)
//   altitude: 0 = horizon, 90 = zenith, negative = below horizon

import Foundation

struct SolarPosition {
    let azimuth: Double   // degrees
    let altitude: Double  // degrees
}

func calculateSolarPosition(date: Date, latitude: Double, longitude: Double) -> SolarPosition {
    let toRad = { (deg: Double) -> Double in deg * .pi / 180 }
    let toDeg = { (rad: Double) -> Double in rad * 180 / .pi }

    // Julian Day Number from UTC
    let jd = date.timeIntervalSince1970 / 86400.0 + 2440587.5

    // Julian Century
    let t = (jd - 2451545.0) / 36525.0

    // Geometric mean longitude of the sun (degrees)
    let l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)

    // Mean anomaly (degrees)
    let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)

    // Equation of center (degrees)
    let c = sin(toRad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t))
          + sin(toRad(2 * m)) * (0.019993 - 0.000101 * t)
          + sin(toRad(3 * m)) * 0.000289

    // Sun's true longitude and apparent longitude
    let sunTrueLon = l0 + c
    let omega = 125.04 - 1934.136 * t
    let sunApparentLon = sunTrueLon - 0.00569 - 0.00478 * sin(toRad(omega))

    // Obliquity of ecliptic with correction
    let obliquityCorrection = 23.439291
        - t * (0.013004167 + t * (0.0000001639 + t * 0.0000005036))
        + 0.00256 * cos(toRad(omega))

    // Solar declination (degrees)
    let declination = toDeg(asin(
        sin(toRad(obliquityCorrection)) * sin(toRad(sunApparentLon))
    ))

    // Eccentricity of Earth's orbit
    let ecc = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

    // Equation of time (minutes)
    let y = pow(tan(toRad(obliquityCorrection / 2)), 2)
    let eqTime = 4 * toDeg(
        y * sin(2 * toRad(l0))
      - 2 * ecc * sin(toRad(m))
      + 4 * ecc * y * sin(toRad(m)) * cos(2 * toRad(l0))
      - 0.5 * y * y * sin(4 * toRad(l0))
      - 1.25 * ecc * ecc * sin(toRad(2 * m))
    )

    // Hour angle from UTC time, longitude, and equation of time
    let cal = Calendar(identifier: .gregorian)
    let comps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
    let utcMinutes = Double(comps.hour ?? 0) * 60
                   + Double(comps.minute ?? 0)
                   + Double(comps.second ?? 0) / 60.0
    let trueSolarTime = utcMinutes + eqTime + 4 * longitude
    var hourAngle = trueSolarTime / 4 - 180
    hourAngle = ((hourAngle + 180).truncatingRemainder(dividingBy: 360) + 360)
                    .truncatingRemainder(dividingBy: 360) - 180

    // Altitude (elevation angle)
    let latRad = toRad(latitude)
    let decRad = toRad(declination)
    let haRad  = toRad(hourAngle)
    let altitude = toDeg(asin(
        sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
    ))

    // Azimuth (meteorological convention: 0=North, clockwise)
    let cosDenom = cos(latRad) * cos(toRad(altitude))
    var azimuth: Double
    if abs(cosDenom) < 1e-10 {
        azimuth = hourAngle > 0 ? 180 : 0
    } else {
        let cosAz = (sin(decRad) - sin(latRad) * sin(toRad(altitude))) / cosDenom
        azimuth = toDeg(acos(min(max(cosAz, -1), 1)))
        if hourAngle > 0 { azimuth = 360 - azimuth }
    }

    return SolarPosition(azimuth: azimuth, altitude: altitude)
}
