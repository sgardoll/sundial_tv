import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'platform_util.dart';

/// Paints the 60-step penumbra shadow and volumetric highlight on the
/// hour numeral — a direct port of the CSS text-shadow logic in page.tsx.
class SundialPainter extends CustomPainter {
  final String text;
  final double dx;
  final double dy;
  final double elevation;
  final double opacityMultiplier;
  final bool isDaytime;
  final Color textColor;
  final double solarAltitude;
  final bool hasSolarData;
  final TextStyle textStyle;

  SundialPainter({
    required this.text,
    required this.dx,
    required this.dy,
    required this.elevation,
    required this.opacityMultiplier,
    required this.isDaytime,
    required this.textColor,
    required this.solarAltitude,
    required this.hasSolarData,
    required this.textStyle,
  });

  Color _lerpRgb(List<int> warm, List<int> cool, double f) {
    final r = (warm[0] + (cool[0] - warm[0]) * f).round().clamp(0, 255);
    final g = (warm[1] + (cool[1] - warm[1]) * f).round().clamp(0, 255);
    final b = (warm[2] + (cool[2] - warm[2]) * f).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  // Render text into a Picture centred at (0,0) relative to its own bounds.
  // Returns the picture and its layout size.
  (ui.Picture, Size) _buildTextPicture(TextPainter tp) {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    tp.paint(c, Offset.zero);
    return (recorder.endRecording(), Size(tp.width, tp.height));
  }

  // Draw a blurred, tinted copy of [picture] onto [canvas] at [origin]+[offset].
  // Uses a single saveLayer with blur imageFilter + srcIn colorFilter so the
  // text shape is preserved with no ghost duplicate.
  void _drawShadowLayer(
    Canvas canvas,
    ui.Picture picture,
    Offset origin,
    Offset offset,
    Color color,
    double blurRadius,
  ) {
    final sigma = blurRadius.clamp(0.01, 200.0);
    final layerPaint = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma)
      ..colorFilter = ui.ColorFilter.mode(color, BlendMode.srcIn);

    canvas.save();
    canvas.translate(origin.dx + offset.dx, origin.dy + offset.dy);
    canvas.saveLayer(null, layerPaint);
    canvas.drawPicture(picture);
    canvas.restore(); // pop saveLayer (applies blur + tint)
    canvas.restore(); // pop translate
  }

  @override
  void paint(Canvas canvas, Size size) {
    final vmin = math.min(size.width, size.height);

    final altFactor = hasSolarData && isDaytime
        ? (solarAltitude / 45).clamp(0.0, 1.0)
        : 1.0;

    final aoColor = isDaytime
        ? _lerpRgb([120, 60, 10], [0, 5, 15], altFactor)
        : const Color.fromARGB(255, 180, 210, 255);
    final shadowColor = isDaytime
        ? _lerpRgb([180, 110, 40], [10, 20, 40], altFactor)
        : const Color.fromARGB(255, 200, 230, 255);

    final minShadowLength = 0.05 * vmin;
    final shadowLength =
        minShadowLength + math.pow(1 - elevation, 2.5) * 1.5 * vmin;

    // Layout
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final origin = Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2,
    );

    // Build the text picture once; reuse for every shadow layer.
    final (picture, _) = _buildTextPicture(tp);

    // ── 1. Ambient occlusion ─────────────────────────────────────────────────
    _drawShadowLayer(canvas, picture, origin, Offset.zero,
        aoColor.withValues(alpha: (0.9 * opacityMultiplier).clamp(0, 1)),
        0.015 * vmin);
    _drawShadowLayer(
        canvas, picture, origin, Offset(dx * 0.005 * vmin, dy * 0.005 * vmin),
        aoColor.withValues(alpha: (0.7 * opacityMultiplier).clamp(0, 1)),
        0.025 * vmin);

    // ── 2. Directional penumbra ────────────────────────────────────────────
    // 60 blurred saveLayer calls per frame is fine on Apple TV (Metal) but
    // catastrophic on Android TV chipsets (weak OpenGL / Mali / PowerVR).
    // Use 10 steps on Android TV — still looks good at living-room distance.
    final numSteps = isAndroidTV ? 10 : 60;
    for (int i = 1; i <= numSteps; i++) {
      final progress = i / numSteps;
      final easeProgress = 1 - math.pow(1 - progress, 2.5);
      final distance = easeProgress * shadowLength;
      final blur = distance * 0.15 + 0.005 * vmin;
      final baseOpacity = isDaytime ? 0.8 : 0.5;
      final stepOpacity =
          (baseOpacity * math.pow(1 - progress, 1.5) * opacityMultiplier)
              .clamp(0.0, 1.0);
      _drawShadowLayer(
          canvas,
          picture,
          origin,
          Offset(dx * distance, dy * distance),
          shadowColor.withValues(alpha: stepOpacity),
          blur);
    }

    // ── 3. Volumetric highlight (lit edge) ───────────────────────────────────
    final highlightColor = isDaytime
        ? Colors.white
        : const Color.fromARGB(255, 200, 230, 255);
    final hAlpha = (0.95 * opacityMultiplier).clamp(0.0, 1.0);
    _drawShadowLayer(
        canvas, picture, origin,
        Offset(-dx * 0.006 * vmin, -dy * 0.006 * vmin),
        highlightColor.withValues(alpha: hAlpha), 0.01 * vmin);
    _drawShadowLayer(
        canvas, picture, origin,
        Offset(-dx * 0.002 * vmin, -dy * 0.002 * vmin),
        highlightColor.withValues(alpha: hAlpha), 0.003 * vmin);

    // ── 4. Core shadow on unlit side ─────────────────────────────────────────
    final coreShadow = isDaytime
        ? Colors.black.withValues(alpha: (0.4 * opacityMultiplier).clamp(0, 1))
        : const Color.fromARGB(255, 0, 5, 15)
            .withValues(alpha: (0.8 * opacityMultiplier).clamp(0, 1));
    _drawShadowLayer(
        canvas, picture, origin,
        Offset(dx * 0.008 * vmin, dy * 0.008 * vmin),
        coreShadow, 0.015 * vmin);

    // ── 5. The actual numeral — painted once, on top, no filter ──────────────
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SundialPainter old) =>
      old.text != text ||
      old.dx != dx ||
      old.dy != dy ||
      old.elevation != elevation ||
      old.opacityMultiplier != opacityMultiplier ||
      old.isDaytime != isDaytime ||
      old.textColor != textColor ||
      old.solarAltitude != solarAltitude;
}
