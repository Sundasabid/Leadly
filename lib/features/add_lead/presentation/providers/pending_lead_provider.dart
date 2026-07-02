import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../leads/data/leads_repository.dart';
import '../../../leads/domain/models/lead_model.dart';

/// The LeadInput the agent is about to save, held here so S10 can read it
/// without needing route params.
final pendingLeadInputProvider = StateProvider<LeadInput?>((ref) => null);

/// The existing lead that triggered the duplicate warning in S10.
final pendingDuplicateProvider = StateProvider<LeadModel?>((ref) => null);

/// The raw extraction result from the voice lead Edge Function.
/// Held here so VoiceRecordingScreen can push to ReviewExtractedLeadScreen
/// without route params. Cleared after save or discard in the review screen.
final pendingExtractedLeadProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);
