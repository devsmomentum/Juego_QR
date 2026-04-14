import 'package:flutter/material.dart';

class CoinImage extends StatelessWidget {
  final double size;
  const CoinImage({super.key, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Transform.scale(
          scale: 1.5, // Zoom even more to hide white edges perfectly
          child: Image.asset(
            'assets/images/coin.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.monetization_on, size: size, color: Colors.amber);
            },
          ),
        ),
      ),
    );
  }
}
