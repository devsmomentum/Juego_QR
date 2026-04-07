import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:map_hunter/features/admin/services/admin_service.dart';
import '../../game/models/event.dart';
import '../../game/models/clue.dart';
import '../../game/providers/event_provider.dart';
import '../../game/providers/game_request_provider.dart';
import '../../game/models/game_request.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/qr_display_dialog.dart';
import '../widgets/request_tile.dart';
import '../../auth/providers/player_provider.dart';
import '../../../shared/models/player.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../mall/providers/store_provider.dart';
import '../widgets/store_edit_dialog.dart';
import '../widgets/clue_form_dialog.dart';
import '../../mall/models/mall_store.dart';
import '../widgets/competition_financials_widget.dart';
import '../../../shared/widgets/coin_image.dart';
import '../widgets/location_picker_dialog.dart';
import '../widgets/competition_detail/details_tab.dart';
import '../widgets/competition_detail/participants_tab.dart';
import '../widgets/competition_detail/clues_tab.dart';
import '../widgets/competition_detail/stores_tab.dart';
import '../widgets/competition_detail/safe_reset_confirm_dialog.dart';
import '../widgets/competition_detail/reset_summary_dialog.dart';

class CompetitionDetailScreen extends StatefulWidget {
  final GameEvent event;

  const CompetitionDetailScreen({super.key, required this.event});

