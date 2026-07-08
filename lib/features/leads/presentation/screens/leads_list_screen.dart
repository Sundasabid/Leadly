import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/status_badge.dart';
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
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final current = ref.read(leadsFilterProvider);
      ref.read(leadsFilterProvider.notifier).state =
          value.trim().isEmpty
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0,
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
                    icon: Icon(
                      Icons.sort_rounded,
                      color: filter.sortOrder != LeadsSortOrder.newestFirst
                          ? AppColors.primaryLight
                          : AppColors.textSecondaryLight,
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
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, or area...',
                  hintStyle: const TextStyle(
                    color: AppColors.textDisabledLight,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textDisabledLight,
                    size: 20,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textDisabledLight,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceAltLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                        color: AppColors.primaryLight, width: 1.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Status tabs ──────────────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl),
                itemCount: _statusTabs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final tab = _statusTabs[i];
                  final active = filter.status == tab.value;
                  return GestureDetector(
                    onTap: () => _setStatus(tab.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primaryLight
                            : AppColors.surfaceAltLight,
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: active
                              ? AppColors.primaryLight
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : AppColors.textSecondaryLight,
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
                  onRetry: () =>
                      ref.invalidate(leadsAsyncProvider),
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
                        AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl,
                      ),
                      itemCount: leads.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) => _LeadCard(
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    lead.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(status: lead.status),
              ],
            ),

            const SizedBox(height: AppSpacing.xs),

            // Phone
            Text(
              lead.phone,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Property info row
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _Chip(label: _capitalize(lead.propertyType)),
                _Chip(label: _capitalize(lead.intent)),
                _Chip(label: lead.areaSociety),
                if (lead.budgetPkr != null)
                  _Chip(label: _formatBudget(lead.budgetPkr!)),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Timestamp
            Text(
              _relativeTime(lead.createdAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textDisabledLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondaryLight,
          fontWeight: FontWeight.w500,
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
          const Text(
            'Sort By',
            style: TextStyle(
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
            Icon(
              hasFilter
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              size: 56,
              color: AppColors.borderLight,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              hasFilter ? 'No leads match your search' : 'No leads yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasFilter
                  ? 'Try adjusting your search or filters.'
                  : 'Tap the + button in the nav bar to add your first lead.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textDisabledLight,
                height: 1.5,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: onClear,
                child: const Text(
                  'Clear filters',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
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
            const Text(
              'Could not load leads',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
