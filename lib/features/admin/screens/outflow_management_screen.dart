import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'withdrawal_requests_management_screen.dart';
import 'merchandise_redemptions_screen.dart';

class OutflowManagementScreen extends StatefulWidget {
  const OutflowManagementScreen({super.key});

  @override
  State<OutflowManagementScreen> createState() => _OutflowManagementScreenState();
}

class _OutflowManagementScreenState extends State<OutflowManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color goldColor = isDark ? AppTheme.dGoldMain : AppTheme.lGoldAction;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color?.withOpacity(0.5),
            border: Border(
              bottom: BorderSide(
                color: goldColor.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: goldColor,
            labelColor: goldColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(
                icon: Icon(Icons.redeem),
                text: 'Canjes Merch',
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const MerchandiseRedemptionsScreen(),
        ],
      ),
    );
  }
}
