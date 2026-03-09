import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/services/event_service.dart';
import '../../game/models/event.dart';

class EventMetricsScreen extends StatefulWidget {
  const EventMetricsScreen({super.key});

  @override
  State<EventMetricsScreen> createState() => _EventMetricsScreenState();
}

class _EventMetricsScreenState extends State<EventMetricsScreen> {
  bool _isLoading = true;
  List<GameEvent> _events = [];
  List<GameEvent> _filteredEvents = [];
  int _totalPlayers = 0;
  String _timeFilter = 'Todo'; // 'Hoy', 'Semana', 'Todo'
  Map<int, int> _hourlyFlow = {}; // Hour (0-23) -> Total Players
  int _peakHour = -1;
  int? _selectedHour;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final eventService = EventService(supabase);

      final allEvents = await eventService.fetchEvents(type: 'online');

      // Apply filters in Venezuela Time (UTC-4)
      final nowUtc = DateTime.now().toUtc();
      final nowVzla = nowUtc.subtract(const Duration(hours: 4));

      _events = allEvents.where((e) {
        final vzlaDate = e.date.toUtc().subtract(const Duration(hours: 4));

        if (_timeFilter == 'Hoy') {
          return vzlaDate.year == nowVzla.year &&
              vzlaDate.month == nowVzla.month &&
              vzlaDate.day == nowVzla.day;
        } else if (_timeFilter == 'Semana') {
          return nowVzla.difference(vzlaDate).inDays <= 7;
        }
        return true;
      }).toList();

      int total = 0;
      Map<int, int> hourSum = {};
      Map<int, int> hourCount = {};

      for (var e in _events) {
        total += e.currentParticipants;

        // Venezuela Hour (UTC-4)
        final vzlaHour = e.date.toUtc().subtract(const Duration(hours: 4)).hour;
        hourSum[vzlaHour] = (hourSum[vzlaHour] ?? 0) + e.currentParticipants;
        hourCount[vzlaHour] = (hourCount[vzlaHour] ?? 0) + 1;
      }

      _hourlyFlow = {};
      hourSum.forEach((hour, sum) {
        if (_timeFilter == 'Hoy') {
          _hourlyFlow[hour] = sum;
        } else {
          // Calculate average (rounded)
          _hourlyFlow[hour] = (sum / (hourCount[hour] ?? 1)).round();
        }
      });

      // Calculate peak hour
      int maxPlayers = 0;
      _peakHour = -1;
      _hourlyFlow.forEach((hour, players) {
        if (players > maxPlayers) {
          maxPlayers = players;
          _peakHour = hour;
        }
      });

      if (mounted) {
        setState(() {
          _totalPlayers = total;
          _filteredEvents = _events; // Initial state: all filtered by date
          _selectedHour = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading metrics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterByHour(int? hour) {
    setState(() {
      if (_selectedHour == hour) {
        _selectedHour = null;
        _filteredEvents = _events;
      } else {
        _selectedHour = hour;
        _filteredEvents = _events.where((e) {
          final vzlaHour =
              e.date.toUtc().subtract(const Duration(hours: 4)).hour;
          return vzlaHour == hour;
        }).toList();
      }
    });
  }

  String _formatToVenezuelaTime(DateTime utcDate) {
    final venezuelaTime = utcDate.toUtc().subtract(const Duration(hours: 4));
    return DateFormat('dd/MM HH:mm').format(venezuelaTime);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildSummaryAndPeakRow(),
            const SizedBox(height: 24),
            _buildHourlyChartSection(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedHour == null
                      ? "Historial de Eventos Online"
                      : "Eventos a las ${_selectedHour.toString().padLeft(2, '0')}:00 (Vzla)",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedHour == null) _buildFilterDropdown(),
                if (_selectedHour != null)
                  TextButton.icon(
                    onPressed: () => _filterByHour(null),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text("Limpiar Filtro"),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.secondaryPink),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildEventsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyChartSection() {
    final maxPlayers = _hourlyFlow.values.isNotEmpty
        ? _hourlyFlow.values.reduce((a, b) => a > b ? a : b)
        : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _timeFilter == 'Hoy'
                ? "Distribución por Horas (Flujo Real)"
                : "Distribución por Horas (Promedio por Evento)",
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            _timeFilter == 'Hoy'
                ? "Pulsa una barra para filtrar eventos por rango de hora."
                : "Promedio estimado de participantes históricos por cada hora.",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140, // Chart height
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(24, (index) {
                final players = _hourlyFlow[index] ?? 0;
                final heightFactor = players / maxPlayers;
                final isSelected = _selectedHour == index;
                final isPeak = _peakHour == index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _filterByHour(index),
                    child: Tooltip(
                      message: _timeFilter == 'Hoy'
                          ? "${index.toString().padLeft(2, '0')}:00 - $players jugadores"
                          : "${index.toString().padLeft(2, '0')}:00 - Promedio $players",
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              players > 0 ? "$players" : "",
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white24,
                                  fontSize: 8),
                            ),
                            const SizedBox(height: 4),
                            Flexible(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : (isPeak
                                          ? Colors.orangeAccent.withOpacity(0.8)
                                          : AppTheme.primaryPurple.withOpacity(
                                              0.4 + (heightFactor * 0.6))),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4)),
                                ),
                                height: heightFactor * 100,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${index.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white38,
                                  fontSize: 9,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Métricas de Eventos",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Análisis de flujo y participación.",
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
        IconButton(
          onPressed: _loadMetrics,
          icon: const Icon(Icons.refresh,
              color: AppTheme.primaryPurple, size: 20),
          tooltip: "Actualizar",
        ),
      ],
    );
  }

  Widget _buildSummaryAndPeakRow() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        _MetricCard(
          title: "Eventos",
          value: _events.length.toString(),
          icon: Icons.cloud_outlined,
          color: AppTheme.primaryPurple,
        ),
        _MetricCard(
          title: "Participantes",
          value: _totalPlayers.toString(),
          icon: Icons.people_outline,
          color: AppTheme.secondaryPink,
        ),
        if (_peakHour != -1)
          _MetricCard(
            title: "Hora Pico (Vzla)",
            value: "${_peakHour.toString().padLeft(2, '0')}:00",
            icon: Icons.access_time_filled,
            color: Colors.orangeAccent,
          ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _timeFilter,
          dropdownColor: AppTheme.cardBg,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: ['Hoy', 'Semana', 'Todo'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _timeFilter = val);
              _loadMetrics();
            }
          },
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    if (_filteredEvents.isEmpty) {
      return const Center(
        child: Text(
          "No hay eventos para este filtro.",
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredEvents.length,
      itemBuilder: (context, index) {
        final event = _filteredEvents[index];
        return Card(
          color: AppTheme.cardBg,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flash_on,
                  color: AppTheme.primaryPurple, size: 20),
            ),
            title: Text(
              event.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  event.status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(event.status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Vzla: ${_formatToVenezuelaTime(event.date)}",
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${event.currentParticipants}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.person, color: Colors.white24, size: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.greenAccent;
      case 'completed':
        return Colors.blueAccent;
      case 'pending':
        return Colors.orangeAccent;
      default:
        return Colors.white54;
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
