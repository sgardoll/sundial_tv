/**
 * Solar position calculation using the NOAA/Jean Meeus algorithm.
 * Returns azimuth and altitude in meteorological convention:
 *   azimuth: 0 = North, 90 = East, 180 = South, 270 = West (clockwise)
 *   altitude: 0 = horizon, 90 = zenith, negative = below horizon
 */

const toRad = (deg: number) => deg * Math.PI / 180;
const toDeg = (rad: number) => rad * 180 / Math.PI;

export interface SolarPosition {
  azimuth: number;   // degrees, 0 = North, 90 = East, 180 = South, 270 = West
  altitude: number;  // degrees, 0 = horizon, 90 = zenith, negative = below horizon
}

/**
 * Calculate the solar position (azimuth and altitude) for a given UTC date,
 * latitude, and longitude using the NOAA Solar Position algorithm.
 *
 * @param date - UTC date/time for the calculation
 * @param latitude - Observer latitude in degrees (positive = north, negative = south)
 * @param longitude - Observer longitude in degrees (positive = east, negative = west)
 * @returns SolarPosition with azimuth (0–360) and altitude (-90 to 90) in degrees
 */
export function calculateSolarPosition(
  date: Date,
  latitude: number,
  longitude: number
): SolarPosition {
  // Julian Day Number from UTC milliseconds
  const JD = date.getTime() / 86400000 + 2440587.5;

  // Julian Century
  const T = (JD - 2451545.0) / 36525;

  // Geometric mean longitude of the sun (degrees)
  const L0 = (280.46646 + T * (36000.76983 + T * 0.0003032)) % 360;

  // Mean anomaly (degrees)
  const M = 357.52911 + T * (35999.05029 - 0.0001537 * T);

  // Equation of center (degrees)
  const C = Math.sin(toRad(M)) * (1.914602 - T * (0.004817 + 0.000014 * T))
          + Math.sin(toRad(2 * M)) * (0.019993 - 0.000101 * T)
          + Math.sin(toRad(3 * M)) * 0.000289;

  // Sun's true longitude and apparent longitude
  const sunTrueLon = L0 + C;
  const omega = 125.04 - 1934.136 * T;
  const sunApparentLon = sunTrueLon - 0.00569 - 0.00478 * Math.sin(toRad(omega));

  // Obliquity of ecliptic with correction
  const obliquityCorrection = 23.439291 - T * (0.013004167 + T * (0.0000001639 + T * 0.0000005036))
    + 0.00256 * Math.cos(toRad(omega));

  // Solar declination (degrees)
  const declination = toDeg(Math.asin(
    Math.sin(toRad(obliquityCorrection)) * Math.sin(toRad(sunApparentLon))
  ));

  // Eccentricity of Earth's orbit
  const ecc = 0.016708634 - T * (0.000042037 + 0.0000001267 * T);

  // Equation of time (minutes) — SOLAR-03 correction
  const y = Math.tan(toRad(obliquityCorrection / 2)) ** 2;
  const eqTime = 4 * toDeg(
    y * Math.sin(2 * toRad(L0))
    - 2 * ecc * Math.sin(toRad(M))
    + 4 * ecc * y * Math.sin(toRad(M)) * Math.cos(2 * toRad(L0))
    - 0.5 * y * y * Math.sin(4 * toRad(L0))
    - 1.25 * ecc * ecc * Math.sin(toRad(2 * M))
  );

  // Hour angle from UTC time, longitude, and equation of time
  const utcMinutes = date.getUTCHours() * 60 + date.getUTCMinutes() + date.getUTCSeconds() / 60;
  const trueSolarTime = utcMinutes + eqTime + 4 * longitude; // 4 min per degree of longitude
  let hourAngle = trueSolarTime / 4 - 180; // degrees
  // Normalize to [-180, 180] — trueSolarTime can exceed 1440 for eastern
  // longitudes when UTC midnight falls within local daytime hours
  hourAngle = ((hourAngle + 180) % 360 + 360) % 360 - 180;

  // Altitude (elevation angle)
  const latRad = toRad(latitude);
  const decRad = toRad(declination);
  const haRad = toRad(hourAngle);
  const altitude = toDeg(Math.asin(
    Math.sin(latRad) * Math.sin(decRad) +
    Math.cos(latRad) * Math.cos(decRad) * Math.cos(haRad)
  ));

  // Azimuth (meteorological convention: 0=North, clockwise)
  // Guard against division by zero at polar noon or extreme latitudes
  const cosDenom = Math.cos(latRad) * Math.cos(toRad(altitude));
  let azimuth: number;
  if (Math.abs(cosDenom) < 1e-10) {
    // At poles or zenith — azimuth is undefined; default to south (noon) or north (midnight)
    azimuth = hourAngle > 0 ? 180 : 0;
  } else {
    const cosAz = (Math.sin(decRad) - Math.sin(latRad) * Math.sin(toRad(altitude))) / cosDenom;
    // Clamp to [-1, 1] to guard against floating-point overflow in acos
    azimuth = toDeg(Math.acos(Math.max(-1, Math.min(1, cosAz))));
    if (hourAngle > 0) azimuth = 360 - azimuth;
  }

  return { azimuth, altitude };
}
