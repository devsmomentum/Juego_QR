import 'package:flutter/material.dart';
import '../../models/clue.dart';
import '../../../../core/theme/app_theme.dart';

/// Widget de minijuego tipo "Caja Fuerte" donde el usuario debe ingresar 
/// un código de 4 dígitos para desbloquear.
/// 
/// Recibe una [clue] que contiene la respuesta correcta y un callback [onSuccess]
/// que se ejecuta cuando el jugador ingresa el código correcto.
class CodeBreakerWidget extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const CodeBreakerWidget({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<CodeBreakerWidget> createState() => _CodeBreakerWidgetState();
}

class _CodeBreakerWidgetState extends State<CodeBreakerWidget> {
  String _enteredCode = "";
  bool _isError = false;

  void _onDigitPress(String digit) {
    if (_enteredCode.length < 4) {
      setState(() {
        _enteredCode += digit;
        _isError = false;
      });
    }
  }

  void _onDelete() {
    if (_enteredCode.isNotEmpty) {
      setState(() {
        _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
      });
    }
  }

  void _checkCode() {
    final expected = widget.clue.riddleAnswer?.trim() ?? "";
    if (_enteredCode == expected) {
      // ÉXITO: Llamar callback
      widget.onSuccess();
    } else {
      setState(() {
        _isError = true;
        _enteredCode = "";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Código Incorrecto'),
          backgroundColor: AppTheme.dangerRed,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple.withValues(alpha: 0.3),
                  AppTheme.secondaryPink.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 35,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'CAJA FUERTE',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.clue.riddleQuestion ?? "Ingresa el código de 4 dígitos",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          
          // Display de dígitos
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final hasDigit = index < _enteredCode.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 45,
                height: 50,
                decoration: BoxDecoration(
                  color: hasDigit
                      ? AppTheme.successGreen.withValues(alpha: 0.2)
                      : const Color.fromRGBO(0, 0, 0, 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isError
                        ? AppTheme.dangerRed
                        : (hasDigit ? AppTheme.successGreen : Colors.grey),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    hasDigit ? _enteredCode[index] : '',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isError ? AppTheme.dangerRed : Colors.white,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 15),
          
          // Teclado numérico
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              if (index == 9) {
                return _buildKey(
                  icon: Icons.backspace_outlined,
                  onTap: _onDelete,
                  color: AppTheme.warningOrange,
                );
              }
              if (index == 10) {
                return _buildKey(
                  text: '0',
                  onTap: () => _onDigitPress('0'),
                );
              }
              if (index == 11) {
                return _buildKey(
                  icon: Icons.check_circle,
                  onTap: _enteredCode.length == 4 ? _checkCode : null,
                  color: AppTheme.successGreen,
                );
              }
              final digit = '${index + 1}';
              return _buildKey(
                text: digit,
                onTap: () => _onDigitPress(digit),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKey({
    String? text,
    IconData? icon,
    required VoidCallback? onTap,
    Color? color,
  }) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(10),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: onTap != null
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryPurple.withValues(alpha: 0.2),
                      AppTheme.secondaryPink.withValues(alpha: 0.2),
                    ],
                  )
                : null,
          ),
          child: Center(
            child: text != null
                ? Text(
                    text,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color ?? Colors.white,
                    ),
                  )
                : Icon(icon, color: color ?? Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
