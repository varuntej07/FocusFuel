import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../Models/debate_model.dart';
import '../Models/debate_preset_model.dart';

class DebateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Start a new debate by creating the debate document and request
  Future<String> startDebate({
    required String dilemma,
    required String customAgentPresetId,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Create the debate document first
      final debateRef = _firestore
          .collection('Users')
          .doc(userId)
          .collection('debates')
          .doc();

      final debateId = debateRef.id;

      // Get the preset details
      final preset = DebatePresetModel.defaultPresets
          .firstWhere((p) => p.id == customAgentPresetId,
              orElse: () => DebatePresetModel.defaultPresets.first);

      await debateRef.set({
        'userId': userId,
        'dilemma': dilemma,
        'status': 'pending',
        'state': 'idle',
        'customAgent': {
          'id': preset.id,
          'name': preset.name,
          'tone': preset.tone,
          'personality': preset.personality,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create the debate request to trigger the Cloud Function
      await _firestore.collection('DebateRequests').add({
        'userId': userId,
        'debateId': debateId,
        'dilemma': dilemma,
        'customAgent': preset.id,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return debateId;
    } catch (error, stackTrace) {
      _handleError('Failed to start debate', error, stackTrace);
      rethrow;
    }
  }

  /// Get a stream of a specific debate for real-time updates
  Stream<DebateModel?> getDebateStream(String debateId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('Users')
        .doc(userId)
        .collection('debates')
        .doc(debateId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return DebateModel.fromFirestore(snapshot);
    });
  }

  /// Get stream of debate turns for real-time updates during active debate
  Stream<List<DebateTurn>> getDebateTurnsStream(String debateId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('Users')
        .doc(userId)
        .collection('debates')
        .doc(debateId)
        .collection('turns')
        .orderBy('turnNumber', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DebateTurn.fromFirestore(doc))
          .toList();
    });
  }

  /// Get stream of all user's debates for history
  Stream<List<DebateModel>> getDebatesStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('Users')
        .doc(userId)
        .collection('debates')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DebateModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get a single debate by ID
  Future<DebateModel?> getDebate(String debateId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    try {
      final doc = await _firestore
          .collection('Users')
          .doc(userId)
          .collection('debates')
          .doc(debateId)
          .get();

      if (!doc.exists) return null;
      return DebateModel.fromFirestore(doc);
    } catch (error, stackTrace) {
      _handleError('Failed to get debate', error, stackTrace);
      return null;
    }
  }

  /// Get all turns for a completed debate
  Future<List<DebateTurn>> getDebateTurns(String debateId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('Users')
          .doc(userId)
          .collection('debates')
          .doc(debateId)
          .collection('turns')
          .orderBy('turnNumber', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => DebateTurn.fromFirestore(doc))
          .toList();
    } catch (error, stackTrace) {
      _handleError('Failed to get debate turns', error, stackTrace);
      return [];
    }
  }

  /// Cancel an active debate
  Future<void> cancelDebate(String debateId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('Users')
          .doc(userId)
          .collection('debates')
          .doc(debateId)
          .update({
        'status': 'cancelled',
        'state': 'complete',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stackTrace) {
      _handleError('Failed to cancel debate', error, stackTrace);
      rethrow;
    }
  }

  /// Delete a debate from history
  Future<void> deleteDebate(String debateId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final debateRef = _firestore
          .collection('Users')
          .doc(userId)
          .collection('debates')
          .doc(debateId);

      // Delete all turns first
      final turnsSnapshot = await debateRef.collection('turns').get();
      for (final doc in turnsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the debate document
      await debateRef.delete();
    } catch (error, stackTrace) {
      _handleError('Failed to delete debate', error, stackTrace);
      rethrow;
    }
  }

  /// Save user feedback on which agent's points resonated
  Future<void> saveDebateFeedback({
    required String debateId,
    required String preferredAgent,
    String? additionalNotes,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('Users')
          .doc(userId)
          .collection('debates')
          .doc(debateId)
          .update({
        'userFeedback': {
          'preferredAgent': preferredAgent,
          'additionalNotes': additionalNotes,
          'submittedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stackTrace) {
      _handleError('Failed to save debate feedback', error, stackTrace);
      rethrow;
    }
  }

  /// Get user's daily debate count for limit display
  Future<int> getDailyDebateCount() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0;

    try {
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      final userData = userDoc.data();
      return userData?['dailyDebateCount'] ?? 0;
    } catch (error, stackTrace) {
      _handleError('Failed to get daily debate count', error, stackTrace);
      return 0;
    }
  }

  /// Get available presets (currently returns default presets)
  List<DebatePresetModel> getAvailablePresets() {
    return DebatePresetModel.defaultPresets;
  }

  void _handleError(String context, dynamic error, [StackTrace? stackTrace]) {
    FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace ?? StackTrace.current,
        information: ['DebateService: $context']
    );
  }
}
