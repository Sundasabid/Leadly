import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/leads_repository.dart';
import '../../domain/models/lead_model.dart';
import '../providers/leads_providers.dart';

class LeadsListScreen extends ConsumerStatefulWidget {
  const LeadsListScreen({super.key});

  @override
  ConsumerState<LeadsListScreen> createState() => _LeadsListScreenState();
}

class _LeadsListScreenState extends ConsumerState<LeadsListScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  static const _statusTabs = [
    (label: 'All', value: null),
    (label: 'New', value: kStatusNew),
    (label: 'Hot', value: kStatusHot),
    (label: 'Warm', value: kStatusWarm),
    (label: 'Cold', value: kStatusCold),
    (label: 'Done', value: kStatusDone),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {}); // refresh clear button immediately
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final current = ref.read(leadsFilterProvider);
      ref.read(leadsFilterProvider.notifier).state = value.trim().isEmpty
          ? current.copyWith(clearSearch: true)
          : current.copyWith(searchQuery: value.trim());
    });
  }

  void _setStatus(String? status) {
    final current = ref.read(leadsFilterProvider);
    ref.read(leadsFilterProvider.notifier).state = status == null
        ? current.copyWith(clearStatus: true)
        : current.copyWith(status: status);
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _SortSheet(
        current: ref.read(leadsFilterProvider).sortOrder,
        onSelected: (order) {
          ref.read(leadsFilterProvider.notifier).state =
              ref.read(leadsFilterProvider).copyWith(sortOrder: order);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(leadsFilterProvider);
    final leadsAsync = ref.watch(leadsAsyncProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.sm, 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Leads',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _showSortSheet,
                    icon: const Icon(
                      LucideIcons.slidersHorizontal,
                      color: AppColors.primaryLight,
                      size: 20,
                    ),
                    tooltip: 'Sort',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Search bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, or area...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              LucideIcons.x,
                              size: 16,
                              color: Color(0xFF9CA3AF),
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primaryLight,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Filter chips ─────────────────────────────────────────────
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                itemCount: _statusTabs.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final tab = _statusTabs[i];
                  final active = filter.status == tab.value;
                  return GestureDetector(
                    onTap: () => _setStatus(tab.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF1B3A8A)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: active
                            ? null
                            : Border.all(color: AppColors.borderLight),
                        boxShadow: active
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Center(
                        child: Text(
                          tab.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: active
                                ? Colors.white
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: leadsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryLight,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => _ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(leadsAsyncProvider),
                ),
                data: (leads) {
                  if (leads.isEmpty) {
                    return _EmptyState(
                      hasFilter: filter.hasActiveFilter,
                      onClear: () {
                        _searchCtrl.clear();
                        ref.read(leadsFilterProvider.notifier).state =
                            const LeadsFilter();
                      },
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primaryLight,
                    onRefresh: () async =>
                        ref.invalidate(leadsAsyncProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        16, 0, 16, AppSpacing.xxl,
                      ),
                      itemCount: leads.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => _LeadCard(
                        lead: leads[i],
                        onTap: () =>
                            context.push('/leads/${leads[i].id}'),
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
}

// ── Lead card ──────────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  final LeadModel lead;
  final VoidCallback onTap;

  const _LeadCard({required this.lead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TOP ROW: avatar · name/phone · status badge ──────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B3A8A),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      lead.name.isNotEmpty
                          ? lead.name[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.phone,
                            size: 12,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              lead.phone,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF6B7280),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Status badge pill
                _statusBadge(lead.status),
              ],
            ),

            const SizedBox(height: 10),

            // ── MIDDLE ROW: colored property tag pills ───────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _TagPill(
                  label: _capitalize(lead.propertyType),
                  bg: const Color(0xFFEEF2FF),
                  fg: const Color(0xFF3730A3),
                ),
                _TagPill(
                  label: _capitalize(lead.intent),
                  bg: const Color(0xFFECFDF5),
                  fg: const Color(0xFF15803D),
                ),
                if (lead.areaSociety.isNotEmpty)
                  _TagPill(
                    label: lead.areaSociety,
                    bg: const Color(0xFFF5F3FF),
                    fg: const Color(0xFF7C3AED),
                  ),
                if (lead.budgetPkr != null)
                  _TagPill(
                    label: _formatBudget(lead.budgetPkr!),
                    bg: const Color(0xFFFFFBEB),
                    fg: const Color(0xFF92400E),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // ── BOTTOM ROW: timestamp · AI source pill ───────────────────
            Row(
              children: [
                const Icon(
                  LucideIcons.clock,
                  size: 12,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  _relativeTime(lead.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                const Spacer(),
                if (lead.source == 'voice')
                  Container(
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        '🎙 AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B3A8A),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tag pill ───────────────────────────────────────────────────────────────────

class _TagPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _TagPill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ── Sort bottom sheet ──────────────────────────────────────────────────────────

class _SortSheet extends StatelessWidget {
  final LeadsSortOrder current;
  final ValueChanged<LeadsSortOrder> onSelected;

  const _SortSheet({required this.current, required this.onSelected});

  static const _options = [
    (label: 'Newest First', order: LeadsSortOrder.newestFirst),
    (label: 'Oldest First', order: LeadsSortOrder.oldestFirst),
    (label: 'Budget: High to Low', order: LeadsSortOrder.byBudgetHighLow),
    (label: 'Name: A to Z', order: LeadsSortOrder.byNameAZ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sort By',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._options.map(
            (opt) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                opt.label,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimaryLight,
                  fontWeight: current == opt.order
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              trailing: current == opt.order
                  ? const Icon(Icons.check_rounded,
                      color: AppColors.primaryLight, size: 20)
                  : null,
              onTap: () => onSelected(opt.order),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onClear;

  const _EmptyState({required this.hasFilter, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primaryTintLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.userX,
                size: 36,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              hasFilter ? 'No leads found' : 'No leads yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasFilter
                  ? 'Try adjusting your search or filters.'
                  : 'Tap the + button in the nav bar to add your first lead.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
                height: 1.5,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(height: AppSpacing.xl),
              TextButton(
                onPressed: onClear,
                child: const Text(
                  'Clear filters',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.borderLight,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Could not load leads',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textDisabledLight,
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

// ── Helpers ────────────────────────────────────────────────────────────────────

Widget _statusBadge(String status) {
  return Container(
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: BoxDecoration(
      color: _statusBg(status),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Center(
      child: Text(
        _capitalize(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _statusFg(status),
        ),
      ),
    ),
  );
}

Color _statusBg(String s) => switch (s) {
      kStatusNew  => const Color(0xFFDBEAFE),
      kStatusHot  => const Color(0xFFFFEDD5),
      kStatusWarm => const Color(0xFFFEF9C3),
      kStatusCold => const Color(0xFFE0F2FE),
      kStatusDone => const Color(0xFFDCFCE7),
      _           => AppColors.surfaceAltLight,
    };

Color _statusFg(String s) => switch (s) {
      kStatusNew  => const Color(0xFF1D4ED8),
      kStatusHot  => const Color(0xFFC2410C),
      kStatusWarm => const Color(0xFF92400E),
      kStatusCold => const Color(0xFF0369A1),
      kStatusDone => const Color(0xFF15803D),
      _           => AppColors.textSecondaryLight,
    };

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _formatBudget(double v) {
  final n = v.toInt().toString();
  final buffer = StringBuffer('PKR ');
  final offset = n.length % 3;
  for (var i = 0; i < n.length; i++) {
    if (i != 0 && (i - offset) % 3 == 0) buffer.write(',');
    buffer.write(n[i]);
  }
  return buffer.toString();
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final local = dt.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
