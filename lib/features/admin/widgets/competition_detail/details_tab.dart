import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/coin_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../game/models/event.dart';
import '../../models/sponsor.dart';

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
    fillColor: Colors.white.withOpacity(0.03),
    labelStyle: const TextStyle(color: Colors.white70),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white10),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.accentGold),
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
      prefixIcon: icon != null ? Icon(icon, color: Colors.white38, size: 20) : null,
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
                      color: AppTheme.accentGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accentGold),
                    ),
                    child: const Text(
                      'AUTOMATIZADO',
                      style: TextStyle(
                        color: AppTheme.accentGold,
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
                  color: widget.isEventActive ? Colors.white38 : Colors.white),
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
                  color: widget.isEventActive ? Colors.white38 : Colors.white),
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
                  icon: Icons.star_border),
                dropdownColor: AppTheme.cardBg,
                style: const TextStyle(color: Colors.white),
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
                            color: widget.isEventActive ? Colors.white38 : Colors.white),
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
                                icon: const Icon(Icons.qr_code),
                                label: const Text("Ver QR"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accentGold,
                                  side: const BorderSide(color: AppTheme.accentGold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onGenerateAllQRs,
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text("PDF"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blueAccent,
                                  side: const BorderSide(color: Colors.blueAccent),
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
                            color: widget.isEventActive ? Colors.white38 : Colors.white),
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
                              color: widget.isEventActive ? Colors.white38 : Colors.white),
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
                            color: AppTheme.accentGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.accentGold.withOpacity(0.3)),
                          ),
                          child: IconButton(
                            icon:
                                const Icon(Icons.qr_code, color: AppTheme.accentGold),
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
                            icon: const Icon(Icons.picture_as_pdf,
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
                              color: widget.isEventActive ? Colors.white38 : Colors.white),
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
                            color: widget.isEventActive ? Colors.white38 : Colors.white),
                        decoration: _buildInputDecoration('Precio Entrada').copyWith(
                          suffix: const CoinImage(size: 16),
                          helperText: '0 para GRATIS',
                          helperStyle: const TextStyle(color: Colors.white38),
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
                            color: widget.isEventActive ? Colors.white38 : Colors.white),
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
                              color: widget.isEventActive ? Colors.white38 : Colors.white),
                          decoration: _buildInputDecoration('Precio Entrada').copyWith(
                            suffix: const CoinImage(size: 16),
                            helperText: '0 para GRATIS',
                            helperStyle: const TextStyle(color: Colors.white38),
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
                              color: widget.isEventActive ? Colors.white38 : Colors.white),
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
                    color: AppTheme.accentGold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: MediaQuery.of(context).size.width < 600
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Cantidad de Ganadores:",
                            style: TextStyle(color: Colors.white)),
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
                              selectedBackgroundColor: AppTheme.accentGold,
                              selectedForegroundColor: Colors.black,
                              foregroundColor: Colors.white54,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Cantidad de Ganadores:",
                            style: TextStyle(color: Colors.white)),
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
                                  return AppTheme.accentGold;
                                }
                                return Colors.transparent;
                              },
                            ),
                            foregroundColor: MaterialStateProperty.resolveWith<Color>(
                                (Set<MaterialState> states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors.black;
                              }
                              return Colors.white54;
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
                    color: AppTheme.accentGold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
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
                                  foregroundColor: AppTheme.accentGold,
                                  side: const BorderSide(
                                      color: AppTheme.accentGold),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
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
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
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
                                  foregroundColor: AppTheme.accentGold,
                                  side: const BorderSide(
                                      color: AppTheme.accentGold),
                                ),
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 12),
                  const Text(
                    "Estos precios sobrescriben los valores por defecto de los poderes en este evento.",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
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
                  color: widget.isEventActive ? Colors.white38 : Colors.white),
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
                        color: widget.isEventActive ? Colors.white38 : Colors.white),
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
                      color: AppTheme.primaryPurple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primaryPurple.withOpacity(0.5)),
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.map, color: AppTheme.primaryPurple),
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
                              colorScheme: const ColorScheme.dark(
                                primary: AppTheme.accentGold,
                                onPrimary: Colors.black,
                                surface: AppTheme.cardBg,
                                onSurface: Colors.white,
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
                                  backgroundColor: AppTheme.cardBg,
                                  hourMinuteTextColor: Colors.white,
                                  dayPeriodTextColor: Colors.white,
                                  dialHandColor: AppTheme.accentGold,
                                  dialBackgroundColor: AppTheme.darkBg,
                                  entryModeIconColor: AppTheme.accentGold,
                                ),
                                colorScheme: const ColorScheme.dark(
                                  primary: AppTheme.accentGold,
                                  onPrimary: Colors.black,
                                  surface: AppTheme.cardBg,
                                  onSurface: Colors.white,
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
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: widget.isEventActive ? null : widget.onSave,
                icon: Icon(widget.isEventActive ? Icons.lock : Icons.save),
                label: Text(widget.isEventActive
                    ? "Evento No Editable (${widget.event.status == 'active' ? 'En Curso' : widget.event.status == 'completed' ? 'Completado' : 'Bloqueado'})"
                    : "Guardar Cambios"),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.isEventActive ? Colors.grey : AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
