import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/coin_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../game/models/event.dart';
import '../../models/sponsor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailsTab extends StatefulWidget {
  final GameEvent event;
  final GlobalKey<FormState> formKey;
  final bool isEventActive;
  final List<Sponsor> sponsors;
  
  // State values
  final String? sponsorId;
  final String title;
  final String description;
  final String pin;
  final String clue;
  final String locationName;
  final int maxParticipants;
  final int entryFee;
  final int betTicketPrice;
  final int configuredWinners;
  final DateTime selectedDate;
  final TextEditingController locationController;

  // Callbacks
  final Function(String?) onSponsorChanged;
  final Function(int) onWinnersChanged;
  final Function(DateTime) onDateChanged;
  final Function() onSelectLocation;
  final Function() onShowQR;
  final Function() onGenerateAllQRs;
  final Function(bool) onShowGlobalPrices;
  final Function() onSave;
  
  // Setters for form values (onSaved)
  final Function(String) onTitleSaved;
  final Function(String) onDescriptionSaved;
  final Function(String) onPinSaved;
  final Function(int) onMaxParticipantsSaved;
  final Function(int) onEntryFeeSaved;
  final Function(int) onBetTicketPriceSaved;
  final Function(String) onClueSaved;
  final Function(String) onLocationNameSaved;

  const DetailsTab({
    super.key,
    required this.event,
    required this.formKey,
    required this.isEventActive,
    required this.sponsors,
    required this.sponsorId,
    required this.title,
    required this.description,
    required this.pin,
    required this.clue,
    required this.locationName,
    required this.maxParticipants,
    required this.entryFee,
    required this.betTicketPrice,
    required this.configuredWinners,
    required this.selectedDate,
    required this.locationController,
    required this.onSponsorChanged,
    required this.onWinnersChanged,
    required this.onDateChanged,
    required this.onSelectLocation,
    required this.onShowQR,
    required this.onGenerateAllQRs,
    required this.onShowGlobalPrices,
    required this.onSave,
    required this.onTitleSaved,
    required this.onDescriptionSaved,
    required this.onPinSaved,
    required this.onMaxParticipantsSaved,
    required this.onEntryFeeSaved,
    required this.onBetTicketPriceSaved,
    required this.onClueSaved,
    required this.onLocationNameSaved,
  });

  @override
  State<DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<DetailsTab> {
  final inputDecoration = InputDecoration(
    filled: true,
    fillColor: Colors.transparent,
    labelStyle: const TextStyle(fontWeight: FontWeight.w500),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.lGoldAction, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  InputDecoration _buildInputDecoration(String label, {IconData? icon}) {
    return inputDecoration.copyWith(
      labelText: label,
      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
      prefixIcon: icon != null ? Icon(icon, color: AppTheme.lGoldAction, size: 20) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final _eventType = widget.event.type;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Info (Type) ---
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _eventType == 'online'
                        ? Colors.blueAccent.withOpacity(0.2)
                        : Colors.orangeAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _eventType == 'online'
                          ? Colors.blueAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _eventType == 'online' ? Icons.public : Icons.location_on,
                        size: 16,
                        color: _eventType == 'online'
                            ? Colors.blueAccent
                            : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _eventType == 'online' ? 'EVENTO ONLINE' : 'EVENTO PRESENCIAL',
                        style: TextStyle(
                          color: _eventType == 'online'
                              ? Colors.blueAccent
                              : Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.event.isAutomated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.lGoldAction.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.lGoldAction.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'AUTOMATIZADO',
                      style: TextStyle(
                        color: AppTheme.lGoldAction,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            TextFormField(
              initialValue: widget.title,
              readOnly: widget.isEventActive,
              style: TextStyle(
                  color: widget.isEventActive 
                      ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                      : Theme.of(context).textTheme.displayLarge?.color,
                  fontWeight: FontWeight.bold),
              decoration: _buildInputDecoration('Título'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
              onSaved: (v) => widget.onTitleSaved(v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.description,
              readOnly: widget.isEventActive,
              maxLines: 3,
              style: TextStyle(
                  color: widget.isEventActive 
                      ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                      : Theme.of(context).textTheme.bodyMedium?.color),
              decoration: _buildInputDecoration('Descripción'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
              onSaved: (v) => widget.onDescriptionSaved(v!),
            ),
            const SizedBox(height: 16),

            // --- Sponsor Selection ---
            if (widget.sponsors.isNotEmpty)
              DropdownButtonFormField<String>(
                value: widget.sponsorId,
                 decoration: _buildInputDecoration('Patrocinador (Opcional)',
                   icon: Icons.star_border_rounded),
                 dropdownColor: Theme.of(context).cardTheme.color,
                 style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text("Sin Patrocinador"),
                  ),
                  ...widget.sponsors.map((sponsor) {
                    return DropdownMenuItem<String>(
                      value: sponsor.id,
                      child: Text(sponsor.name),
                    );
                  }).toList(),
                ],
                onChanged: widget.isEventActive
                    ? null
                    : widget.onSponsorChanged,
              ),
            if (widget.sponsors.isNotEmpty) const SizedBox(height: 16),
            
            MediaQuery.of(context).size.width < 600
                ? Column(
                    children: [
                      TextFormField(
                        initialValue: widget.pin,
                        readOnly: widget.isEventActive,
                        style: TextStyle(
                            color: widget.isEventActive 
                                ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                                : Theme.of(context).textTheme.bodyMedium?.color),
                        decoration:
                            _buildInputDecoration('PIN (6 dígitos)'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (v) =>
                            v!.length != 6 ? 'Debe tener 6 dígitos' : null,
                        onSaved: (v) => widget.onPinSaved(v!),
                      ),
                      const SizedBox(height: 16),
                      if (widget.event.type != 'online')
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onShowQR,
                                icon: const Icon(Icons.qr_code_rounded),
                                label: const Text("Ver QR"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.lGoldAction,
                                    side: const BorderSide(color: AppTheme.lGoldAction),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onGenerateAllQRs,
                                icon: const Icon(Icons.picture_as_pdf_rounded),
                                label: const Text("PDF"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blueAccent,
                                    side: const BorderSide(color: Colors.blueAccent),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                              ),
                            ),
                          ],
                        ),
                      if (widget.event.type != 'online') const SizedBox(height: 16),
                      TextFormField(
                        initialValue: widget.maxParticipants.toString(),
                        readOnly: widget.isEventActive,
                        style: TextStyle(
                            color: widget.isEventActive 
                                ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                                : Theme.of(context).textTheme.bodyMedium?.color),
                        decoration:
                            _buildInputDecoration('Max. Jugadores'),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => widget.onMaxParticipantsSaved(int.parse(v!)),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: widget.pin,
                          readOnly: widget.isEventActive,
                          style: TextStyle(
                              color: widget.isEventActive 
                                  ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                                  : Theme.of(context).textTheme.bodyMedium?.color),
                          decoration:
                              _buildInputDecoration('PIN (6 dígitos)'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (v) =>
                              v!.length != 6 ? 'Debe tener 6 dígitos' : null,
                          onSaved: (v) => widget.onPinSaved(v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.event.type != 'online')
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.lGoldAction.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.lGoldAction.withOpacity(0.3)),
                          ),
                          child: IconButton(
                            icon:
                                const Icon(Icons.qr_code_rounded, color: AppTheme.lGoldAction),
                            tooltip: "Ver QR del Evento",
                            onPressed: widget.onShowQR,
                          ),
                        ),
                      if (widget.event.type != 'online') const SizedBox(width: 8),
                      if (widget.event.type != 'online')
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.picture_as_pdf_rounded,
                                color: Colors.blueAccent),
                            tooltip: "Guardar Todos los QRs (PDF)",
                            onPressed: widget.onGenerateAllQRs,
                          ),
                        ),
                      if (widget.event.type != 'online') const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: widget.maxParticipants.toString(),
                          readOnly: widget.isEventActive,
                          style: TextStyle(
                              color: widget.isEventActive 
                                  ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                                  : Theme.of(context).textTheme.bodyMedium?.color),
                          decoration:
                              _buildInputDecoration('Max. Jugadores'),
                          keyboardType: TextInputType.number,
                          onSaved: (v) => widget.onMaxParticipantsSaved(int.parse(v!)),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 16),

            // Prices Row (Entry Fee + Bet Ticket)
            MediaQuery.of(context).size.width < 600
                ? Column(
                    children: [
                      TextFormField(
                        initialValue: widget.entryFee == 0 ? '' : widget.entryFee.toString(),
                        readOnly: widget.isEventActive,
                        style: TextStyle(
                            color: widget.isEventActive 
                                ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                                : Theme.of(context).textTheme.bodyMedium?.color),
                        decoration: _buildInputDecoration('Precio Entrada').copyWith(
                          suffix: const CoinImage(size: 16),
                          helperText: '0 para GRATIS',
                          helperStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onSaved: (v) =>
                            widget.onEntryFeeSaved((v == null || v.isEmpty) ? 0 : int.parse(v)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: widget.betTicketPrice.toString(),
                        readOnly: widget.isEventActive,
                        style: TextStyle(
                            color: widget.isEventActive 
                                ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                                : Theme.of(context).textTheme.bodyMedium?.color),
                        decoration: _buildInputDecoration('Precio Apuesta').copyWith(
                          suffix: const CoinImage(size: 16),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onSaved: (v) =>
                            widget.onBetTicketPriceSaved((v == null || v.isEmpty) ? 100 : int.parse(v)),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: widget.entryFee == 0 ? '' : widget.entryFee.toString(),
                          readOnly: widget.isEventActive,
                          style: TextStyle(
                              color: widget.isEventActive 
                                  ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                                  : Theme.of(context).textTheme.bodyMedium?.color),
                          decoration: _buildInputDecoration('Precio Entrada').copyWith(
                            suffix: const CoinImage(size: 16),
                            helperText: '0 para GRATIS',
                            helperStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onSaved: (v) =>
                              widget.onEntryFeeSaved((v == null || v.isEmpty) ? 0 : int.parse(v)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: widget.betTicketPrice.toString(),
                          readOnly: widget.isEventActive,
                          style: TextStyle(
                              color: widget.isEventActive 
                                  ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                                  : Theme.of(context).textTheme.bodyMedium?.color),
                          decoration: _buildInputDecoration('Precio Apuesta').copyWith(
                            suffix: const CoinImage(size: 16),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onSaved: (v) =>
                              widget.onBetTicketPriceSaved((v == null || v.isEmpty) ? 100 : int.parse(v)),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 16),

            // Winners Selection
            const Text("Configuración de Premios",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.lGoldAction)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: MediaQuery.of(context).size.width < 600
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Cantidad de Ganadores:",
                            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<int>(
                            segments: const [
                              ButtonSegment<int>(value: 1, label: Text("1")),
                              ButtonSegment<int>(value: 2, label: Text("2")),
                              ButtonSegment<int>(value: 3, label: Text("3")),
                            ],
                            selected: {widget.configuredWinners},
                            onSelectionChanged: widget.isEventActive
                                ? null
                                : (Set<int> newSelection) {
                                    widget.onWinnersChanged(newSelection.first);
                                  },
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: AppTheme.lGoldAction,
                              selectedForegroundColor: Colors.white,
                              foregroundColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Cantidad de Ganadores:",
                            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment<int>(value: 1, label: Text("1")),
                            ButtonSegment<int>(value: 2, label: Text("2")),
                            ButtonSegment<int>(value: 3, label: Text("3")),
                          ],
                          selected: {widget.configuredWinners},
                          onSelectionChanged: widget.isEventActive
                              ? null
                              : (Set<int> newSelection) {
                                  widget.onWinnersChanged(newSelection.first);
                                },
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.selected)) {
                                  return AppTheme.lGoldAction;
                                }
                                return Colors.transparent;
                              },
                            ),
                            foregroundColor: MaterialStateProperty.resolveWith<Color>(
                                (Set<MaterialState> states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors.white;
                              }
                              return Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) ?? Colors.grey;
                            }),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // --- Pricing Section (NEW: Match Creation) ---
            const Text("Tienda y Precios",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.lGoldAction)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  MediaQuery.of(context).size.width < 600
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    widget.onShowGlobalPrices(false),
                                icon: const Icon(Icons.shopping_bag_outlined),
                                label: const Text("Precios Jugadores"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
                                    side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    widget.onShowGlobalPrices(true),
                                icon: const Icon(Icons.visibility_outlined),
                                label: const Text("Precios Espectadores"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.lGoldAction,
                                    side: const BorderSide(
                                        color: AppTheme.lGoldAction),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    widget.onShowGlobalPrices(false),
                                icon: const Icon(Icons.shopping_bag_outlined),
                                label: const Text("Precios Jugadores"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
                                  side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    widget.onShowGlobalPrices(true),
                                icon: const Icon(Icons.visibility_outlined),
                                label: const Text("Precios Espectadores"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.lGoldAction,
                                  side: const BorderSide(
                                      color: AppTheme.lGoldAction),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 12),
                  Text(
                    "Estos precios sobrescriben los valores por defecto de los poderes en este evento.",
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              initialValue: widget.clue,
              readOnly: widget.isEventActive,
               style: TextStyle(
                   color: widget.isEventActive 
                       ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                       : Theme.of(context).textTheme.bodyMedium?.color),
              decoration: _buildInputDecoration('Pista de Victoria / Final'),
              onSaved: (v) => widget.onClueSaved(v!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.locationController,
                    readOnly: widget.isEventActive,
                     style: TextStyle(
                         color: widget.isEventActive 
                             ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4) 
                             : Theme.of(context).textTheme.bodyMedium?.color),
                    decoration: _buildInputDecoration('Nombre de Ubicación'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    onSaved: (v) => widget.onLocationNameSaved(v!),
                  ),
                ),
                const SizedBox(width: 8),
                if (!widget.isEventActive)
                  Container(
                    height: 56,
                    width: 56,
                     decoration: BoxDecoration(
                       color: AppTheme.lGoldAction.withOpacity(0.12),
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(
                           color: AppTheme.lGoldAction.withOpacity(0.3)),
                     ),
                     child: IconButton(
                       icon:
                           const Icon(Icons.map_rounded, color: AppTheme.lGoldAction),
                       tooltip: "Seleccionar en Mapa",
                       onPressed: widget.onSelectLocation,
                     ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // --- DATE & TIME PICKER ---
            InkWell(
              onTap: widget.isEventActive
                  ? null
                  : () async {
                      // 1. Pick Date
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: widget.selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                 primary: AppTheme.lGoldAction,
                                 onPrimary: Colors.white,
                                 surface: Theme.of(context).cardTheme.color!,
                                 onSurface: Theme.of(context).textTheme.displayLarge?.color ?? Colors.black,
                               ),
                             ),
                            child: child!,
                          );
                        },
                      );

                      if (pickedDate != null) {
                        // 2. Pick Time (if date was picked)
                        if (!context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(widget.selectedDate),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                timePickerTheme: TimePickerThemeData(
                                   backgroundColor: Theme.of(context).cardTheme.color,
                                   hourMinuteTextColor: Theme.of(context).textTheme.displayLarge?.color,
                                   dayPeriodTextColor: Theme.of(context).textTheme.displayLarge?.color,
                                   dialHandColor: AppTheme.lGoldAction,
                                   dialBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                   entryModeIconColor: AppTheme.lGoldAction,
                                 ),
                                 colorScheme: ColorScheme.light(
                                   primary: AppTheme.lGoldAction,
                                   onPrimary: Colors.white,
                                   surface: Theme.of(context).cardTheme.color!,
                                   onSurface: Theme.of(context).textTheme.displayLarge?.color ?? Colors.black,
                                 ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedTime != null) {
                          widget.onDateChanged(DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          ));
                        }
                      }
                    },
              child: InputDecorator(
                decoration: _buildInputDecoration('Fecha y Hora del Evento',
                    icon: Icons.access_time),
                   child: Text(
                   "${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}   ${widget.selectedDate.hour.toString().padLeft(2, '0')}:${widget.selectedDate.minute.toString().padLeft(2, '0')}",
                   style: TextStyle(
                       color: Theme.of(context).textTheme.displayLarge?.color, fontWeight: FontWeight.bold),
                 ),
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: widget.isEventActive ? null : widget.onSave,
                icon: Icon(widget.isEventActive ? Icons.lock_rounded : Icons.save_rounded),
                label: Text(widget.isEventActive
                    ? "Evento No Editable (${widget.event.status == 'active' ? 'En Curso' : widget.event.status == 'completed' ? 'Completado' : 'Bloqueado'})"
                    : "Guardar Cambios"),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.isEventActive ? Colors.grey : AppTheme.lGoldAction,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            // --- Station QR Access Code ---
            if (widget.event.type != 'online') ...[
              const SizedBox(height: 24),
              const Text("Estación QR (Tablets)",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.lGoldAction)),
              const SizedBox(height: 12),
              _StationAccessCodeWidget(eventId: widget.event.id),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// Widget to generate and display station access codes.
class _StationAccessCodeWidget extends StatefulWidget {
  final String eventId;
  const _StationAccessCodeWidget({required this.eventId});

  @override
  State<_StationAccessCodeWidget> createState() =>
      _StationAccessCodeWidgetState();
}

class _StationAccessCodeWidgetState extends State<_StationAccessCodeWidget> {
  String? _code;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingCode();
  }

  Future<void> _loadExistingCode() async {
    try {
      final response = await Supabase.instance.client
          .from('events')
          .select('station_access_code')
          .eq('id', widget.eventId)
          .maybeSingle();
      if (mounted && response != null) {
        setState(
            () => _code = response['station_access_code'] as String?);
      }
    } catch (_) {}
  }

  Future<void> _generateCode() async {
    setState(() => _isLoading = true);
    try {
      final result = await Supabase.instance.client
          .rpc('generate_station_access_code', params: {
        'p_event_id': widget.eventId,
      });
      if (mounted) {
        setState(() {
          _code = result as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          if (_code != null) ...[
            Row(
              children: [
                const Icon(Icons.qr_code_2_rounded,
                    color: AppTheme.lGoldAction, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Código de Estación',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        _code!,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: AppTheme.lGoldAction,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: 'Copiar código',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _code!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Código copiado'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Comparte este código con los operadores de las tablets.',
              style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.5),
                  fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _generateCode,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      _code == null
                          ? Icons.add_rounded
                          : Icons.refresh_rounded,
                      size: 18),
              label: Text(
                  _code == null ? 'Generar Código' : 'Regenerar Código'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.lGoldAction,
                side: const BorderSide(color: AppTheme.lGoldAction),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
