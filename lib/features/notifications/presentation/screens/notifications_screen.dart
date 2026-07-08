import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/notifications_repository.dart';
import '../../domain/models/notification_model.dart';
import '../providers/notifications_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markingAll = false;

  Future<void> _markAllAsRead() async {
    setState(() => _markingAll = true);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .markAllAsRead();
      if (!mounted) return;
      ref.invalidate(notificationsProvider);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not mark all as read. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  /// Tapping a notification marks it read (fail-open) then navigates.
  /// markAsRead failure is silently swallowed — the agent must not be
  /// blocked from reaching the lead by a non-critical read-status update.
  void _onTap(NotificationModel n) {
    if (!n.isRead) {
      ref
          .read(notificationsRepositoryProvider)
          .markAsRead(n.id)
          .then((_) => ref.invalidate(notificationsProvider))
          .catchError((_) {});
    }
    if (n.relatedLeadId != null) {
      context.push('/leads/${n.relatedLeadId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncNotifications = ref.watch(notificationsProvider);
    final hasUnread = ref.watch(unreadCountProvider) > 0;
    final bottomPad = MediaQuery.of(context).padding.bottom + 80;

    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Blue header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  Text(
                    'Notifications',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  // Mark all as read
                  SizedBox(
                    height: 38,
                    child: _markingAll
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : TextButton(
                            onPressed:
                                hasUnread ? _markAllAsRead : null,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              disabledForegroundColor:
                                  Colors.white.withValues(alpha: 0.35),
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: const Text('Mark all read'),
                          ),
                  ),
                ],
              ),
            ),

            // ── White card ───────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg)),
                ),
                child: asyncNotifications.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryLight),
                  ),
                  error: (err, _) => _ErrorState(
                    message: err is PostgrestException
                        ? err.message
                        : err
                            .toString()
                            .replaceFirst('Exception: ', ''),
                    onRetry: () =>
                        ref.invalidate(notificationsProvider),
                  ),
                  data: (notifications) {
                    if (notifications.isEmpty) {
                      return const Center(
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      color: AppColors.primaryLight,
                      onRefresh: () async =>
                          ref.invalidate(notificationsProvider),
                      child: ListView.separated(
                        padding: EdgeInsets.only(bottom: bottomPad),
                        itemCount: notifications.length,
                        separatorBuilder: (context, index) =>
                            const Divider(
                                height: 1,
                                color: AppColors.dividerLight),
                        itemBuilder: (ctx, i) => _NotificationCard(
                          notification: notifications[i],
                          onTap: () => _onTap(notifications[i]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification card ──────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig(notification.type);
    final read = notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cfg.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(cfg.icon, color: cfg.fg, size: 20),
            ),

            const SizedBox(width: AppSpacing.md),

            // Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: read
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: read
                                ? AppColors.textSecondaryLight
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _relativeTime(notification.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textDisabledLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: read
                          ? AppColors.textDisabledLight
                          : AppColors.textSecondaryLight,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Type badge
                  _TypeBadge(cfg: cfg),
                ],
              ),
            ),

            // Unread dot
            if (!read)
              Padding(
                padding: const EdgeInsets.only(
                    left: AppSpacing.sm, top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Type badge ─────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final _TypeCfg cfg;
  const _TypeBadge({required this.cfg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        cfg.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: cfg.fg,
        ),
      ),
    );
  }
}

// ── Type configuration ─────────────────────────────────────────────────────────

class _TypeCfg {
  final IconData icon;
  final Color bg;
  final Color fg;
  final String label;
  const _TypeCfg(this.icon, this.bg, this.fg, this.label);
}

_TypeCfg _typeConfig(String type) => switch (type) {
      'new_hot_lead' => _TypeCfg(
          Icons.local_fire_department_rounded,
          const Color(0xFFFFEDD5),
          const Color(0xFFC2410C),
          'Hot Lead',
        ),
      'follow_up_due' => _TypeCfg(
          Icons.event_rounded,
          AppColors.primaryTintLight,
          AppColors.primaryLight,
          'Follow-up Due',
        ),
      'overdue' => _TypeCfg(
          Icons.warning_amber_rounded,
          AppColors.warningBgLight,
          AppColors.warningTextLight,
          'Overdue',
        ),
      'weekly_insight' => _TypeCfg(
          Icons.insights_rounded,
          const Color(0xFFF3E8FF),
          const Color(0xFF7C3AED),
          'Insight',
        ),
      _ => _TypeCfg( // system_update + unknown
          Icons.info_outline_rounded,
          AppColors.surfaceAltLight,
          AppColors.textSecondaryLight,
          'System',
        ),
    };

// ── Helpers ────────────────────────────────────────────────────────────────────

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final local = dt.toLocal();
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${local.day} ${months[local.month]}';
}

// ── Error state ────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.dangerTextLight, size: 48),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Could not load notifications.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
