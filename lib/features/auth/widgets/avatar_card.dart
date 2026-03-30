import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AvatarCard extends StatelessWidget {
  final String avatarId;
  final String name;
  final String description;
  final bool isSelected;
  
  // Custom colors for different characters
  final Color primaryAccent;
  final Color secondaryAccent;

  const AvatarCard({
    super.key,
    required this.avatarId,
    required this.name,
    required this.description,
    this.isSelected = false,
    this.primaryAccent = const Color(0xFFE28551), // Default Copper
    this.secondaryAccent = const Color(0xFF8B4513), // Default Dark Copper
  });

  @override
  Widget build(BuildContext context) {
    const Color cardBg = Color(0xFF1E1E26);
    const Color portraitBg = Color(0xFF16161D);
    
    // Use gold as a highlight for circles, or adapt to secondary if needed
    final Color highlightColor = (primaryAccent == const Color(0xFFE28551)) 
        ? const Color(0xFFFECB00) 
        : secondaryAccent;

    return Container(
      width: 290,
      height: 440,
      decoration: BoxDecoration(
        color: cardBg.withOpacity(0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 0.8,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Muesca superior (Top Notch)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 110,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D0D0F),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 45,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryAccent.withOpacity(0.3), secondaryAccent],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Contenido Principal
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: [
                const SizedBox(height: 15),
                // Área del Retrato
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: portraitBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Imagen del Avatar
                        Image.asset(
                          'assets/images/avatars/$avatarId.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            color: Colors.white12,
                            size: 90,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 25),
                
                // Área de Texto
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Text(
                        name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Decoración Izquierda (Líneas Paralelas)
          Positioned(
            left: 14,
            bottom: 35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                12,
                (index) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  width: 30,
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryAccent.withOpacity(0.4), secondaryAccent.withOpacity(0.4)],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),

          // Decoración Derecha (Barra de Poder/Estado)
          Positioned(
            right: 14,
            bottom: 35,
            child: Column(
              children: [
                // Indicador Superior
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: highlightColor.withOpacity(0.8), width: 1.5),
                  ),
                ),
                const SizedBox(height: 10),
                // Barra Vertical con Gradiente
                Container(
                  width: 16,
                  height: 120,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: highlightColor.withOpacity(0.3), width: 1.5),
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 7,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [secondaryAccent, primaryAccent, secondaryAccent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Indicador Inferior
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: highlightColor.withOpacity(0.6), width: 1.5),
                  ),
                ),
              ],
            ),
          ),

          // Acento de Brillo Inferior (Circular Gradient)
          Positioned(
            bottom: -5,
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Glow Effect
                  Container(
                    width: 160,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          secondaryAccent.withOpacity(0.35),
                          Colors.transparent,
                        ],
                        radius: 0.8,
                      ),
                    ),
                  ),
                  // Solid Shape
                  Container(
                    width: 130,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          secondaryAccent.withOpacity(0.05),
                          primaryAccent.withOpacity(0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(100),
                        topRight: Radius.circular(100),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
