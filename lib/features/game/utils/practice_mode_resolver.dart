import 'package:flutter/material.dart';

class PracticeModeResolver extends InheritedWidget {
  final bool isPractice;

  const PracticeModeResolver({
    super.key,
    required this.isPractice,
    required super.child,
  });

  static bool of(BuildContext context) {
    final PracticeModeResolver? result =
        context.dependOnInheritedWidgetOfExactType<PracticeModeResolver>();
    return result?.isPractice ?? false;
  }

  @override
  bool updateShouldNotify(PracticeModeResolver oldWidget) {
    return isPractice != oldWidget.isPractice;
  }
}
