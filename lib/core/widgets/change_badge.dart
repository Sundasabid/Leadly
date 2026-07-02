import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class ChangeBadge extends StatelessWidget {
  final double changePct;

  const ChangeBadge({super.key, required this.changePct});

  @override
  Widget build(BuildContext context) {
    final isUp = changePct >= 0;
    final abs = changePct.abs();
    final label = abs == abs.roundToDouble()
        ? '${abs.round()}%'
        : '${abs.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isUp ? AppColors.successBgLight : AppColors.dangerBgLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 11,
            color: isUp ? AppColors.successTextLight : AppColors.dangerTextLight,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isUp ? AppColors.successTextLight : AppColors.dangerTextLight,
            ),
          ),
        ],
      ),
    );
  }
}
