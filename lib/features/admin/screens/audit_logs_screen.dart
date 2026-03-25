import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../models/audit_log.dart';
import '../../../shared/models/player.dart';
import '../../../core/theme/app_theme.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<AuditLog> _logs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  String? _selectedActionType;
  final List<String> _actionTypes = [
    'INSERT',
    'UPDATE',
    'DELETE',
    'PLAYER_ACCEPTED',
    'UPDATE_SENSITIVE'
  ];

  String? _selectedAdminId;
  List<Player> _admins = [];
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadLogs();
    }
  }

  Future<void> _loadAdmins() async {
    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      final admins = await adminService.fetchAdmins();
      if (mounted) {
        setState(() {
          _admins = admins;
        });
      }
    } catch (e) {
      debugPrint('Error loading admins: $e');
    }
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _logs.clear();
        _offset = 0;
        _hasMore = true;
      }
    });

    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      final newLogs = await adminService.getAuditLogs(
        limit: _limit,
        offset: _offset,
        actionType: _selectedActionType,
        adminId: _selectedAdminId,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );

      setState(() {
        _logs.addAll(newLogs);
        _offset += newLogs.length;
        if (newLogs.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando logs: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final primaryColor = AppTheme.lGoldAction;
    final cardColor = Theme.of(context).cardTheme.color;
    final textColor = Theme.of(context).textTheme.displayLarge?.color;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: cardColor ?? Colors.white,
              onSurface: textColor ?? Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadLogs(refresh: true);
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('DELETE')) return Colors.red.shade400;
    if (action.contains('INSERT') || action.contains('CREATE'))
      return Colors.green.shade400;
    if (action.contains('UPDATE')) return Colors.orange.shade400;
    if (action.contains('ACCEPTED')) return Colors.blue.shade400;
    return Colors.grey.shade400;
  }

  Widget _buildActionDropDown() {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    return DropdownButtonFormField<String>(
      value: _selectedActionType,
      dropdownColor: Theme.of(context).cardTheme.color,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Acción',
        labelStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.6)),
        filled: true,
        fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.lGoldAction, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('Todas', style: TextStyle(color: textColor))),
        ..._actionTypes.map((type) => DropdownMenuItem(
              value: type,
              child: Text(type, style: TextStyle(color: textColor)),
            )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedActionType = value;
        });
        _loadLogs(refresh: true);
      },
    );
  }

  Widget _buildAdminDropDown() {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    return DropdownButtonFormField<String>(
      value: _selectedAdminId,
      dropdownColor: Theme.of(context).cardTheme.color,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Admin',
        labelStyle: TextStyle(color: secondaryTextColor?.withOpacity(0.6)),
        filled: true,
        fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.lGoldAction, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(color: textColor))),
        ..._admins.map((p) => DropdownMenuItem(
              value: p.userId,
              child: Text(p.name.isNotEmpty ? p.name : p.email, style: TextStyle(color: textColor)),
            )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedAdminId = value;
        });
        _loadLogs(refresh: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.displayLarge?.color;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final primaryColor = AppTheme.lGoldAction;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Auditoría', 
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: () => _loadLogs(refresh: true),
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color?.withOpacity(0.5),
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
              ),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 550) {
                        return Column(
                          children: [
                            _buildActionDropDown(),
                            const SizedBox(height: 12),
                            _buildAdminDropDown(),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: _buildActionDropDown()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildAdminDropDown()),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.date_range, size: 18, color: primaryColor),
                              label: Text(
                                _selectedDateRange == null
                                    ? 'Cualquier Fecha'
                                    : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                                style: TextStyle(fontSize: 13, color: textColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: _selectDateRange,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textColor,
                                side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                                backgroundColor: Theme.of(context).dividerColor.withOpacity(0.02),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                      if (_selectedDateRange != null)
                        IconButton(
                          icon: Icon(Icons.clear, size: 20, color: Theme.of(context).colorScheme.error),
                          onPressed: () {
                            setState(() {
                              _selectedDateRange = null;
                            });
                            _loadLogs(refresh: true);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: _logs.isEmpty && _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : _logs.isEmpty
                      ? Center(child: Text('No se encontraron logs', style: TextStyle(color: textColor?.withOpacity(0.5))))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _logs.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _logs.length) {
                              return Center(child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
                              ));
                            }

                            final log = _logs[index];
                            final cardColor = Theme.of(context).cardTheme.color;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 1,
                              color: cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05)),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getActionColor(log.actionType).withOpacity(0.15),
                                    child: Icon(
                                      _getIconForAction(log.actionType),
                                      color: _getActionColor(log.actionType),
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(log.actionType,
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(
                                    'Por: ${log.adminEmail ?? log.adminId ?? 'Sistema'} \nTabla: ${log.targetTable}',
                                    style: TextStyle(fontSize: 12, color: secondaryTextColor?.withOpacity(0.6)),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatDate(log.createdAt),
                                        style: TextStyle(fontSize: 10, color: secondaryTextColor?.withOpacity(0.4)),
                                      ),
                                      Icon(Icons.expand_more, size: 16, color: primaryColor.withOpacity(0.5)),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).dividerColor.withOpacity(0.03),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: SelectableText(
                                          _prettyPrintJson(log.details),
                                          style: TextStyle(
                                              fontFamily: 'monospace', 
                                              fontSize: 11,
                                              color: textColor?.withOpacity(0.8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForAction(String action) {
    if (action.contains('DELETE')) return Icons.delete;
    if (action.contains('INSERT') || action.contains('CREATE'))
      return Icons.add_circle;
    if (action.contains('UPDATE')) return Icons.edit;
    if (action.contains('ACCEPTED')) return Icons.check_circle;
    return Icons.info;
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM HH:mm').format(date);
  }

  String _prettyPrintJson(Map<String, dynamic> json) {
    var encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}
