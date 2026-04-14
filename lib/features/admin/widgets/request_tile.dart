import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/models/game_request.dart';
import '../../game/providers/game_request_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../shared/models/player.dart';
import '../services/admin_service.dart';
import '../../../shared/widgets/coin_image.dart';
import '../../mall/models/power_item.dart';

class RequestTile extends StatefulWidget {
  final GameRequest request;
  final bool isReadOnly;
  final int? rank;
  final int? progress;
  final String? currentStatus;
  final VoidCallback? onBanToggled;
  final int? coins;
  final int? lives;
  final String? eventId;
  final VoidCallback? onStatsUpdated;

  const RequestTile({
    super.key,
    required this.request,
    this.isReadOnly = false,
    this.rank,
    this.progress,
    this.currentStatus,
    this.onBanToggled,
    this.coins,
    this.lives,
    this.eventId,
    this.onStatsUpdated,
  });

  @override
  State<RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<RequestTile> {
  bool _isApproving = false;
  bool _isAdjusting = false;
  bool _isGrantingPower = false;

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  void _toggleBan(BuildContext context, PlayerProvider provider, String userId,
      String eventId, bool isBanned) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
            isBanned ? "Desbanear de Competencia" : "Banear de Competencia",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: Text(
          isBanned
              ? "¿Permitir el acceso nuevamente a este usuario a esta competencia?"
              : "¿Estás seguro? El usuario será expulsado de esta competencia.",
          style: TextStyle(color: textColor?.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: textColor?.withOpacity(0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isBanned ? Colors.green : Colors.red,
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.toggleGameBanUser(userId, eventId, !isBanned);
                if (widget.onBanToggled != null) {
                  widget.onBanToggled!();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(isBanned
                            ? "Usuario desbaneado de competencia"
                            : "Usuario baneado de competencia")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: Text(isBanned ? "DESBANEAR" : "BANEAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(BuildContext context) async {
    if (_isApproving) return;
    setState(() => _isApproving = true);

    try {
      final provider = Provider.of<GameRequestProvider>(context, listen: false);
      final result = await provider.approveRequest(widget.request.id);

      if (!mounted) return;

      final success = result['success'] == true;
      if (success) {
        final paid = result['paid'] == true;
        final amount = result['amount'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(paid
                    ? '✅ Aprobado y cobrado: $amount '
                    : '✅ Aprobado (evento gratuito)'),
                if (paid) const CoinImage(size: 16),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = result['error'] ?? 'UNKNOWN';
        String message;
        switch (error) {
          case 'PAYMENT_FAILED':
            final paymentError = result['payment_error'] ?? '';
            message = paymentError == 'INSUFFICIENT_CLOVERS'
                ? '❌ Saldo insuficiente del usuario'
                : '❌ Error en el pago: $paymentError';
            break;
          case 'REQUEST_NOT_PENDING':
            message =
                '⚠️ La solicitud ya no está pendiente (${result['current_status']})';
            break;
          case 'REQUEST_NOT_FOUND':
            message = '⚠️ Solicitud no encontrada';
            break;
          default:
            message = '❌ Error: $error';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al aprobar: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  void _showAdjustDialog(BuildContext context, String field, int currentValue) {
    final label = field == 'coins' ? 'Monedas' : 'Vidas';
    final customIcon = field == 'coins'
        ? const Icon(Icons.monetization_on, size: 22, color: Colors.amber)
        : null;
    final icon = field == 'coins' ? null : Icons.favorite;
    final color = field == 'coins' ? const Color(0xFFD4AF37) : Colors.redAccent;
    final controller = TextEditingController(text: currentValue.toString());
    final maxValue = field == 'lives' ? 3 : 99999;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    showDialog(
      context: context,
      builder: (ctx) {
        int tempValue = currentValue;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cardColor,
              title: Row(
                children: [
                  if (customIcon != null)
                    customIcon
                  else
                    Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Text('Ajustar $label',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.request.playerName ?? 'Jugador',
                    style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle,
                            color: Colors.redAccent, size: 32),
                        onPressed: tempValue > 0
                            ? () {
                                setDialogState(() {
                                  tempValue--;
                                  controller.text = tempValue.toString();
                                });
                              }
                            : null,
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: color,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: color.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: color.withOpacity(0.3)),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed != null) {
                              setDialogState(
                                  () => tempValue = parsed.clamp(0, maxValue));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: Colors.greenAccent, size: 32),
                        onPressed: tempValue < maxValue
                            ? () {
                                setDialogState(() {
                                  tempValue++;
                                  controller.text = tempValue.toString();
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                  if (field == 'lives')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Máximo: 3 vidas',
                          style:
                              TextStyle(color: textColor?.withOpacity(0.4), fontSize: 11)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar', style: TextStyle(color: textColor?.withOpacity(0.6))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final finalValue =
                        int.tryParse(controller.text) ?? tempValue;
                    await _applyStatChange(
                        field, finalValue.clamp(0, maxValue));
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _applyStatChange(String field, int newValue) async {
    if (_isAdjusting || widget.eventId == null) return;
    setState(() => _isAdjusting = true);
    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      await adminService.setPlayerStat(
        userId: widget.request.playerId,
        eventId: widget.eventId!,
        field: field,
        value: newValue,
      );
      if (mounted) {
        final label = field == 'coins' ? 'Monedas' : 'Vidas';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $label actualizado a $newValue'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onStatsUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdjusting = false);
    }
  }

  void _showPowerSelectionDialog(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (ctx) {
        final powers = PowerItem.getShopItems().where((p) {
          const excludedIds = {
            'life_steal',
            'extra_life',
            'invisibility',
            'return',
            'shield'
          };
          return !excludedIds.contains(p.id);
        }).toList();

        return AlertDialog(
          backgroundColor: cardColor,
          title: Row(
            children: [
              Icon(Icons.bolt, color: primaryColor, size: 22),
              const SizedBox(width: 8),
              Text('Afectar Jugador', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: powers.length,
              itemBuilder: (context, index) {
                final power = powers[index];
                return ListTile(
                  leading:
                      Text(power.icon, style: const TextStyle(fontSize: 24)),
                  title: Text(power.name,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  subtitle: Text(power.description,
                      style:
                          TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12)),
                  trailing:
                      Icon(Icons.flash_on, color: primaryColor, size: 18),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _applyPower(power);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: textColor?.withOpacity(0.6))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyPower(PowerItem power) async {
    if (_isGrantingPower || widget.eventId == null) return;
    setState(() => _isGrantingPower = true);
    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      await adminService.adminApplyPowerToPlayer(
        userId: widget.request.playerId,
        eventId: widget.eventId!,
        powerSlug: power.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('⚡ ${power.name} aplicado a ${widget.request.playerName}'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGrantingPower = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;
    final primaryColor = Theme.of(context).primaryColor;

    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, _) {
        final bool isBanned;

        if (widget.currentStatus != null) {
          isBanned = widget.currentStatus == 'banned' ||
              widget.currentStatus == 'suspended';
        } else {
          final globalStatus = playerProvider.allPlayers
              .firstWhere((p) => p.id == widget.request.playerId,
                  orElse: () => Player(
                      userId: '',
                      email: '',
                      name: '',
                      role: '',
                      status: PlayerStatus.active))
              .status;
          isBanned = globalStatus == PlayerStatus.banned;
        }

        return Card(
          color: isBanned ? Colors.red.withOpacity(0.05) : cardColor,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isBanned ? Colors.red.withOpacity(0.2) : Theme.of(context).dividerColor.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: (widget.isReadOnly && widget.rank != null)
                      ? CircleAvatar(
                          backgroundColor: _getRankColor(widget.rank!),
                          foregroundColor: Colors.white,
                          child: Text("#${widget.rank}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        )
                      : null,
                  title: Text(widget.request.playerName ?? 'Desconocido',
                      style: TextStyle(
                        color: isBanned ? Colors.redAccent : textColor,
                        decoration:
                            isBanned ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.bold,
                      )),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.request.playerEmail ?? 'No email',
                          style: TextStyle(color: textColor?.withOpacity(0.5))),
                      if (widget.request.createdAt != null)
                        Text(
                          'Solicitud: ${_formatDate(widget.request.createdAt!)}',
                          style: TextStyle(
                              color: textColor?.withOpacity(0.35), fontSize: 11),
                        ),
                      if (widget.isReadOnly && widget.progress != null)
                        Text("Pistas completadas: ${widget.progress}",
                            style: const TextStyle(
                                color: AppTheme.lGoldAction, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isReadOnly) ...[
                        if (isBanned)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                            ),
                            child: const Text("SUSPENDIDO",
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          )
                        else
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),

                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(isBanned ? Icons.lock_open_rounded : Icons.block_rounded, size: 20),
                          color: isBanned ? Colors.green : Colors.red,
                          tooltip: isBanned ? "Desbanear" : "Banear",
                          onPressed: () => _toggleBan(
                              context,
                              playerProvider,
                              widget.request.playerId,
                              widget.request.eventId,
                              isBanned),
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                          onPressed: _isApproving
                              ? null
                              : () => Provider.of<GameRequestProvider>(context,
                                      listen: false)
                                  .rejectRequest(widget.request.id),
                        ),
                        if (_isApproving)
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.lGoldAction))
                        else
                          IconButton(
                            icon: const Icon(Icons.check_rounded, color: Colors.green, size: 20),
                            onPressed: () => _handleApprove(context),
                          ),
                      ],
                    ],
                  ),
                ),
                if (widget.isReadOnly &&
                    (widget.coins != null || widget.lives != null))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (widget.rank != null)
                          const SizedBox(width: 32),
                        if (widget.coins != null)
                          _StatChip(
                            customIcon: const Icon(Icons.monetization_on,
                                size: 14, color: AppTheme.lGoldAction),
                            value: widget.coins!,
                            color: AppTheme.lGoldAction,
                            label: 'Monedas',
                            onTap: widget.eventId != null && !_isAdjusting
                                ? () => _showAdjustDialog(
                                    context, 'coins', widget.coins!)
                                : null,
                          ),
                        if (widget.lives != null)
                          _StatChip(
                            icon: Icons.favorite,
                            value: widget.lives!,
                            color: Colors.redAccent,
                            label: 'Vidas',
                            onTap: widget.eventId != null && !_isAdjusting
                                ? () => _showAdjustDialog(
                                    context, 'lives', widget.lives!)
                                : null,
                          ),
                        _StatChip(
                          icon: Icons.bolt_rounded,
                          value: 0,
                          showValue: false,
                          color: AppTheme.lGoldAction,
                          label: 'Lanzar Poder',
                          onTap: widget.eventId != null && !_isGrantingPower
                              ? () => _showPowerSelectionDialog(context)
                              : null,
                        ),
                        if (_isAdjusting || _isGrantingPower)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.lGoldAction),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Theme.of(context).primaryColor;
  }
}

class _StatChip extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final int value;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final bool showValue;

  const _StatChip({
    this.icon,
    this.customIcon,
    required this.value,
    required this.color,
    required this.label,
    this.onTap,
    this.showValue = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (customIcon != null)
              customIcon!
            else
              Icon(icon, size: 14, color: color),
            if (showValue) ...[
              const SizedBox(width: 4),
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ] else ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 11, color: color.withOpacity(0.5)),
            ],
          ],
        ),
      ),
    );
  }
}
