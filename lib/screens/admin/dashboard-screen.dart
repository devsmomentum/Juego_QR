import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'event_creation_screen.dart';
import 'requests_management_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel de Administración"),
        backgroundColor: AppTheme.darkBg,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _AdminMenuCard(
              title: "Crear Competencia",
              icon: Icons.add_location_alt,
              color: AppTheme.primaryPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventCreationScreen()),
                );
              },
            ),
            const SizedBox(height: 15),
            _AdminMenuCard(
              title: "Gestionar Solicitudes",
              icon: Icons.assignment_ind,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RequestsManagementScreen()),
                );
              },
            ),
            const SizedBox(height: 15),
            _AdminMenuCard(
              title: "Gestionar Usuarios",
              icon: Icons.people,
              color: AppTheme.secondaryPink,
              onTap: () {
                // TODO: Navegar a gestión de usuarios
              },
            ),
            // Agrega más opciones aquí
          ],
        ),
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminMenuCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.cardBg,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
