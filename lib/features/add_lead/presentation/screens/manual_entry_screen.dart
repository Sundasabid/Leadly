import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../leads/data/leads_repository.dart';
import '../../../leads/presentation/providers/leads_providers.dart';
import '../../../leads/presentation/widgets/lead_form_fields.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/pending_lead_provider.dart';

class ManualEntryScreen extends ConsumerStatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _propertyType;
  String? _intent;
  String? _timeline;

  bool _loading = false;
  String? _errorMessage;

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
      if (mounted) context.pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Discard this lead?',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight)),
        content: const Text('All entered information will be lost.',
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
      setState(() => _errorMessage =
          'Please select an intent - Buy, Rent, or Invest');
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
                      'New Lead',
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
