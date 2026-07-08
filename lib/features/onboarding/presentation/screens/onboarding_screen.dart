import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/profile_state_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _agencyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _agencyController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'name': _nameController.text.trim(),
        'agency_name': _agencyController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        if (_cityController.text.trim().isNotEmpty)
          'city': _cityController.text.trim(),
        if (user.email != null) 'email': user.email,
      });

      // Invalidate so the router sees the profile now exists.
      ref.invalidate(profileExistsProvider);

      if (mounted) context.go('/dashboard');
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // ── Blue header ────────────────────────────────────────────────
            SizedBox(
              height: size.height * 0.26,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'PROPEX',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Set up your profile to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── White form card ────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'This information appears on your leads and follow-ups.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondaryLight,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        AppTextField(
                          label: 'Full Name',
                          hint: 'e.g. Ali Khan',
                          controller: _nameController,
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
                          controller: _agencyController,
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
                          controller: _phoneController,
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
                          controller: _cityController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          optional: true,
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.dangerBgLight,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
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
                          label: 'Get Started',
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
    );
  }
}
