import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

import 'solar_position.dart';
import 'sundial_painter.dart';

// ── Palette helpers ────────────────────────────────────────────────────────

class _Palette {
  final Color center, mid, edge, text;
  const _Palette({
    required this.center,
    required this.mid,
    required this.edge,
    required this.text,
  });
}

Color _blendColors(Color c1, Color c2, double f) {
  return Color.fromARGB(
    255,
    (c1.r * 255 + (c2.r * 255 - c1.r * 255) * f).round().clamp(0, 255),
    (c1.g * 255 + (c2.g * 255 - c1.g * 255) * f).round().clamp(0, 255),
    (c1.b * 255 + (c2.b * 255 - c1.b * 255) * f).round().clamp(0, 255),
  );
}

_Palette _blendPalette(_Palette p1, _Palette p2, double f) => _Palette(
      center: _blendColors(p1.center, p2.center, f),
      mid: _blendColors(p1.mid, p2.mid, f),
      edge: _blendColors(p1.edge, p2.edge, f),
      text: _blendColors(p1.text, p2.text, f),
    );

const _night = _Palette(
  center: Color(0xFF1a252f),
  mid: Color(0xFF111820),
  edge: Color(0xFF080c10),
  text: Color(0xFF2c3e50),
);
const _sunrise = _Palette(
  center: Color(0xFFffe4c4),
  mid: Color(0xFFdcb494),
  edge: Color(0xFF8a9ba8),
  text: Color(0xFFf0e6d8),
);
const _day = _Palette(
  center: Color(0xFFffffff),
  mid: Color(0xFFe0e5ec),
  edge: Color(0xFFb8c2cc),
  text: Color(0xFFe8ecef),
);
const _sunset = _Palette(
  center: Color(0xFFffcda8),
  mid: Color(0xFFc9967d),
  edge: Color(0xFF7a8b99),
  text: Color(0xFFebdcd3),
);

_Palette _paletteForT(double t) {
  if (t >= 3 && t < 6) return _blendPalette(_night, _sunrise, (t - 3) / 3);
  if (t >= 6 && t < 9) return _blendPalette(_sunrise, _day, (t - 6) / 3);
  if (t >= 9 && t < 15) return _day;
  if (t >= 15 && t < 18) return _blendPalette(_day, _sunset, (t - 15) / 3);
  if (t >= 18 && t < 21) return _blendPalette(_sunset, _night, (t - 18) / 3);
  return _night;
}

// ── Geolocation state ──────────────────────────────────────────────────────

enum _GeoStatus { idle, fetching, granted, denied, unavailable }

// ── Main widget ────────────────────────────────────────────────────────────

class SundialScreen extends StatefulWidget {
  const SundialScreen({super.key});

  @override
  State<SundialScreen> createState() => _SundialScreenState();
}

class _SundialScreenState extends State<SundialScreen>
    with SingleTickerProviderStateMixin {
  DateTime? _time;
  bool _isSimulating = false;
  double _simulatedTime = 12.0;

  double? _latitude;
  double? _longitude;
  _GeoStatus _geoStatus = _GeoStatus.idle;

  late AnimationController _minuteController;

  @override
  void initState() {
    super.initState();
    _startClock();
    _requestLocation();
    _minuteController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  // ── Clock ─────────────────────────────────────────────────────────────────

  void _startClock() {
    _time = DateTime.now();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _time = DateTime.now());
      return true;
    });
  }

  // ── Geolocation ───────────────────────────────────────────────────────────

  Future<void> _requestLocation() async {
    setState(() => _geoStatus = _GeoStatus.fetching);

    try {
      // Wrap the entire flow in a timeout — Android TV can silently hang
      // on permission dialogs that never appear on the TV launcher.
      await _doRequestLocation().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          if (mounted) setState(() => _geoStatus = _GeoStatus.unavailable);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _geoStatus = _GeoStatus.unavailable);
    }
  }

  Future<void> _doRequestLocation() async {
    // On Android TV, isLocationServiceEnabled can return false even when
    // network location works — skip this check and go straight to permission.
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      setState(() => _geoStatus = _GeoStatus.denied);
      return;
    }

    if (permission == LocationPermission.denied) {
      // requestPermission may show no UI on TV and return denied immediately.
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _geoStatus = _GeoStatus.denied);
      return;
    }

    // Use getLastKnownPosition first — instant, no GPS needed, works on TV
    // if any other app has recently fetched location.
    Position? pos = await Geolocator.getLastKnownPosition();

    pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
    if (!mounted) return;
    setState(() {
      _latitude = pos!.latitude;
      _longitude = pos.longitude;
      _geoStatus = _GeoStatus.granted;
    });
  }

  @override
  void dispose() {
    _minuteController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_time == null) return const SizedBox.shrink();

    final now = _time!;
    final actualH = now.hour;
    final actualM = now.minute;
    final actualS = now.second;
    final actualT = actualH + actualM / 60.0 + actualS / 3600.0;
    final t = _isSimulating ? _simulatedTime : actualT;

    int displayHour =
        _isSimulating ? (_simulatedTime.floor() % 12) : (actualH % 12);
    if (displayHour == 0) displayHour = 12;

    // ── Solar / celestial math ──────────────────────────────────────────────
    final hasSolarData = _latitude != null && _longitude != null;
    double dx, dy, elevation;
    bool isDaytime;
    double solarAzimuth = 0, solarAltitude = 0;

    if (hasSolarData) {
      final solarDate = _isSimulating
          ? DateTime(now.year, now.month, now.day, _simulatedTime.floor(),
              ((_simulatedTime % 1) * 60).round(), 0)
          : now;

      final pos =
          calculateSolarPosition(solarDate, _latitude!, _longitude!);
      solarAzimuth = pos.azimuth;
      solarAltitude = pos.altitude;
      isDaytime = pos.altitude > 0;

      if (isDaytime) {
        final shadowAzRad = ((pos.azimuth + 180) % 360) * math.pi / 180;
        dx = math.sin(shadowAzRad);
        dy = -math.cos(shadowAzRad);
        elevation = pos.altitude / 90;
      } else {
        final nightT = t < 6 ? t + 24 : t;
        final celAngle = ((nightT - 18) / 12) * math.pi;
        dx = math.cos(celAngle + math.pi);
        dy = math.sin(celAngle + math.pi);
        elevation = math.max(0, math.sin(celAngle));
      }
    } else {
      isDaytime = t >= 6 && t < 18;
      double celAngle;
      if (isDaytime) {
        celAngle = ((t - 6) / 12) * math.pi;
      } else {
        final nightT = t < 6 ? t + 24 : t;
        celAngle = ((nightT - 18) / 12) * math.pi;
      }
      dx = math.cos(celAngle + math.pi);
      dy = math.sin(celAngle + math.pi);
      elevation = math.max(0, math.sin(celAngle));
    }

    final opacityMultiplier = math.min(1.0, elevation * 8);

    // ── Palette ─────────────────────────────────────────────────────────────
    final palette = _paletteForT(t);

    // ── Gradient centre ──────────────────────────────────────────────────────
    double celestialX, celestialY;
    if (hasSolarData) {
      final azRad = solarAzimuth * math.pi / 180;
      celestialX = 50 + math.sin(azRad) * 40;
      celestialY = 50 - math.max(0, solarAltitude / 90) * 40;
    } else {
      final celAngle = isDaytime
          ? ((t - 6) / 12) * math.pi
          : (((t < 6 ? t + 24 : t) - 18) / 12) * math.pi;
      celestialX = 50 + math.cos(celAngle) * 40;
      celestialY = 50 + math.sin(celAngle) * 40 - elevation * 40;
    }

    // ── Minute dot ────────────────────────────────────────────────────────────
    final minuteFraction = _isSimulating
        ? (_simulatedTime % 1)
        : (actualM + actualS / 60.0) / 60.0;
    final minuteAngle = minuteFraction * 2 * math.pi;

    // ── Sim time display ─────────────────────────────────────────────────────
    final simH = _simulatedTime.floor();
    final simM = ((_simulatedTime % 1) * 60).floor();
    final simDisplay =
        '${simH.toString().padLeft(2, '0')}:${simM.toString().padLeft(2, '0')}';

    // ── Text style ────────────────────────────────────────────────────────────
    final fontSize = MediaQuery.of(context).size.shortestSide * 0.45;
    final playfair = GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: palette.text,
      height: 1.0,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 1000),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(
              (celestialX / 50) - 1,
              (celestialY / 50) - 1,
            ),
            radius: 1.4,
            colors: [palette.center, palette.mid, palette.edge],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Noise texture ──────────────────────────────────────────────
            Positioned.fill(
              child: Opacity(
                opacity: 0.04,
                child: CustomPaint(painter: _NoisePainter()),
              ),
            ),

            // ── Numeral + shadows ──────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: SundialPainter(
                  text: displayHour.toString(),
                  dx: dx,
                  dy: dy,
                  elevation: elevation,
                  opacityMultiplier: opacityMultiplier,
                  isDaytime: isDaytime,
                  textColor: palette.text,
                  solarAltitude: solarAltitude,
                  hasSolarData: hasSolarData,
                  textStyle: playfair,
                ),
              ),
            ),

            // ── Minute orbiting dot ────────────────────────────────────────
            Positioned.fill(
              child: _MinuteDot(
                angle: minuteAngle,
                color: palette.text,
                orbitRadius:
                    MediaQuery.of(context).size.shortestSide * 0.34,
              ),
            ),

            // ── Simulation slider ──────────────────────────────────────────
            if (_isSimulating)
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.15,
                left: MediaQuery.of(context).size.width * 0.25,
                right: MediaQuery.of(context).size.width * 0.25,
                child: Column(
                  children: [
                    Text(
                      'Simulated: $simDisplay',
                      style: GoogleFonts.jetBrainsMono(
                          color: palette.text, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _simulatedTime,
                      min: 0,
                      max: 23.99,
                      onChanged: (v) =>
                          setState(() => _simulatedTime = v),
                      activeColor: palette.text,
                      inactiveColor:
                          palette.text.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),

            // ── Toggle button ──────────────────────────────────────────────
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.04,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _isSimulating = !_isSimulating),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 1000),
                    style: GoogleFonts.jetBrainsMono(
                      color: palette.text,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                    child: Text(
                      _isSimulating
                          ? 'BACK TO REAL TIME'
                          : now.toString().substring(11, 16),
                    ),
                  ),
                ),
              ),
            ),

            // ── Location status (top-right, auto — no manual entry) ────────
            if (_geoStatus != _GeoStatus.granted && _geoStatus != _GeoStatus.idle)
              Positioned(
                top: 24,
                right: 32,
                child: GestureDetector(
                  onTap: (_geoStatus == _GeoStatus.denied ||
                          _geoStatus == _GeoStatus.unavailable)
                      ? _requestLocation
                      : null,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 1000),
                    style: GoogleFonts.jetBrainsMono(
                      color: palette.text.withValues(alpha: 0.5),
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                    child: Text(
                      switch (_geoStatus) {
                        _GeoStatus.fetching   => 'LOCATING…',
                        _GeoStatus.denied     => 'LOCATION DENIED — TAP TO RETRY',
                        _GeoStatus.unavailable => 'LOCATION UNAVAILABLE — TAP TO RETRY',
                        _ => '',
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Minute orbiting dot ────────────────────────────────────────────────────

class _MinuteDot extends StatelessWidget {
  final double angle;
  final Color color;
  final double orbitRadius;

  const _MinuteDot(
      {required this.angle,
      required this.color,
      required this.orbitRadius});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MinuteDotPainter(
          angle: angle, color: color, orbitRadius: orbitRadius),
    );
  }
}

class _MinuteDotPainter extends CustomPainter {
  final double angle;
  final Color color;
  final double orbitRadius;

  _MinuteDotPainter(
      {required this.angle,
      required this.color,
      required this.orbitRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final adjustedCy = cy - size.shortestSide * 0.09 * 0.45;
    final dotX = cx + math.sin(angle) * orbitRadius;
    final dotY = adjustedCy - math.cos(angle) * orbitRadius;
    final dotRadius = size.shortestSide * 0.006;
    canvas.drawCircle(Offset(dotX, dotY), dotRadius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MinuteDotPainter old) =>
      old.angle != angle || old.color != color;
}

// ── Noise texture ──────────────────────────────────────────────────────────

class _NoisePainter extends CustomPainter {
  final _rand = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const grain = 2.0;
    for (double y = 0; y < size.height; y += grain) {
      for (double x = 0; x < size.width; x += grain) {
        final v = _rand.nextDouble();
        paint.color = Color.fromARGB((v * 255).round(), 128, 128, 128);
        canvas.drawRect(Rect.fromLTWH(x, y, grain, grain), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_NoisePainter _) => false;
}
