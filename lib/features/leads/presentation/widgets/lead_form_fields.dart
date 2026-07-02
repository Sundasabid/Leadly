import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/models/lead_model.dart';

/// Shared form body used by both Add Lead (S07) and Edit Lead.
/// The parent screen owns all controllers and selection state;
/// this widget is purely presentational.
class LeadFormFields extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController budgetCtrl;
  final TextEditingController areaCtrl;
  final TextEditingController notesCtrl;

  final String? propertyType;
  final String? intent;
  final String? timeline;

  final ValueChanged<String?> onPropertyTypeChanged;
  final ValueChanged<String> onIntentSelected;
  final ValueChanged<String?> onTimelineChanged;

  const LeadFormFields({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.budgetCtrl,
    required this.areaCtrl,
    required this.notesCtrl,
    required this.propertyType,
    required this.intent,
    required this.timeline,
    required this.onPropertyTypeChanged,
    required this.onIntentSelected,
    required this.onTimelineChanged,
  });

  // ── Static utilities shared by parent screens ──────────────────────────────

  /// Strips all non-digit characters, preserving a leading '+'.
  /// Use before populating the phone field from any external source
  /// (voice extraction, contact picker) so the validator never sees separators.
  static String cleanPhone(String raw) {
    if (raw.isEmpty) return raw;
    final hasPlus = raw.trimLeft().startsWith('+');
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return hasPlus ? '+$digits' : digits;
  }

  static String? validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    final s = v.trim();
    String digits;
    if (s.startsWith('+92')) {
      digits = s.substring(3);
    } else if (s.startsWith('0')) {
      digits = s.substring(1);
    } else {
      return 'Enter a Pakistani number: 03XXXXXXXXXX or +923XXXXXXXXXX';
    }
    if (digits.length != 10) {
      return 'Must be exactly 10 digits after the prefix';
    }
    if (!digits.startsWith('3')) {
      return 'Mobile number must start with 3 after the prefix';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
      return 'Digits only - no spaces, dashes, or other characters';
    }
    return null;
  }

  /// Always returns +92XXXXXXXXXX regardless of input format.
  static String normalizePhone(String raw) {
    final s = raw.trim();
    if (s.startsWith('+92')) return s;
    return '+92${s.substring(1)}';
  }

  // ── Contact picker ─────────────────────────────────────────────────────────

  static Future<void> _pickContact(
    BuildContext context,
    TextEditingController phoneCtrl,
  ) async {
    // showPicker(properties: {phone}) requires READ_CONTACTS on Android.
    final status = await ph.Permission.contacts.request();

    if (!context.mounted) return;

    if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Contacts permission is blocked. Enable it in app settings.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: ph.openAppSettings,
          ),
        ),
      );
      return;
    }

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contacts permission is required to pick a number.',
          ),
        ),
      );
      return;
    }

    Contact? contact;
    try {
      contact = await FlutterContacts.native
          .showPicker(properties: {ContactProperty.phone});
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open contacts. Please try again.'),
          ),
        );
      }
      return;
    }

    if (!context.mounted || contact == null) return;

    final phones = contact.phones;

    if (phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${contact.displayName ?? "This contact"} has no phone number saved.',
          ),
        ),
      );
      return;
    }

    if (phones.length == 1) {
      final raw = phones.first.normalizedNumber ?? phones.first.number;
      phoneCtrl.text = cleanPhone(raw);
      return;
    }

    // Multiple numbers - let the agent choose.
    final picked = await showModalBottomSheet<Phone>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
              child: Text(
                contact!.displayName ?? 'Select a number',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ),
            ...phones.map(
              (p) => ListTile(
                leading: const Icon(Icons.phone_rounded,
                    color: AppColors.primaryLight, size: 20),
                title: Text(
                  p.number,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  _phoneLabelDisplay(p),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(p),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );

    if (picked == null || !context.mounted) return;
    final raw = picked.normalizedNumber ?? picked.number;
    phoneCtrl.text = cleanPhone(raw);
  }

  static String _phoneLabelDisplay(Phone phone) {
    if (phone.label.label == PhoneLabel.custom) {
      return phone.label.customLabel ?? 'Custom';
    }
    // Convert camelCase enum name to spaced words: "workMobile" -> "Work Mobile"
    return phone.label.label.name
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => ' ${m.group(0)}',
        )
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Full Name',
          hint: 'e.g. Ahmed Khan',
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        const SizedBox(height: AppSpacing.lg),

        AppTextField(
          label: 'Phone Number',
          hint: 'e.g. 03012345678 or +923012345678',
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          validator: validatePhone,
          suffixIcon: IconButton(
            icon: const Icon(
              Icons.contacts_rounded,
              size: 20,
              color: AppColors.primaryLight,
            ),
            tooltip: 'Pick from contacts',
            onPressed: () => _pickContact(context, phoneCtrl),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        AppTextField(
          label: 'Budget (PKR)',
          hint: 'e.g. 15000000',
          controller: budgetCtrl,
          keyboardType: TextInputType.number,
          optional: true,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final n = double.tryParse(v.trim());
            if (n == null) return 'Enter a valid number';
            if (n < 0) return 'Budget cannot be negative';
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        AppTextField(
          label: 'Area / Society',
          hint: 'e.g. DHA Phase 5, Bahria Town',
          controller: areaCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Area or society is required'
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),

        AppDropdownField<String>(
          label: 'Property Type',
          hint: 'Select type',
          value: propertyType,
          items: kPropertyTypes,
          itemLabel: (v) => v,
          onChanged: onPropertyTypeChanged,
          validator: (v) =>
              v == null ? 'Please select a property type' : null,
        ),
        const SizedBox(height: AppSpacing.lg),

        _IntentField(selected: intent, onSelect: onIntentSelected),
        const SizedBox(height: AppSpacing.lg),

        AppDropdownField<String>(
          label: 'Timeline',
          hint: 'When do they need it?',
          value: timeline,
          items: kTimelineOptions,
          itemLabel: (v) => v,
          onChanged: onTimelineChanged,
          validator: (v) => v == null ? 'Please select a timeline' : null,
        ),
        const SizedBox(height: AppSpacing.lg),

        _NotesField(controller: notesCtrl),
      ],
    );
  }
}

