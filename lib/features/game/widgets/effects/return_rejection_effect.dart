import 'package:flutter/material.dart';

class ReturnRejectionEffect extends StatefulWidget {
  final String? returnedBy;

  const ReturnRejectionEffect({super.key, this.returnedBy});

  @override
  State<ReturnRejectionEffect> createState() => _ReturnRejectionEffectState();
}

class _ReturnRejectionEffectState extends State<ReturnRejectionEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.1).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 60),
    ]).animate(_controller);

    _shake = Tween<double>(begin: -6.0, end: 6.0).chain(CurveTween(curve: Curves.elasticIn)).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: RotationTransition(
            turns: Tween<double>(begin: -0.05, end: 0.0).animate(_controller),
            child: Container(
              width: size.width * 0.75,
              height: size.width * 1.1, // Aspecto de carta
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 25,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.3),
                    blurRadius: 40,
                  )
                ],
              ),
              child: Stack(
                children: [
                  // Diseño interno de la carta (estilo UNO)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icono de Reverso Grande Central
                            Transform.rotate(
                              angle: 0.5,
                              child: const Icon(
                                Icons.sync_rounded,
                                color: Colors.white,
                                size: 120,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "REVERSO",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Iconos pequeños en las esquinas
                  const Positioned(
                    top: 20,
                    left: 20,
                    child: Icon(Icons.sync_rounded, color: Colors.white, size: 30),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationZ(3.14159),
                      child: const Icon(Icons.sync_rounded, color: Colors.white, size: 30),
                    ),
                  ),

                  // Overlay de información del rival
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 60),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "DEVOLUCIÓN DE:",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          Text(
                            widget.returnedBy?.toUpperCase() ?? "UN RIVAL",
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Banner de alerta inferior
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "¡SUFRES TU PODER!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
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
