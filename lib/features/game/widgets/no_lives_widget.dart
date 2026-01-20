import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../mall/screens/mall_screen.dart';

class NoLivesWidget extends StatelessWidget {
  const NoLivesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.heart_broken,
                color: AppTheme.dangerRed, size: 64),
            const SizedBox(height: 20),
            const Text(
              "¡SIN VIDAS!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "No puedes jugar sin vidas.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // If this widget is shown as a screen, we pop it when going to mall?
                // Or we push mall on top.
                // The user code: Navigator.of(context).pop(); then push MallScreen.
                // If we use this inside a screen (like PuzzleScreen) that replaces the body,
                // pop() might pop the PuzzleScreen itself.
                // If we use it as a standalone route, pop() pops the NoLivesScreen.
                // This seems consistent with the user's provided snippet.
                Navigator.of(context).pop();
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const MallScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text("Comprar Vidas",
                  style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}
