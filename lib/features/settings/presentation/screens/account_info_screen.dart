import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/data/profile_repository.dart';
import '../../../auth/domain/models/profile_model.dart';
import '../../../auth/presentation/providers/profile_state_provider.dart';

class AccountInfoScreen extends ConsumerStatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  ConsumerState<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends ConsumerState<AccountInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _agencyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // Read-once from the provider - never re-read so the form isn't disrupted
  // if profileDataProvider re-fetches in the background.
  ProfileModel? _original;

  bool _loading = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_original == null) {
      final profile = ref.read(profileDataProvider).valueOrNull;
      if (profile != null) {
        _original = profile;
        _nameCtrl.text = profile.name;
        _agencyCtrl.text = profile.agencyName;
        _phoneCtrl.text = profile.phoneNumber ?? '';
        _cityCtrl.text = profile.city ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _agencyCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final o = _original;
    if (o == null) return false;
    return _nameCtrl.text.trim() != o.name ||
        _agencyCtrl.text.trim() != o.agencyName ||
        _phoneCtrl.text.trim() != (o.phoneNumber ?? '') ||
        _cityCtrl.text.trim() != (o.city ?? '');
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
        title: const Text(
          'Discard changes?',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight),
        ),
        content: const Text(
          'Your edits will not be saved.',
          style: TextStyle(
              fontSize: 14, color: AppColors.textSecondaryLight),
        ),
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
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final city = _cityCtrl.text.trim();

    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            name: _nameCtrl.text.trim(),
            agencyName: _agencyCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
            city: city.isEmpty ? null : city,
          );
      if (!mounted) return;
      ref.invalidate(profileDataProvider);
      context.pop();
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileDataProvider);

    // Pre-fill once data arrives if didChangeDependencies didn't catch it
    // (e.g. provider was still loading when the screen first built).
    ref.listen(profileDataProvider, (_, next) {
      if (_original == null) {
        final profile = next.valueOrNull;
        if (profile != null) {
          setState(() {
            _original = profile;
            _nameCtrl.text = profile.name;
            _agencyCtrl.text = profile.agencyName;
            _phoneCtrl.text = profile.phoneNumber ?? '';
            _cityCtrl.text = profile.city ?? '';
          });
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryLight,
        body: SafeArea(
          child: Column(
            children: [
              // ── Blue header ──────────────────────────────────────────
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
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Text(
                      'Account Info',
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

              // ── White form card ──────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg)),
                  ),
                  // Show form once _original is set, regardless of current
                  // provider state (avoids wiping the form on background refetch).
                  // Only fall back to loading/error if we never got initial data.
                  child: _original != null
                      ? _Form(
                          formKey: _formKey,
                          nameCtrl: _nameCtrl,
                          agencyCtrl: _agencyCtrl,
                          phoneCtrl: _phoneCtrl,
                          cityCtrl: _cityCtrl,
                          errorMessage: _errorMessage,
                          loading: _loading,
                          onSubmit: _submit,
                        )
                      : profileAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primaryLight),
                          ),
                          error: (err, _) => Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.dangerTextLight,
                                      size: 48),
                                  const SizedBox(height: AppSpacing.md),
                                  const Text(
                                    'Could not load your profile.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    err.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  TextButton(
                                    onPressed: () => ref.invalidate(
                                        profileDataProvider),
                                    child: const Text('Retry',
                                        style: TextStyle(
                                            color: AppColors.primaryLight,
                                            fontWeight:
                                                FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          data: (_) => const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primaryLight),
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

// ── Form body (extracted so build() stays readable) ───────────────────────────

class _Form extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController agencyCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController cityCtrl;
  final String? errorMessage;
  final bool loading;
  final VoidCallback onSubmit;

  const _Form({
    required this.formKey,
    required this.nameCtrl,
    required this.agencyCtrl,
    required this.phoneCtrl,
    required this.cityCtrl,
    required this.errorMessage,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Full Name',
              hint: 'e.g. Ali Khan',
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Full name is required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              label: 'Agency Name',
              hint: 'e.g. Pak Properties',
              controller: agencyCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Agency name is required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              label: 'Phone Number',
              hint: 'e.g. 03001234567',
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Phone number is required';
                }
                if (v.trim().length < 10) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              label: 'City',
              hint: 'e.g. Lahore',
              controller: cityCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              optional: true,
            ),

            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerBgLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.dangerTextLight,
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            PrimaryButton(
              label: 'Save Changes',
              onPressed: loading ? null : onSubmit,
              loading: loading,
            ),
          ],
        ),
      ),
    );
  }
}
