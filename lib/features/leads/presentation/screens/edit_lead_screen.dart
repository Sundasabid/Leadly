import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/leads_repository.dart';
import '../../domain/models/lead_model.dart';
import '../providers/leads_providers.dart';
import '../widgets/lead_form_fields.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class EditLeadScreen extends ConsumerStatefulWidget {
  final LeadModel lead;
  const EditLeadScreen({super.key, required this.lead});

  @override
  ConsumerState<EditLeadScreen> createState() => _EditLeadScreenState();
}

class _EditLeadScreenState extends ConsumerState<EditLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _notesCtrl;

  late String? _propertyType;
  late String? _intent;
  late String? _timeline;

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final l = widget.lead;
    _nameCtrl    = TextEditingController(text: l.name);
    _phoneCtrl   = TextEditingController(text: l.phone);
    _budgetCtrl  = TextEditingController(
        text: l.budgetPkr?.toInt().toString() ?? '');
    _areaCtrl    = TextEditingController(text: l.areaSociety);
    _notesCtrl   = TextEditingController(text: l.notes ?? '');
    _propertyType = _capitalize(l.propertyType);
    _intent       = _capitalize(l.intent);
    _timeline     = _timelineDisplay(l.timeline);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _budgetCtrl.dispose();
    _areaCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final l = widget.lead;
    return _nameCtrl.text.trim() != l.name ||
        _phoneCtrl.text.trim() != l.phone ||
        _budgetCtrl.text.trim() != (l.budgetPkr?.toInt().toString() ?? '') ||
        _areaCtrl.text.trim() != l.areaSociety ||
        _notesCtrl.text.trim() != (l.notes ?? '') ||
        _propertyType != _capitalize(l.propertyType) ||
        _intent != _capitalize(l.intent) ||
        _timeline != _timelineDisplay(l.timeline);
  }

  Future<void> _handleBack() async {
    if (!_hasChanges) {
      if (mounted) context.pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Discard changes?',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight)),
        content: const Text('Your edits will not be saved.',
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondaryLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing',
                style: TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard',
                style: TextStyle(
                    color: AppColors.dangerTextLight,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) context.pop();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_intent == null) {
      setState(() =>
          _errorMessage = 'Please select an intent - Buy, Rent, or Invest');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final normalizedPhone = LeadFormFields.normalizePhone(_phoneCtrl.text);
    final budgetRaw = _budgetCtrl.text.trim();

    final input = LeadInput(
      name: _nameCtrl.text.trim(),
      phone: normalizedPhone,
      budgetPkr: budgetRaw.isEmpty ? null : double.tryParse(budgetRaw),
      areaSociety: _areaCtrl.text.trim(),
      propertyType: _propertyType!,
      intent: _intent!,
      timeline: _timeline!,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    final timelineChanged = _timeline != _timelineDisplay(widget.lead.timeline);
    final intentChanged = _intent != _capitalize(widget.lead.intent);

    try {
      await ref.read(leadsRepositoryProvider).updateLead(widget.lead.id, input);
      if (!mounted) return;
      ref.invalidate(leadDetailProvider(widget.lead.id));
      ref.invalidate(leadsAsyncProvider);
      ref.invalidate(dashboardStatsProvider);

      if (timelineChanged || intentChanged) {
        final schedule = await _showFollowUpPrompt(
            timelineChanged: timelineChanged, intentChanged: intentChanged);
        if (!mounted) return;
        context.pop(schedule == true);
      } else {
        context.pop(false);
      }
    } on PostgrestException catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<bool?> _showFollowUpPrompt({
    required bool timelineChanged,
    required bool intentChanged,
  }) {
    final String what;
    if (timelineChanged && intentChanged) {
      what = "timeline and intent";
    } else if (timelineChanged) {
      what = "timeline";
    } else {
      what = "intent";
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        contentPadding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
        actionsPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primaryTintLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_rounded,
                color: AppColors.primaryLight,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Schedule a follow-up?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "You changed this lead's $what. Do you want to schedule a new follow-up to match?",
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Schedule',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondaryLight),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryLight,
        body: SafeArea(
          child: Column(
            children: [
              // ── Blue header ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _handleBack,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Text(
                      'Edit Lead',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // ── White form card ────────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl, AppSpacing.xl,
                          AppSpacing.xl, AppSpacing.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LeadFormFields(
                            nameCtrl: _nameCtrl,
                            phoneCtrl: _phoneCtrl,
                            budgetCtrl: _budgetCtrl,
                            areaCtrl: _areaCtrl,
                            notesCtrl: _notesCtrl,
                            propertyType: _propertyType,
                            intent: _intent,
                            timeline: _timeline,
                            onPropertyTypeChanged: (v) =>
                                setState(() => _propertyType = v),
                            onIntentSelected: (v) =>
                                setState(() => _intent = v),
                            onTimelineChanged: (v) =>
                                setState(() => _timeline = v),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.dangerBgLight,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Text(_errorMessage!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.dangerTextLight)),
                            ),
                          ],

                          const SizedBox(height: AppSpacing.xl),

                          PrimaryButton(
                            label: 'Save Changes',
                            onPressed: _loading ? null : _submit,
                            loading: _loading,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers (edit-screen only - map DB values to dropdown display labels) ─────

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _timelineDisplay(String db) =>
    const {
      'immediate':      'Immediate',
      'within_1_month': 'Within 1 Month',
      '1_3_months':     '1–3 Months',
      '3_6_months':     '3–6 Months',
      '6_plus_months':  '6+ Months',
    }[db] ??
    db;
