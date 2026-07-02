import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../leads/data/leads_repository.dart';
import '../../../leads/presentation/providers/leads_providers.dart';
import '../../../leads/presentation/widgets/lead_form_fields.dart';
import '../providers/pending_lead_provider.dart';

class ReviewExtractedLeadScreen extends ConsumerStatefulWidget {
  const ReviewExtractedLeadScreen({super.key});

  @override
  ConsumerState<ReviewExtractedLeadScreen> createState() =>
      _ReviewExtractedLeadScreenState();
}

class _ReviewExtractedLeadScreenState
    extends ConsumerState<ReviewExtractedLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _propertyType;
  String? _intent;
  String? _timeline;
  double _confidence = 0.0;

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final json = ref.read(pendingExtractedLeadProvider);
    if (json == null) return;

    _nameCtrl.text = (json['name'] as String?) ?? '';
    final rawPhone = (json['phone'] as String?) ?? '';
    if (rawPhone.isNotEmpty) {
      _phoneCtrl.text = LeadFormFields.cleanPhone(rawPhone);
    }
    final budget = json['budget_pkr'];
    _budgetCtrl.text =
        budget != null ? (budget as num).round().toString() : '';
    _areaCtrl.text = (json['area_society'] as String?) ?? '';
    _notesCtrl.text = (json['notes'] as String?) ?? '';
    _propertyType =
        LeadInput.propertyTypeFromDb(json['property_type'] as String?);
    _intent = LeadInput.intentFromDb(json['intent'] as String?);
    _timeline = LeadInput.timelineFromDb(json['timeline'] as String?);
    _confidence = (json['confidence'] as num).toDouble();
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

  bool get _hasContent =>
      _nameCtrl.text.isNotEmpty ||
      _phoneCtrl.text.isNotEmpty ||
      _budgetCtrl.text.isNotEmpty ||
      _areaCtrl.text.isNotEmpty ||
      _notesCtrl.text.isNotEmpty ||
      _propertyType != null ||
      _intent != null ||
      _timeline != null;

  Future<void> _handleBack() async {
    if (!_hasContent) {
      ref.read(pendingExtractedLeadProvider.notifier).state = null;
      if (mounted) context.pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text(
          'Discard this lead?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
        content: const Text(
          'All entered information will be lost.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Keep Editing',
              style: TextStyle(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Discard',
              style: TextStyle(
                color: AppColors.dangerTextLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      ref.read(pendingExtractedLeadProvider.notifier).state = null;
      context.pop();
    }
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

    // Build ONE input with voice tracking — used in both duplicate and clean branches.
    final input = LeadInput(
      name: _nameCtrl.text.trim(),
      phone: normalizedPhone,
      budgetPkr: budgetRaw.isEmpty ? null : double.tryParse(budgetRaw),
      areaSociety: _areaCtrl.text.trim(),
      propertyType: _propertyType!,
      intent: _intent!,
      timeline: _timeline!,
      notes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      source: 'voice',
      extractionConfidence: _confidence,
    );

    try {
      final repo = ref.read(leadsRepositoryProvider);
      final duplicate = await repo.findDuplicateByPhone(normalizedPhone);

      if (!mounted) return;

      if (duplicate != null) {
        setState(() => _loading = false);
        ref.read(pendingLeadInputProvider.notifier).state = input;
        ref.read(pendingDuplicateProvider.notifier).state = duplicate;
        context.push('/add-lead/duplicate-warning');
      } else {
        await repo.createLead(input);
        if (!mounted) return;
        ref.read(pendingExtractedLeadProvider.notifier).state = null;
        ref.invalidate(leadsAsyncProvider);
        ref.invalidate(dashboardStatsProvider);
        context.go('/leads');
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
              // Blue header
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
                      'Review Lead',
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

              // White card
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
                          _ConfidenceBadge(confidence: _confidence),
                          const SizedBox(height: AppSpacing.xl),

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
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.dangerTextLight,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: AppSpacing.xl),

                          PrimaryButton(
                            label: 'Save Lead',
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

// ── Confidence badge ───────────────────────────────────────────────────────────

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();

    final Color bgColor;
    final Color textColor;
    final String label;

    if (confidence >= 0.8) {
      bgColor = AppColors.successBgLight;
      textColor = AppColors.successTextLight;
      label = 'High confidence';
    } else if (confidence >= 0.5) {
      bgColor = AppColors.warningBgLight;
      textColor = AppColors.warningTextLight;
      label = 'Medium confidence - verify the details below';
    } else {
      bgColor = AppColors.dangerBgLight;
      textColor = AppColors.dangerTextLight;
      label = 'Low confidence - check all fields carefully';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor: textColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
