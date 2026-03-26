// Solar position calculation using the NOAA/Jean Meeus algorithm.
// Direct port of lib/solar-position.ts
// Returns azimuth and altitude in meteorological convention:
//   azimuth: 0 = North, 90 = East, 180 = South, 270 = West (clockwise)
//   altitude: 0 = horizon, 90 = zenith, negative = below horizon

import 'dart:math' as math;

class SolarPosition {
  final double azimuth; // degrees, 0=North, 90=East, 180=South, 270=West
  final double altitude; // degrees, 0=horizon, 90=zenith, negative=below horizon

  const SolarPosition({required this.azimuth, required this.altitude});
}

double _toRad(double deg) => deg * math.pi / 180;
double _toDeg(double rad) => rad * 180 / math.pi;

/// Calculate the solar position (azimuth and altitude) for a given UTC date,
/// latitude, and longitude using the NOAA Solar Position algorithm.
SolarPosition calculateSolarPosition(
  DateTime date,
  double latitude,
  double longitude,
) {
  // Julian Day Number from UTC milliseconds
  final jd = date.millisecondsSinceEpoch / 86400000.0 + 2440587.5;

  // Julian Century
  final t = (jd - 2451545.0) / 36525;

  // Geometric mean longitude of the sun (degrees)
  final l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360;

  // Mean anomaly (degrees)
  final m = 357.52911 + t * (35999.05029 - 0.0001537 * t);

  // Equation of center (degrees)
  final c = math.sin(_toRad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
      math.sin(_toRad(2 * m)) * (0.019993 - 0.000101 * t) +
      math.sin(_toRad(3 * m)) * 0.000289;

  // Sun's true longitude and apparent longitude
  final sunTrueLon = l0 + c;
  final omega = 125.04 - 1934.136 * t;
  final sunApparentLon =
      sunTrueLon - 0.00569 - 0.00478 * math.sin(_toRad(omega));

  // Obliquity of ecliptic with correction
  final obliquityCorrection =
      23.439291 -
      t * (0.013004167 + t * (0.0000001639 + t * 0.0000005036)) +
      0.00256 * math.cos(_toRad(omega));

  // Solar declination (degrees)
  final declination = _toDeg(math.asin(
    math.sin(_toRad(obliquityCorrection)) *
        math.sin(_toRad(sunApparentLon)),
  ));

  // Eccentricity of Earth's orbit
  final ecc = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);

  // Equation of time (minutes)
  final y = math.pow(math.tan(_toRad(obliquityCorrection / 2)), 2).toDouble();
  final eqTime = 4 *
      _toDeg(y * math.sin(2 * _toRad(l0)) -
          2 * ecc * math.sin(_toRad(m)) +
          4 * ecc * y * math.sin(_toRad(m)) * math.cos(2 * _toRad(l0)) -
          0.5 * y * y * math.sin(4 * _toRad(l0)) -
          1.25 * ecc * ecc * math.sin(_toRad(2 * m)));

  // Hour angle from UTC time, longitude, and equation of time
  final utcMinutes =
      date.toUtc().hour * 60 +
      date.toUtc().minute +
      date.toUtc().second / 60.0;
  final trueSolarTime = utcMinutes + eqTime + 4 * longitude;
  double hourAngle = trueSolarTime / 4 - 180;
  // Normalize to [-180, 180]
  hourAngle = ((hourAngle + 180) % 360 + 360) % 360 - 180;

  // Altitude (elevation angle)
  final latRad = _toRad(latitude);
  final decRad = _toRad(declination);
  final haRad = _toRad(hourAngle);
  final altitude = _toDeg(math.asin(
    math.sin(latRad) * math.sin(decRad) +
        math.cos(latRad) * math.cos(decRad) * math.cos(haRad),
  ));

  // Azimuth (meteorological convention: 0=North, clockwise)
  final cosDenom = math.cos(latRad) * math.cos(_toRad(altitude));
  double azimuth;
  if (cosDenom.abs() < 1e-10) {
    azimuth = hourAngle > 0 ? 180.0 : 0.0;
  } else {
    final cosAz =
        (math.sin(decRad) - math.sin(latRad) * math.sin(_toRad(altitude))) /
        cosDenom;
    azimuth = _toDeg(math.acos(cosAz.clamp(-1.0, 1.0)));
    if (hourAngle > 0) azimuth = 360 - azimuth;
  }

  return SolarPosition(azimuth: azimuth, altitude: altitude);
}
