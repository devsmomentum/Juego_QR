import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/theme/app_theme.dart';

class MinigameCountdownOverlay extends StatefulWidget {
  final String instruction;
  final Widget child;

  const MinigameCountdownOverlay({
    super.key,
    required this.instruction,
    required this.child,
  });

  @override
  State<MinigameCountdownOverlay> createState() =>
      _MinigameCountdownOverlayState();
}

class _MinigameCountdownOverlayState extends State<MinigameCountdownOverlay> {
  @override
  Widget build(BuildContext context) {
    // Retornamos directamente el hijo para omitir el efecto de 3,2,1 y el sonido
    return widget.child;
  }
}
