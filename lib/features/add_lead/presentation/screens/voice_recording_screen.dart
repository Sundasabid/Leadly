import 'dart:async';
import 'dart:convert' show base64Encode;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:record/record.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/voice_lead_repository.dart';
import '../providers/pending_lead_provider.dart';

enum _RecState { idle, permissionDenied, recording, processing, error }

class VoiceRecordingScreen extends ConsumerStatefulWidget {
  const VoiceRecordingScreen({super.key});

  @override
  ConsumerState<VoiceRecordingScreen> createState() =>
      _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends ConsumerState<VoiceRecordingScreen> {
  final _recorder = AudioRecorder();

  _RecState _state = _RecState.idle;
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _mimeType;
  String? _errorMessage;

  static const int _maxSeconds = 120;

  static const List<String> _checklist = [
    'Name',
    'Phone Number (digit-by-digit is most reliable, e.g. "zero three zero two...")',
    'Budget (e.g. 50 lakh, 2 crore)',
    'Area / Society',
    'Property Type (house, plot, flat)',
    'Intent (buy, rent, invest)',
    'Timeline',
    'Any additional notes',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String get _timerLabel {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _onMicTap() async {
    final granted = await _recorder.hasPermission();
    if (!granted) {
      setState(() => _state = _RecState.permissionDenied);
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    AudioEncoder encoder;
    String mimeType;

    if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
      encoder = AudioEncoder.aacLc;
      mimeType = 'audio/aac';
    } else if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
      encoder = AudioEncoder.opus;
      mimeType = 'audio/ogg';
    } else {
      encoder = AudioEncoder.aacLc;
      mimeType = 'audio/aac';
    }
    _mimeType = mimeType;

    final path =
        '${Directory.systemTemp.path}/leadly_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      RecordConfig(
        encoder: encoder,
        numChannels: 1,
        noiseSuppress: true,
        echoCancel: true,
      ),
      path: path,
    );

    setState(() {
      _state = _RecState.recording;
      _elapsedSeconds = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= _maxSeconds) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _timer = null;

    setState(() => _state = _RecState.processing);

    final path = await _recorder.stop();

    if (path == null) {
      if (!mounted) return;
      setState(() {
        _state = _RecState.error;
        _errorMessage =
            'Recording failed - no audio file was produced. Please try again.';
      });
      return;
    }

    try {
      final Uint8List bytes;
      if (kIsWeb) {
        throw const VoiceLeadException(
          'unsupported_platform',
          'Voice lead entry is not supported on web.',
        );
      } else {
        bytes = await File(path).readAsBytes();
      }

      final audioBase64 = base64Encode(bytes);
      final result = await ref.read(voiceLeadRepositoryProvider).extractLead(
            audioBase64: audioBase64,
            mimeType: _mimeType!,
          );

      if (!mounted) return;
      ref.read(pendingExtractedLeadProvider.notifier).state = result;
      _reset();
      context.push('/add-lead/review');
    } on VoiceLeadException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _RecState.error;
        _errorMessage = _messageFor(e.errorCode);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _RecState.error;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  String _messageFor(String code) => switch (code) {
        'rate_limited' =>
          'The AI service is busy right now. Wait a moment, then try again.',
        'invalid_audio' =>
          'The recording could not be processed. Please try again with a clear voice note.',
        'content_filtered' =>
          'The recording was flagged and could not be processed. Please try again.',
        'network_error' =>
          'Network error contacting the AI service. Check your connection and try again.',
        'extraction_failed' => 'Lead extraction failed. Please try again.',
        'parse_error' =>
          'Unexpected response from the AI service. Please try again.',
        'empty_response' =>
          'The AI returned an empty response. Please try again.',
        'bad_request' => 'Invalid request. Please try again.',
        'configuration_error' =>
          'Service is unavailable. Please contact support.',
        _ => 'Something went wrong. Please try again.',
      };

  void _reset() {
    setState(() {
      _state = _RecState.idle;
      _elapsedSeconds = 0;
      _errorMessage = null;
      _mimeType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: SafeArea(
        child: Column(
          children: [
            // Blue header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
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
                    'Voice Lead',
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
                    top: Radius.circular(AppRadius.lg),
                  ),
                ),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() => switch (_state) {
        _RecState.idle || _RecState.recording => _RecordingView(
            isRecording: _state == _RecState.recording,
            timerLabel: _timerLabel,
            checklist: _checklist,
            onMicTap:
                _state == _RecState.recording ? _stopRecording : _onMicTap,
          ),
        _RecState.permissionDenied => _PermissionDeniedView(
            onOpenSettings: () async {
              await ph.openAppSettings();
              if (mounted) _reset();
            },
          ),
        _RecState.processing => const _ProcessingView(),
        _RecState.error => _ErrorView(
            message:
                _errorMessage ?? 'Something went wrong. Please try again.',
            onRetry: _reset,
          ),
      };
}

// ── Recording view ────────────────────────────────────────────────────────────

class _RecordingView extends StatelessWidget {
  final bool isRecording;
  final String timerLabel;
  final List<String> checklist;
  final VoidCallback onMicTap;

  const _RecordingView({
    required this.isRecording,
    required this.timerLabel,
    required this.checklist,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tip box
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primaryTintLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.primaryLight.withValues(alpha: 0.25),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 18, color: AppColors.primaryLight),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Our AI will extract and organize details - speak naturally and clearly.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryLight,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          const Text(
            'Make sure to mention:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          ...checklist.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryTintLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 12, color: AppColors.primaryLight),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Timer
          Center(
            child: Text(
              timerLabel,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: isRecording
                    ? AppColors.textPrimaryLight
                    : AppColors.textDisabledLight,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              isRecording ? 'Tap to stop' : 'Tap the mic to start recording',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Mic / stop button
          Center(
            child: GestureDetector(
              onTap: onMicTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecording
                      ? const Color(0xFFDC2626)
                      : AppColors.primaryLight,
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording
                              ? const Color(0xFFDC2626)
                              : AppColors.primaryLight)
                          .withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          const Center(
            child: Text(
              'Maximum 2 minutes',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textDisabledLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Permission denied view ────────────────────────────────────────────────────

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _PermissionDeniedView({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.dangerBgLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                const Icon(Icons.mic_off_rounded,
                    size: 44, color: AppColors.dangerTextLight),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Microphone access required',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Propex needs microphone permission to record voice notes. Please enable it in your device settings.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onOpenSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Open App Settings',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
}

// ── Processing view ───────────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  const _ProcessingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryLight,
            strokeWidth: 3,
          ),
          SizedBox(height: AppSpacing.xl),
          Text(
            'Extracting lead details...',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.dangerBgLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 44, color: AppColors.dangerTextLight),
                const SizedBox(height: AppSpacing.md),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
}
