import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/sponsor.dart';
import '../services/sponsor_service.dart';
import 'sponsor_detail_screen.dart';

class SponsorsManagementScreen extends StatefulWidget {
  const SponsorsManagementScreen({super.key});

  @override
  State<SponsorsManagementScreen> createState() =>
      _SponsorsManagementScreenState();
}

class _SponsorsManagementScreenState extends State<SponsorsManagementScreen> {
  final SponsorService _sponsorService = SponsorService();
  bool _isLoading = true;
  List<Sponsor> _sponsors = [];

  @override
  void initState() {
    super.initState();
    _loadSponsors();
  }

  Future<void> _loadSponsors() async {
    setState(() => _isLoading = true);
    try {
      final sponsors = await _sponsorService.getSponsors();
      setState(() {
        _sponsors = sponsors;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar patrocinadores: $e')),
        );
      }
    }
  }

  Future<void> _deleteSponsor(Sponsor sponsor) async {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text('Eliminar Patrocinador',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Estás seguro de que deseas eliminar a "${sponsor.name}"?\n\nEsta acción no se puede deshacer.',
          style: TextStyle(color: textColor?.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: textColor?.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _sponsorService.deleteSponsor(sponsor.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Patrocinador eliminado correctamente')),
          );
          _loadSponsors();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SponsorDetailScreen(),
            ),
          );
          _loadSponsors();
        },
        backgroundColor: AppTheme.lGoldAction,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Nuevo Patrocinador",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Expanded(
                    child: Text(
                      "Gestionar Patrocinadores",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.lGoldAction),
                    onPressed: _isLoading ? null : _loadSponsors,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.lGoldAction))
                  : _sponsors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business_center_outlined,
                                  size: 64,
                                  color: textColor?.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text(
                                "No hay patrocinadores registrados",
                                style: TextStyle(
                                    color: textColor?.withOpacity(0.5), fontSize: 18),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: _sponsors.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final sponsor = _sponsors[index];
                            return _buildSponsorCard(sponsor);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSponsorCard(Sponsor sponsor) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardTheme.color;

    Color planColor;
    switch (sponsor.planType.toLowerCase()) {
      case 'oro':
        planColor = const Color(0xFFFFD700);
        break;
      case 'plata':
        planColor = const Color(0xFFC0C0C0);
        break;
      case 'bronce':
        planColor = const Color(0xFFCD7F32);
        break;
      default:
        planColor = Colors.grey;
    }

    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: sponsor.isActive
                ? AppTheme.lGoldAction.withOpacity(0.3)
                : Theme.of(context).dividerColor.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            image: sponsor.logoUrl != null
                ? DecorationImage(
                    image: NetworkImage(sponsor.logoUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: sponsor.logoUrl == null
              ? Icon(Icons.image_not_supported, color: textColor?.withOpacity(0.25))
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                sponsor.name,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            if (sponsor.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.lGoldAction.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.lGoldAction.withOpacity(0.3)),
                ),
                child: const Text("ACTIVO",
                    style: TextStyle(
                        color: AppTheme.lGoldText,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: planColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: planColor.withOpacity(0.5)),
                ),
                child: Text(
                  sponsor.planType.toUpperCase(),
                  style: TextStyle(
                      color: planColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.lGoldAction),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SponsorDetailScreen(sponsor: sponsor),
                  ),
                );
                _loadSponsors();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _deleteSponsor(sponsor),
            ),
          ],
        ),
      ),
    );
  }
}
