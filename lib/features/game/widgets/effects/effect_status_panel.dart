import 'package:flutter/material.dart';
import 'effect_timer.dart';

class EffectStatusPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final DateTime? expiresAt;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;
  final Color? textColor;

  const EffectStatusPanel({
    super.key,
    required this.title,
    required this.icon,
    this.expiresAt,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = textColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor ?? titleColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 10),
            EffectTimer(
              expiresAt: expiresAt!,
              backgroundColor: backgroundColor ?? Colors.black.withOpacity(0.85),
              borderColor: borderColor ?? Colors.white.withOpacity(0.2),
              iconColor: iconColor ?? Colors.white70,
              textColor: textColor ?? Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}
