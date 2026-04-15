import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/version_check_service.dart';
import '../../features/game/services/whats_new_service.dart';
import '../utils/global_keys.dart';

class WhatsNewDialog extends StatelessWidget {
  final VersionStatus status;

  const WhatsNewDialog({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accentGold.withOpacity(0.8),
                AppTheme.primaryPurple.withOpacity(0.5),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGold.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0F).withOpacity(0.9),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon Header
                  const Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      color: AppTheme.accentGold,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  const Text(
                    "SISTEMA ACTUALIZADO",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accentGold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Version Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        "Versión ${status.localVersion}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Changelog Text
                  const Text(
                    "Detección de nuevas anomalías corregidas y optimizaciones de red completadas:",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Updates List
                  if (status.changelog.isNotEmpty)
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: status.changelog.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppTheme.accentGold.withOpacity(0.7),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    status.changelog[index],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "Mejoras de rendimiento y corrección de errores generales.",
                        style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Button
                  ElevatedButton(
                    onPressed: () async {
                      await WhatsNewService.markAsSeen(status.localVersion);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 10,
                      shadowColor: AppTheme.accentGold.withOpacity(0.5),
                    ),
                    child: const Text(
                      "RECIBIDO Y ENTENDIDO",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper method to show the dialog
void showWhatsNewDialog(BuildContext context, VersionStatus status) {
  final navContext = rootNavigatorKey.currentContext;
  if (navContext == null) return;
  
  showDialog(
    context: navContext,
    barrierDismissible: false,
    builder: (context) => WhatsNewDialog(status: status),
  );
}