  @override
  State<CompetitionDetailScreen> createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Helper method for consistent input styling
  InputDecoration _buildInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(context).cardTheme.color,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.lGoldAction),
      ),
      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
      prefixIcon: icon != null ? Icon(icon, color: AppTheme.lGoldAction) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // Form State
  late String _title;
  late String _description;
  late String _locationName;
  late TextEditingController _locationController;

  void _showQRDialog(String data, String title, String label, {String? hint}) {
    showDialog(
      context: context,
      builder: (_) =>
          QRDisplayDialog(data: data, title: title, label: label, hint: hint),
    );
  }

  late double _latitude;
  late double _longitude;
  late String _clue;
  late String _pin;
  late int _maxParticipants;
  late int _entryFee; // NEW: State for price
  late DateTime _selectedDate;
  late String _eventType; // NEW
  late int _configuredWinners; // NEW
  late int _betTicketPrice; // NEW
  bool _sponsorsEnabled = false;
  Map<String, int> _spectatorPrices = {}; // NEW

  XFile? _selectedImage;
  bool _isLoading = false;
  bool _prizesDistributed = false; // New state
  int _pot = 0; // State for pot
  List<Map<String, dynamic>> _leaderboardData = [];

  Map<String, String> _playerStatuses =
      {}; // Cache para estados locales de baneo
  RealtimeChannel? _gamePlayersChannel; // Channel for realtime updates
  Future<List<Clue>>? _cluesFuture; // Cached future to prevent FutureBuilder flickering

  Future<void> _fetchPlayerStatuses([AdminService? adminService]) async {
    debugPrint(
        'CompetitionDetailScreen: _fetchPlayerStatuses CALLED for event ${widget.event.id}');
    try {
      // Use provided adminService or get from context
      final service =
          adminService ?? Provider.of<AdminService>(context, listen: false);
      final statuses =
          await service.fetchEventParticipantStatuses(widget.event.id);
      debugPrint(
          'CompetitionDetailScreen: Fetched ${statuses.length} player statuses: $statuses');
      if (mounted) {
        setState(() {
          _playerStatuses = statuses;
        });
        debugPrint('CompetitionDetailScreen: UI updated with new statuses');
      }
    } catch (e) {
      debugPrint("Error loading player statuses: $e");
    }
  }

  Future<void> _fetchLeaderboard() async {
    try {
      // Fetch ranking from game_players with profile data via PostgREST join
      final playersData = await Supabase.instance.client
          .from('game_players')
          .select(
              'user_id, completed_clues:completed_clues_count, last_active, coins, lives, profiles(name, email, avatar_id)')
          .eq('event_id', widget.event.id)
          .neq('status', 'spectator')
          .order('completed_clues_count', ascending: false)
          .order('last_active', ascending: true);

      if (playersData.isEmpty) {
        if (mounted) setState(() => _leaderboardData = []);
        return;
      }

      // Flatten joined profile data into each row
      final enrichedData = (playersData as List).map((p) {
        final profile = p['profiles'];
        return {
          'user_id': p['user_id'],
          'completed_clues': p['completed_clues'],
          'last_active': p['last_active'],
          'coins': p['coins'],
          'lives': p['lives'],
          'name': (profile is Map ? profile['name'] : null) ?? 'Usuario',
          'email': profile is Map ? profile['email'] : null,
          'avatar_id': profile is Map ? profile['avatar_id'] : null,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _leaderboardData = List<Map<String, dynamic>>.from(enrichedData);
        });
      }
    } catch (e) {
      debugPrint("Error loading leaderboard: $e");
    }
  }

  Future<void> _fetchEventDetails() async {
    try {
      final data = await Supabase.instance.client
          .from('events')
          .select('pot')
          .eq('id', widget.event.id)
          .single();

      if (mounted) {
        setState(() {
          _pot = (data['pot'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error refreshing event details: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide FAB
    });

    // Initialize form data
    _title = widget.event.title;
    _description = widget.event.description;
    _locationName = widget.event.locationName;
    _locationController = TextEditingController(text: _locationName);
    _latitude = widget.event.latitude;
    _longitude = widget.event.longitude;
    _clue = widget.event.clue;
    _pin = widget.event.pin;
    _maxParticipants = widget.event.maxParticipants;
    _entryFee = widget.event.entryFee; // NEW: Init
    _selectedDate = widget.event.date.toLocal();
    _pot = widget.event.pot; // Init pot
    _eventType = widget.event.type; // NEW
    _configuredWinners = widget.event.configuredWinners; // NEW
    _betTicketPrice = widget.event.betTicketPrice; // NEW
    _sponsorsEnabled = widget.event.sponsorsEnabled;
    _spectatorPrices = Map<String, int>.from(widget.event.spectatorConfig.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    )); // NEW

    // Load requests for this event
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GameRequestProvider>(context, listen: false)
          .fetchAllRequests();
      // Cargar lista de jugadores para verificar estados de baneo
      Provider.of<PlayerProvider>(context, listen: false).fetchAllPlayers();
      _fetchLeaderboard(); // Cargar ranking
      // Cargar tiendas
      Provider.of<StoreProvider>(context, listen: false)
          .fetchStores(widget.event.id);
      // Cargar pistas
      _cluesFuture = Provider.of<EventProvider>(context, listen: false)
          .fetchCluesForEvent(widget.event.id);
      _fetchPlayerStatuses(); // Cargar estados locales

      // Capture AdminService before subscription to avoid context issues
      final adminService = Provider.of<AdminService>(context, listen: false);

      // Subscribe to game_players changes for realtime UI updates
      debugPrint(
          '🔔 CompetitionDetailScreen: Setting up realtime subscription for event ${widget.event.id}');

      try {
        _gamePlayersChannel = Supabase.instance.client
            .channel('game_players_${widget.event.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'game_players',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'event_id',
                value: widget.event.id,
              ),
              callback: (payload) {
                debugPrint(
                    '🔔 CompetitionDetailScreen: REALTIME UPDATE received!');
                debugPrint('   - Event type: ${payload.eventType}');
                debugPrint('   - Table: ${payload.table}');
                debugPrint('   - New record: ${payload.newRecord}');
                debugPrint('   - Old record: ${payload.oldRecord}');

                if (mounted) {
                  _fetchPlayerStatuses(adminService);
                  _fetchEventDetails(); // Refresh pot on player changes
                }
              },
            )
            .subscribe((status, error) {
          debugPrint(
              '🔔 CompetitionDetailScreen: Subscription status changed: $status');
          if (error != null) {
            debugPrint(
                '🔔 CompetitionDetailScreen: Subscription ERROR: $error');
          }
        });

        debugPrint('🔔 CompetitionDetailScreen: Channel created successfully');
      } catch (e) {
        debugPrint(
            '🔔 CompetitionDetailScreen: Failed to setup subscription: $e');
      }

      _checkPrizeStatus(adminService); // Check on init
    });
  }

  Future<void> _checkPrizeStatus([AdminService? service]) async {
    try {
      final adminService =
          service ?? Provider.of<AdminService>(context, listen: false);
      final distributed =
          await adminService.checkPrizeDistributionStatus(widget.event.id);
      if (mounted) {
        setState(() => _prizesDistributed = distributed);
      }
    } catch (e) {
      debugPrint('Error checking prize status: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationController.dispose();
    _gamePlayersChannel?.unsubscribe(); // Unsubscribe from realtime channel
    super.dispose();
  }

  Future<void> _selectLocationOnMap() async {
    final latlng.LatLng? picked = await showDialog<latlng.LatLng>(
      context: context,
      builder: (context) => LocationPickerDialog(
        initialLatitude: _latitude,
        initialLongitude: _longitude,
      ),
    );

    if (picked != null) {
      String address = 'Ubicación seleccionada';
      final apiKey = 'pk.45e576837f12504a63c6d1893820f1cf';
      final url = Uri.parse(
          'https://us1.locationiq.com/v1/reverse.php?key=$apiKey&lat=${picked.latitude}&lon=${picked.longitude}&format=json');
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) {
            address = data['display_name'] ?? 'Ubicación seleccionada';
          }
        }
      } catch (_) {
        // Fallback
      }

      if (mounted) {
        setState(() {
          _latitude = picked.latitude;
          _longitude = picked.longitude;
          _locationName = address;
          _locationController.text = _locationName;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final ext = image.name.split('.').last.toLowerCase();
      if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚠️ Formato no soportado (.$ext). Solo se permiten imágenes JPG o PNG.'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
        return;
      }
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _generateAllQRsPdf() async {
    setState(() => _isLoading = true);
    try {
      final doc = pw.Document();

      // Load fonts
      final fontBold = await PdfGoogleFonts.nunitoBold();
      final fontItalic = await PdfGoogleFonts.nunitoItalic();

      // Add page helper
      void addQRPage(String data, String title, String label, String? hint) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: data,
                      width: 400,
                      height: 400,
                    ),
                    pw.SizedBox(height: 20),
                    if (label.isNotEmpty)
                      pw.Text(
                        label,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 22,
                        ),
                      ),
                    if (hint != null && hint.isNotEmpty) ...[
                      pw.SizedBox(height: 20),
                      pw.Text(
                        hint,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: fontItalic,
                          fontSize: 18,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      }

      // 1. Event Access QR
      if (_pin.length == 6) {
        addQRPage("EVENT:${widget.event.id}:$_pin", "QR de Acceso al Evento",
            "", "Escanea este código para entrar");
      }

      // 2. Clues QRs
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final clues = await eventProvider.fetchCluesForEvent(widget.event.id);
      for (var clue in clues) {
        addQRPage("CLUE:${widget.event.id}:${clue.id}", clue.title,
            "Pista: ${clue.puzzleType.label}", clue.hint);
      }

      // 3. Stores QRs
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final stores = storeProvider.stores;
      for (var store in stores) {
        if (store.qrCodeData.isNotEmpty) {
          addQRPage(store.qrCodeData, "QR de Tienda", store.name,
              "Escanea para entrar");
        }
      }

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename:
            'todos_qr_evento_${_pin.isNotEmpty ? _pin : widget.event.id}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al generar PDF: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    // Validación de estado: solo se permite guardar si el evento está en 'pending'
    if (widget.event.status != 'pending') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⛔ No se puede editar: el evento ya no está en estado pendiente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final updatedEvent = widget.event.copyWith(
        title: _title,
        description: _description,
        clue: _clue,
        maxParticipants: _maxParticipants,
        pin: _pin,
        entryFee: _entryFee,
        type: _eventType,
        configuredWinners: _configuredWinners,
        betTicketPrice: _betTicketPrice,
        sponsorsEnabled: _sponsorsEnabled,
        spectatorConfig: _spectatorPrices,
      );

      await Provider.of<EventProvider>(context, listen: false)
          .updateEvent(updatedEvent, _selectedImage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Competencia actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => SafeResetConfirmDialog(
            eventTitle: widget.event.title,
          ),
        ) ??
        false;
  }

  /// Shows a post-reset summary dialog with integrity verification
  void _showResetSummary(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (ctx) => ResetSummaryDialog(result: result),
    );
  }



  // --- Pot Logic ---

  int get _activeParticipantCount {
    return _playerStatuses.values
        .where((status) =>
            ['active', 'banned', 'suspended', 'eliminated'].contains(status))
        .length;
  }

  // Use the local state pot
  int get _currentPot => _pot;

  Future<void> _approveAll(List<GameRequest> pending) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text("¿Aceptar a todos?",
            style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color)),
        content: Text(
            "Se aprobarán las ${pending.length} solicitudes pendientes de manera instantánea. ¿Estás seguro?",
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.lGoldAction),
            onPressed: () => Navigator.pop(ctx, true),
            child: const FittedBox(
              child: Text("ACEPTAR TODOS",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final provider = Provider.of<GameRequestProvider>(context, listen: false);

    int successCount = 0;
    int errorCount = 0;

    for (var req in pending) {
      try {
        final result = await provider.approveRequest(req.id);
        if (result['success'] == true) {
          successCount++;
        } else {
          errorCount++;
        }
      } catch (e) {
        errorCount++;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $successCount solicitudes aprobadas' +
              (errorCount > 0 ? '. ❌ $errorCount fallaron.' : '')),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
        ),
      );
      _loadData(); // Actualizar datos
    }
  }

  void _loadData() {
    setState(() {});
    Provider.of<GameRequestProvider>(context, listen: false).fetchAllRequests();
    _fetchLeaderboard();
    _fetchPlayerStatuses();
    _checkPrizeStatus(); // Re-check status on reload
    _fetchEventDetails(); // Refresh pot
  }

  Future<void> _distributePrizes() async {
    // 1. Confirmación Inicial
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text('Finalizar y Premiar',
            style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Pote Acumulado: $_currentPot ',
                  style: const TextStyle(
                      color: AppTheme.lGoldAction,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const CoinImage(size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Se distribuirá el 70% de lo recaudado entre los 3 primeros lugares del ranking actual.',
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 10),
            const Text(
              '⚠️ Esta acción finalizará el evento y es IRREVERSIBLE.',
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.lGoldAction),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DISTRIBUIR PREMIOS',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await Provider.of<AdminService>(context, listen: false)
          .distributeCompetitionPrizes(widget.event.id);

      if (mounted) {
        if (result['success'] == true) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).cardTheme.color,
              title: Text('🎉 ¡Premios Entregados!',
                  style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Pote Total: ${result['pot']} ',
                            style: const TextStyle(
                                color: AppTheme.lGoldAction,
                                fontWeight: FontWeight.bold)),
                        const CoinImage(size: 16),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (result['results'] != null)
                      ...(result['results'] as List).map((r) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: r['place'] == 1
                                  ? Colors.yellow
                                  : (r['place'] == 2
                                      ? Colors.grey
                                      : Colors.brown),
                              child: Text('${r['place']}'),
                            ),
                            title: Text('${r['user']}',
                                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('+${r['amount']} ',
                                    style: const TextStyle(
                                        color: Colors.greenAccent)),
                                const CoinImage(size: 14),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
          // Recargar datos y salir o refrescar
          _loadData();
          // Opcional: Cerrar pantalla si el evento ya terminó
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: ${result['message']}'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error crítico: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardTheme.color,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.displayLarge?.color),
        title: Text(
          widget.event.title,
          style: TextStyle(
            color: Theme.of(context).textTheme.displayLarge?.color,
            fontWeight: FontWeight.w900,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: [
          if (widget.event.type != 'online')
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
              tooltip: "Generar y Guardar Todos los QRs",
              onPressed: () {
                if (_pin.length == 6) {
                  _generateAllQRsPdf();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Guarda el PIN primero')),
                  );
                }
              },
            ),
          if (widget.event.status == 'pending')
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded,
                  color: Colors.green, size: 30),
              tooltip: "Iniciar Evento (Admin)",
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Theme.of(context).cardTheme.color,
                    title: Text("¿Iniciar Evento Ahora?",
                        style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color)),
                    content: Text(
                      "El evento pasará a estado 'active' inmediatamente. Esta acción es exclusiva del administrador y no puede revertirse automáticamente.",
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancelar"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.lGoldAction),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("INICIAR",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                setState(() => _isLoading = true);
                try {
                  // Use secure RPC instead of direct status update
                  await Provider.of<EventProvider>(context, listen: false)
                      .startEvent(widget.event.id);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('🚀 ¡Evento iniciado correctamente!'),
                          backgroundColor: Colors.green),
                    );
                    Navigator.pop(context); // Close screen or refresh?
                    // Better to just refresh state or let the provider notify listeners
                    // But since status changed, the UI might need a full reload or just setState
                    // We are listening to provider changes in the parent list, but here?
                    // The widget.event is final, so it won't update automatically unless we navigate back
                    // or re-fetch.
                    // Let's pop to list to be safe and simple.
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error al iniciar: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Colors.orange),
            tooltip: "Reiniciar Competencia",
            onPressed: () async {
              final confirmed = await _showConfirmDialog();
              if (!confirmed) return;

              setState(() => _isLoading = true);
              try {
                // 1. Call the safe atomic RPC (not the old nuclear edge function)
                final result =
                    await Provider.of<EventProvider>(context, listen: false)
                        .safeResetEvent(widget.event.id);

                // 2. Refresh local data to sync with server state
                if (mounted) {
                  Provider.of<GameRequestProvider>(context, listen: false)
                      .fetchAllRequests();
                  Provider.of<PlayerProvider>(context, listen: false)
                      .fetchAllPlayers();
                  _fetchLeaderboard();
                }

                // 3. Show integrity-verified summary
                if (mounted) {
                  _showResetSummary(result);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error al reiniciar: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5)),
            onPressed: () {
              setState(() {});
              Provider.of<GameRequestProvider>(context, listen: false)
                  .fetchAllRequests();
              _fetchLeaderboard(); // Recargar ranking
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.lGoldAction,
          unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4),
          indicatorColor: AppTheme.lGoldAction,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Detalles"),
            Tab(text: "Participantes"),
            Tab(text: "Pistas de Juego"),
            Tab(text: "Tiendas"),
            Tab(text: "Finanzas"),
          ],
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDetailsTab(),
            _buildParticipantsTab(),
            _buildCluesTab(),
            _buildStoresTab(),
            CompetitionFinancialsWidget(event: widget.event),
          ],
        ),
      ),
      floatingActionButton: _getFAB(),
    );
  }

  /// El evento es editable ÚNICAMENTE si su status es 'pending'.
  /// Si el status es nulo o cualquier valor distinto de 'pending', se bloquea (fail-safe).
  bool get _isEventActive {
    return widget.event.status != 'pending';
  }

  Widget? _getFAB() {
    // Si el evento está activo, no permitimos agregar nada (pistas ni tiendas)
    if (_isEventActive) return null;

    if (_tabController.index == 2) {
      return FloatingActionButton(
        backgroundColor: AppTheme.lGoldAction,
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (_) => ClueFormDialog(
              eventId: widget.event.id,
              eventLatitude: widget.event.latitude,
              eventLongitude: widget.event.longitude,
            ),
          );
          if (result == true) _refreshClues();
        },
        child: const Icon(Icons.add_rounded, color: Colors.white),
      );
    } else if (_tabController.index == 3) {
      return FloatingActionButton(
        backgroundColor: AppTheme.lGoldAction,
        onPressed: () => _showAddStoreDialog(),
        child: const Icon(Icons.store_rounded, color: Colors.white),
      );
    }
    return null;
  }

  Widget _buildDetailsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return DetailsTab(
      event: widget.event,
      formKey: _formKey,
      isEventActive: _isEventActive,
      sponsorsEnabled: _sponsorsEnabled,
      title: _title,
      description: _description,
      pin: _pin,
      clue: _clue,
      locationName: _locationName,
      maxParticipants: _maxParticipants,
      entryFee: _entryFee,
      betTicketPrice: _betTicketPrice,
      configuredWinners: _configuredWinners,
      selectedDate: _selectedDate,
      locationController: _locationController,
      onSponsorsEnabledChanged: (value) => setState(() => _sponsorsEnabled = value),
      onWinnersChanged: (value) => setState(() => _configuredWinners = value),
      onDateChanged: (value) => setState(() => _selectedDate = value),
      onSelectLocation: _selectLocationOnMap,
      onShowQR: () {
        if (_pin.length == 6) {
          final qrData = "EVENT:${widget.event.id}:$_pin";
          _showQRDialog(qrData, "QR de Acceso", "PIN: $_pin");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guarda el PIN primero')),
          );
        }
      },
      onGenerateAllQRs: () {
        if (_pin.length == 6) {
          _generateAllQRsPdf();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guarda el PIN primero')),
          );
        }
      },
      onShowGlobalPrices: (isSpectator) =>
          _showGlobalPricesDialog(isSpectatorMode: isSpectator),
      onSave: _saveChanges,
      onTitleSaved: (v) => _title = v,
      onDescriptionSaved: (v) => _description = v,
      onPinSaved: (v) => _pin = v,
      onMaxParticipantsSaved: (v) => _maxParticipants = v,
      onEntryFeeSaved: (v) => _entryFee = v,
      onBetTicketPriceSaved: (v) => _betTicketPrice = v,
      onClueSaved: (v) => _clue = v,
      onLocationNameSaved: (v) => _locationName = v,
    );
  }





  Widget _buildParticipantsTab() {
    return ParticipantsTab(
      event: widget.event,
      leaderboardData: _leaderboardData,
      playerStatuses: _playerStatuses,
      onFetchPlayerStatuses: _fetchPlayerStatuses,
      onFetchLeaderboard: _fetchLeaderboard,
      onApproveAll: _approveAll,
    );
  }

  void _refreshClues() {
    setState(() {
      _cluesFuture = Provider.of<EventProvider>(context, listen: false)
          .fetchCluesForEvent(widget.event.id);
    });
  }

  Widget _buildCluesTab() {
    return CluesTab(
      event: widget.event,
      cluesFuture: _cluesFuture,
      onRefresh: _refreshClues,
      onShowQR: _showQRDialog,
    );
  }

  // Edit legacy method removed

  void _showRestartConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text("¿Reiniciar Competencia?",
            style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color)),
        content: Text(
          "Esto expulsará a todos los participantes actuales, eliminará su progreso y bloqueará las pistas nuevamente. Esta acción no se puede deshacer.",
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final confirm =
                  await _showConfirmDialog(); // Diálogo de confirmación
              if (!confirm) return;

              setState(() => _isLoading = true);
              try {
                // 1. Ejecutar limpieza en base de datos
                await Provider.of<EventProvider>(context, listen: false)
                    .restartCompetition(widget.event.id);

                // 2. Refrescar todos los datos locales para sincronizar
                if (mounted) {
                  Provider.of<GameRequestProvider>(context, listen: false)
                      .fetchAllRequests();
                  Provider.of<PlayerProvider>(context, listen: false)
                      .fetchAllPlayers();
                  _fetchLeaderboard();
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            '✅ Competencia y progreso eliminados correctamente')),
                  );
                }
              } catch (e) {
                // Manejo de error
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text("REINICIAR AHORA",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStoresTab() {
    return StoresTab(
      event: widget.event,
      isEventActive: _isEventActive,
      onShowAddStoreDialog: (store) => _showAddStoreDialog(store: store),
      onConfirmDeleteStore: _confirmDeleteStore,
      onShowQR: _showQRDialog,
    );
  }

  void _showGlobalPricesDialog({bool isSpectatorMode = false}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StoreEditDialog(
        eventId: widget.event.id,
        initialPrices: isSpectatorMode ? _spectatorPrices : widget.event.storePrices,
        isGlobalMode: true,
        isSpectator: isSpectatorMode,
      ),
    );

    if (result != null && result.containsKey('customPrices')) {
      try {
        final prices = Map<String, int>.from(result['customPrices']);
        
        if (isSpectatorMode) {
          await context
              .read<EventProvider>()
              .updateEventSpectatorConfig(widget.event.id, prices);
          setState(() {
            _spectatorPrices = prices;
          });
        } else {
          await context
              .read<EventProvider>()
              .updateEventStorePrices(widget.event.id, prices);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Precios ${isSpectatorMode ? 'de espectador' : 'globales'} actualizados')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  void _showAddStoreDialog({MallStore? store}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          StoreEditDialog(store: store, eventId: widget.event.id),
    );

    if (result != null && mounted) {
      final newStore = result['store'] as MallStore;
      final imageFile = result['imageFile'];

      final provider = Provider.of<StoreProvider>(context, listen: false);
      try {
        if (store == null) {
          await provider.createStore(newStore, imageFile);
          if (mounted)
            _showSnackBar('Tienda creada exitosamente', Colors.green);
        } else {
          await provider.updateStore(newStore, imageFile);
          if (mounted)
            _showSnackBar('Tienda actualizada exitosamente', Colors.green);
        }
      } catch (e) {
        if (mounted) _showSnackBar('Error: $e', Colors.red);
      }
    }
  }

  void _confirmDeleteStore(MallStore store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        surfaceTintColor: Colors.transparent,
        title: Text("Confirmar Eliminación",
            style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color)),
        content: Text("¿Estás seguro de eliminar a ${store.name}?",
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Provider.of<StoreProvider>(context, listen: false)
                    .deleteStore(store.id, widget.event.id);
                if (mounted) _showSnackBar('Tienda eliminada', Colors.green);
              } catch (e) {
                if (mounted) _showSnackBar('Error: $e', Colors.red);
              }
            },
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}


