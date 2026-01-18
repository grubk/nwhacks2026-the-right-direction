import 'package:flutter/material.dart';

import '../../../../core/services/camera_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Overlay showing detected objects for users with partial vision
class ObjectOverlay extends StatelessWidget {
  final List<DetectedObject> objects;

  const ObjectOverlay({
    super.key,
    required this.objects,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ObjectOverlayPainter(objects),
      child: Container(),
    );
  }
}

class _ObjectOverlayPainter extends CustomPainter {
  final List<DetectedObject> objects;

  _ObjectOverlayPainter(this.objects);

  @override
  void paint(Canvas canvas, Size size) {
    for (final object in objects) {
      _drawObject(canvas, size, object);
    }
  }

  void _drawObject(Canvas canvas, Size size, DetectedObject object) {
    final box = object.boundingBox;
    
    // Convert normalized coordinates to screen coordinates
    final rect = Rect.fromLTRB(
      box.left * size.width,
      box.top * size.height,
      box.right * size.width,
      box.bottom * size.height,
    );

    // Color based on proximity
    final color = _getProximityColor(object.proximityLevel);
    
    // Draw bounding box
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    // Draw fill
    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      fillPaint,
    );

    // Draw label
    _drawLabel(canvas, rect, object, color);
  }

  Color _getProximityColor(ProximityLevel level) {
    switch (level) {
      case ProximityLevel.veryClose:
        return Colors.red;
      case ProximityLevel.close:
        return Colors.orange;
      case ProximityLevel.medium:
        return Colors.yellow;
      case ProximityLevel.far:
        return Colors.lightGreen;
      case ProximityLevel.veryFar:
        return AppTheme.blindModeAccent;
    }
  }

  void _drawLabel(Canvas canvas, Rect rect, DetectedObject object, Color color) {
    final labelText = '${object.label} ${object.distance.toStringAsFixed(1)}m';
    
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      backgroundColor: color.withOpacity(0.8),
    );

    final textSpan = TextSpan(text: labelText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Position label above the box
    final labelOffset = Offset(
      rect.left + (rect.width - textPainter.width) / 2,
      rect.top - textPainter.height - 4,
    );
    
    // Draw background
    final bgRect = Rect.fromLTWH(
      labelOffset.dx - 4,
      labelOffset.dy - 2,
      textPainter.width + 8,
      textPainter.height + 4,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      Paint()..color = color.withOpacity(0.8),
    );
    
    // Draw text
    textPainter.paint(canvas, labelOffset);
  }

  @override
  bool shouldRepaint(covariant _ObjectOverlayPainter oldDelegate) {
    return objects != oldDelegate.objects;
  }
}
