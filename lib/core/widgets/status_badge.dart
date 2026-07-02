import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../../features/leads/domain/models/lead_model.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final cfg = _config(status);
    final fontSize = small ? 10.0 : 11.0;
    final px = small ? 6.0 : AppSpacing.sm;
    final py = small ? 2.0 : 3.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        cfg.label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: cfg.fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _BadgeCfg {
  final String label;
  final Color bg;
  final Color fg;
  const _BadgeCfg(this.label, this.bg, this.fg);
}

_BadgeCfg _config(String status) => switch (status) {
      kStatusNew  => _BadgeCfg('New',  const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      kStatusHot  => _BadgeCfg('Hot',  const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
      kStatusWarm => _BadgeCfg('Warm', const Color(0xFFFEF9C3), const Color(0xFF92400E)),
      kStatusCold => _BadgeCfg('Cold', const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
      kStatusDone => _BadgeCfg('Done', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      _           => _BadgeCfg(status, const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };
