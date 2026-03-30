import { describe, it, expect } from 'vitest';
import { calculateSolarPosition, SolarPosition } from './solar-position';

describe('calculateSolarPosition', () => {
  // Test 1 (SOLAR-01 + SOLAR-02): Solar noon at equator on March 20 equinox
  // At equator on equinox, altitude should be near 90 degrees (sun near zenith).
  // Azimuth is checked separately for a northern hemisphere location where 180 is well-defined.
  it('returns near-zenith altitude at equator on equinox at solar noon', () => {
    const date = new Date(Date.UTC(2024, 2, 20, 12, 0)); // March 20, 2024, 12:00 UTC
    const result = calculateSolarPosition(date, 0, 0);
    expect(result.altitude).toBeGreaterThan(88); // within 2 degrees of 90
  });

  // Test 1b (SOLAR-01): Solar noon at northern hemisphere location returns southward azimuth (~180)
  // Berlin (lat 52.5, lon 13.4) at solar noon June 21 — azimuth should be near 180 degrees (south)
  it('returns southward azimuth (~180) at northern hemisphere solar noon', () => {
    const date = new Date(Date.UTC(2024, 5, 21, 11, 7)); // June 21, 2024, ~11:07 UTC = solar noon in Berlin
    const result = calculateSolarPosition(date, 52.5, 13.4);
    expect(result.azimuth).toBeGreaterThan(175); // within 5 degrees of 180
    expect(result.azimuth).toBeLessThan(185);
    expect(result.altitude).toBeGreaterThan(55); // well above horizon at solar noon in June
  });

  // Test 2 (SOLAR-01): Morning at New York
  // Expected: eastern azimuth (90-180 degrees), positive altitude
  it('returns eastern azimuth and positive altitude during morning in New York', () => {
    const date = new Date(Date.UTC(2024, 5, 15, 14, 0)); // June 15, 2024, 14:00 UTC = ~9am EDT
    const result = calculateSolarPosition(date, 40.7, -74.0);
    expect(result.azimuth).toBeGreaterThan(90);
    expect(result.azimuth).toBeLessThan(180);
    expect(result.altitude).toBeGreaterThan(0);
  });

  // Test 3 (SOLAR-02): Nighttime at New York
  // Expected: negative altitude (sun below horizon)
  it('returns negative altitude during nighttime in New York', () => {
    const date = new Date(Date.UTC(2024, 5, 15, 7, 0)); // June 15, 2024, 07:00 UTC = ~3am EDT
    const result = calculateSolarPosition(date, 40.7, -74.0);
    expect(result.altitude).toBeLessThan(0);
  });

  // Test 4 (SOLAR-03): Equation of time correction
  // On Nov 3 at lon 0, the equation of time shifts solar noon by ~16 min earlier.
  // Altitude at 11:44 UTC should be HIGHER than at 12:00 UTC, proving correction is present.
  it('applies equation of time correction (Nov 3 at lon 0 — solar noon before 12:00 UTC)', () => {
    const at1144 = new Date(Date.UTC(2024, 10, 3, 11, 44)); // 11:44 UTC
    const at1200 = new Date(Date.UTC(2024, 10, 3, 12, 0));  // 12:00 UTC
    const result1144 = calculateSolarPosition(at1144, 0, 0);
    const result1200 = calculateSolarPosition(at1200, 0, 0);
    // Solar noon is around 11:44 on Nov 3 due to equation of time
    expect(result1144.altitude).toBeGreaterThan(result1200.altitude);
  });

  // Test 5 (SOLAR-01): Southern hemisphere solar noon
  // Sydney at solar noon on Dec 21 — sun should be in the north (azimuth near 0 or 360)
  it('returns north-facing azimuth for southern hemisphere at solar noon', () => {
    const date = new Date(Date.UTC(2024, 11, 21, 2, 0)); // Dec 21, 2024, 02:00 UTC = ~1pm AEDT
    const result = calculateSolarPosition(date, -33.87, 151.21);
    // Azimuth should be near 0 or 360 (north)
    expect(result.azimuth < 30 || result.azimuth > 330).toBe(true);
    expect(result.altitude).toBeGreaterThan(0);
  });

  // Test 6: Return type validation
  // Function returns object with numeric azimuth (0-360) and numeric altitude (-90 to 90)
  it('returns a SolarPosition object with valid azimuth and altitude ranges', () => {
    const date = new Date(Date.UTC(2024, 5, 21, 12, 0)); // June 21, 2024, noon UTC
    const result: SolarPosition = calculateSolarPosition(date, 51.5, -0.1); // London
    expect(typeof result.azimuth).toBe('number');
    expect(typeof result.altitude).toBe('number');
    expect(result.azimuth).toBeGreaterThanOrEqual(0);
    expect(result.azimuth).toBeLessThanOrEqual(360);
    expect(result.altitude).toBeGreaterThanOrEqual(-90);
    expect(result.altitude).toBeLessThanOrEqual(90);
  });
});