// ── Intent chip row ────────────────────────────────────────────────────────────

class _IntentField extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _IntentField({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Intent',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: kIntentOptions.asMap().entries.map((entry) {
            final isLast = entry.key == kIntentOptions.length - 1;
            final option = entry.value;
            final isSelected = option == selected;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: isLast ? 0 : AppSpacing.sm),
                child: GestureDetector(
                  onTap: () => onSelect(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.surfaceAltLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryLight
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Notes field with character counter ────────────────────────────────────────

class _NotesField extends StatefulWidget {
  final TextEditingController controller;
  const _NotesField({required this.controller});

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  static const int _maxChars = 500;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.controller.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Notes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimaryLight,
              ),
            ),
            Row(
              children: [
                const Text(
                  '  (optional)  ',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                Text(
                  '$count / $_maxChars',
                  style: TextStyle(
                    fontSize: 12,
                    color: count > _maxChars
                        ? AppColors.dangerTextLight
                        : AppColors.textDisabledLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: widget.controller,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          validator: (v) {
            if (v != null && v.length > _maxChars) {
              return 'Notes cannot exceed $_maxChars characters';
            }
            return null;
          },
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: 'Any additional details about this lead...',
            hintStyle: const TextStyle(
              color: AppColors.textDisabledLight,
              fontSize: 15,
            ),
            filled: true,
            fillColor: AppColors.surfaceAltLight,
            contentPadding: const EdgeInsets.all(AppSpacing.lg),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(
                  color: AppColors.primaryLight, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
                  const BorderSide(color: AppColors.dangerTextLight),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(
                  color: AppColors.dangerTextLight, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
