import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/country_code.dart';
import '../providers/profile_registration_provider.dart';

/// Campo de teléfono gamificado con selector de código de país.
///
/// Diseño inmersivo: bordes con glow, colores de alto contraste,
/// modal de selección con búsqueda. Se integra con [ProfileRegistrationProvider].
class GamePhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  // --- Colores adaptables para encajar en cualquier UI de juego ---
  final Color backgroundColor;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color textColor;
  final Color hintColor;
  final Color labelColor;
  final Color iconColor;
  final Color selectorBgColor;

  const GamePhoneInputField({
    super.key,
    required this.controller,
    this.validator,
    this.backgroundColor = const Color(0xFF2A2A2E),
    this.borderColor = const Color(0xFF3D3D4D),
    this.focusedBorderColor = const Color(0xFFFECB00), // Gold
    this.textColor = Colors.white,
    this.hintColor = const Color(0x61FFFFFF), // white38
    this.labelColor = const Color(0xB3FFFFFF), // white70
    this.iconColor = const Color(0xFFFECB00), // Gold
    this.selectorBgColor = const Color(0xFF1A1A1D),
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileRegistrationProvider>();
    final selectedCode = provider.selectedCountryCode;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Selector de código de país ---
        GestureDetector(
          onTap: () => _showCountryCodePicker(context, provider),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedCode.flag,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 6),
                Text(
                  selectedCode.dialCode,
                  style: TextStyle(
                    color: focusedBorderColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: labelColor, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // --- Campo de número ---
        Expanded(
          child: TextFormField(
            controller: controller,
            style: TextStyle(color: textColor),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              // Impide cero inicial: el código de país ya se muestra aparte.
              _NoLeadingZeroFormatter(),
              LengthLimitingTextInputFormatter(selectedCode.maxLength),
            ],
            decoration: InputDecoration(
              labelText: 'NÚMERO DE TELÉFONO',
              labelStyle: TextStyle(
                color: labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              hintText: _getHintForCountry(selectedCode.iso),
              hintStyle: TextStyle(color: hintColor, fontSize: 14),
              prefixIcon: Icon(Icons.phone_android_outlined, color: iconColor),
              filled: true,
              fillColor: backgroundColor.withOpacity(0.8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: focusedBorderColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Colors.redAccent, width: 2),
              ),
            ),
            onChanged: (value) => provider.setPhoneNumber(value),
            validator: validator ??
                (value) => provider.validatePhone(value),
          ),
        ),
      ],
    );
  }

  /// Hint dinámico según el país seleccionado.
  String _getHintForCountry(String iso) {
    switch (iso) {
      case 'VE':
        return '4121234567';
      case 'CO':
        return '3001234567';
      case 'MX':
        return '5512345678';
      case 'US':
        return '2025551234';
      case 'ES':
        return '612345678';
      default:
        return '123456789';
    }
  }

  /// Modal estilizado con búsqueda para seleccionar código de país.
  void _showCountryCodePicker(
      BuildContext context, ProfileRegistrationProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CountryCodePickerSheet(
        selectorBgColor: selectorBgColor,
        borderColor: borderColor,
        focusedBorderColor: focusedBorderColor,
        textColor: textColor,
        hintColor: hintColor,
        iconColor: iconColor,
        selectedIso: provider.selectedCountryCode.iso,
        onSelected: (code) {
          provider.setCountryCode(code);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// --- Modal de selección de código de país ---

class _CountryCodePickerSheet extends StatefulWidget {
  final Color selectorBgColor;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color textColor;
  final Color hintColor;
  final Color iconColor;
  final String selectedIso;
  final ValueChanged<CountryCode> onSelected;

  const _CountryCodePickerSheet({
    required this.selectorBgColor,
    required this.borderColor,
    required this.focusedBorderColor,
    required this.textColor,
    required this.hintColor,
    required this.iconColor,
    required this.selectedIso,
    required this.onSelected,
  });

  @override
  State<_CountryCodePickerSheet> createState() =>
      _CountryCodePickerSheetState();
}

class _CountryCodePickerSheetState extends State<_CountryCodePickerSheet> {
  final _searchController = TextEditingController();
  List<CountryCode> _filtered = CountryCode.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = CountryCode.all;
      } else {
        _filtered = CountryCode.all.where((c) {
          return c.name.toLowerCase().contains(query) ||
              c.dialCode.contains(query) ||
              c.iso.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: widget.selectorBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: widget.focusedBorderColor, width: 2),
        ),
        // Glow sutil en la parte superior
        boxShadow: [
          BoxShadow(
            color: widget.focusedBorderColor.withOpacity(0.25),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle decorativo
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: widget.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.public, color: widget.focusedBorderColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  'SELECCIONA TU PAÍS',
                  style: TextStyle(
                    color: widget.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Campo de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: widget.textColor),
              decoration: InputDecoration(
                hintText: 'Buscar país o código...',
                hintStyle: TextStyle(color: widget.hintColor),
                prefixIcon:
                    Icon(Icons.search, color: widget.focusedBorderColor),
                filled: true,
                fillColor: widget.selectorBgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: widget.borderColor, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: widget.borderColor, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: widget.focusedBorderColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Lista de países
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final code = _filtered[index];
                final isSelected = code.iso == widget.selectedIso;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onSelected(code),
                    splashColor: widget.focusedBorderColor.withOpacity(0.15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? widget.focusedBorderColor.withOpacity(0.1)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: widget.borderColor.withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(code.flag, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  code.name,
                                  style: TextStyle(
                                    color: widget.textColor,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  code.iso,
                                  style: TextStyle(
                                    color: widget.hintColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            code.dialCode,
                            style: TextStyle(
                              color: widget.focusedBorderColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle,
                                color: widget.focusedBorderColor, size: 20),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Formatter que impide escribir "0" como primer dígito.
///
/// El código de país (+58, +57, etc.) ya se muestra en el selector separado,
/// por lo que el campo solo debe aceptar el número local sin cero inicial.
class _NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.startsWith('0')) {
      // Rechazar: mantener el valor anterior.
      return oldValue;
    }
    return newValue;
  }
}
