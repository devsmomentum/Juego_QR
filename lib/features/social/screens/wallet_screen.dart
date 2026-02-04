import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import 'profile_screen.dart';
import '../../game/screens/scenarios_screen.dart';
import '../../../shared/widgets/glitch_text.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;
    final cloverBalance = player?.clovers ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // Center the title
                children: [
                   const GlitchText(
                    text: "MapHunter",
                    fontSize: 22,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Balance Card with Custom Clover Icon
                    CustomPaint(
                      painter: PixelBorderPainter(color: const Color(0xFF10B981)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF10B981).withOpacity(0.3),
                              const Color(0xFF10B981).withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'TRÉBOLES',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Clover Icon
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Text(
                                '🍀',
                                style: TextStyle(fontSize: 40),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Balance Amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  cloverBalance.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Massive Conversion info
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                              ),
                              child: const Text(
                                '1 🍀 = 1\$',
                                style: TextStyle(
                                  color: AppTheme.accentGold,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.add_circle_outline,
                            label: 'RECARGAR',
                            color: AppTheme.accentGold,
                            onTap: () => _showRechargeDialog(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.remove_circle_outline,
                            label: 'RETIRAR',
                            color: AppTheme.secondaryPink,
                            onTap: () => _showWithdrawDialog(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Transaction History Section (Placeholder)
                    CustomPaint(
                      painter: PixelBorderPainter(color: Colors.white.withOpacity(0.3)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg.withOpacity(0.9),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  color: AppTheme.accentGold,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'HISTORIAL DE TRANSACCIONES',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Center(
                              child: Text(
                                'No hay transacciones recientes',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: PixelBorderPainter(color: color),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRechargeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.add_circle, color: AppTheme.accentGold),
            const SizedBox(width: 12),
            const Text(
              'Recargar Tréboles',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'La funcionalidad de recarga estará disponible próximamente. Podrás comprar tréboles para usar en el juego.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Entendido',
              style: TextStyle(color: AppTheme.accentGold),
            ),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.secondaryPink.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.remove_circle, color: AppTheme.secondaryPink),
            const SizedBox(width: 12),
            const Text(
              'Retirar Tréboles',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'La funcionalidad de retiro estará disponible próximamente. Podrás convertir tus tréboles en recompensas reales.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Entendido',
              style: TextStyle(color: AppTheme.secondaryPink),
            ),
          ),
        ],
      ),
    );
  }


  void _showComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.construction, color: AppTheme.accentGold),
            const SizedBox(width: 12),
            const Text(
              'Próximamente',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'La sección "$featureName" estará disponible muy pronto. ¡Mantente atento a las actualizaciones!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Entendido',
              style: TextStyle(color: AppTheme.accentGold),
            ),
          ),
        ],
      ),
    );
  }
}

class PixelBorderPainter extends CustomPainter {
  final Color color;

  PixelBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const double cornerSize = 15;
    const double pixelSize = 4;

    final path = Path()
      ..moveTo(cornerSize, 0)
      ..lineTo(size.width - cornerSize, 0)
      ..moveTo(size.width, cornerSize)
      ..lineTo(size.width, size.height - cornerSize)
      ..moveTo(size.width - cornerSize, size.height)
      ..lineTo(cornerSize, size.height)
      ..moveTo(0, size.height - cornerSize)
      ..lineTo(0, cornerSize);

    canvas.drawPath(path, paint);

    void drawCorner(double x, double y, bool right, bool bottom) {
      final cp = Paint()..color = color..style = PaintingStyle.fill;
      double dx = right ? -1 : 1;
      double dy = bottom ? -1 : 1;

      canvas.drawRect(Rect.fromLTWH(x, y, pixelSize * dx, cornerSize * dy), cp);
      canvas.drawRect(Rect.fromLTWH(x, y, cornerSize * dx, pixelSize * dy), cp);
      
      canvas.drawRect(Rect.fromLTWH(x + (cornerSize + 5) * dx, y, pixelSize * dx, pixelSize * dy), cp);
      canvas.drawRect(Rect.fromLTWH(x, y + (cornerSize + 5) * dy, pixelSize * dx, pixelSize * dy), cp);
    }

    drawCorner(0, 0, false, false);
    drawCorner(size.width, 0, true, false);
    drawCorner(0, size.height, false, true);
    drawCorner(size.width, size.height, true, true);
    
    canvas.drawRect(Rect.fromLTWH(size.width/2 - 20, 0, 40, pixelSize), paint..style = PaintingStyle.fill);
    canvas.drawRect(Rect.fromLTWH(size.width/2 - 20, size.height - pixelSize, 40, pixelSize), paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PixelButtonPainter extends CustomPainter {
  final Color color;

  PixelButtonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(10, 0)
      ..lineTo(size.width - 10, 0)
      ..arcToPoint(Offset(size.width, 10), radius: const Radius.circular(5))
      ..lineTo(size.width, size.height - 10)
      ..arcToPoint(Offset(size.width - 10, size.height), radius: const Radius.circular(5))
      ..lineTo(10, size.height)
      ..arcToPoint(Offset(0, size.height - 10), radius: const Radius.circular(5))
      ..lineTo(0, 10)
      ..arcToPoint(const Offset(10, 0), radius: const Radius.circular(5));

    canvas.drawPath(path, paint);
    
    final detailPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
    
    canvas.drawCircle(const Offset(5, 5), 2, detailPaint);
    canvas.drawCircle(Offset(size.width - 5, 5), 2, detailPaint);
    canvas.drawCircle(Offset(5, size.height - 5), 2, detailPaint);
    canvas.drawCircle(Offset(size.width - 5, size.height - 5), 2, detailPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
