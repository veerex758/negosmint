import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.onSelect});
  final void Function(String action) onSelect;

  static const _items = [
    (label: 'Tasks', icon: Icons.task_alt_rounded),
    (label: 'Wallet', icon: Icons.account_balance_wallet_rounded),
    (label: 'Withdraw', icon: Icons.north_east_rounded),
    (label: 'Refer', icon: Icons.groups_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, i) {
        final item = _items[i];
        return GlassCard(
          padding: const EdgeInsets.all(10),
          borderRadius: 18,
          delay: Duration(milliseconds: 60 * i),
          onTap: () => onSelect(item.label),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: AppColors.highlight, size: 22),
              const SizedBox(height: 8),
              Text(
                item.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
