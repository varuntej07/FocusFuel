import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/debate_model.dart';
import '../Models/debate_preset_model.dart';
import '../Models/debate_stream_event.dart';
import '../Services/debate_service.dart';
import '../Services/debate_stream_service.dart';
import '../Services/debate_audio_service.dart';

/// State enum for debate UI
enum DebateViewState {
  idle,           // No active debate
  setup,          // User is entering dilemma and selecting agent
  connecting,     // Waiting for debate to start
  inProgress,     // Debate is running, turns streaming in
  summarizing,    // Debate complete, summary being generated
  complete,       // Debate finished with summary
  error           // Error occurred
}

class DebateViewModel extends ChangeNotifier {
  final DebateService _debateService = DebateService();
  final DebateStreamService _streamService = DebateStreamService();
  final DebateAudioService _audioService = DebateAudioService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _disposed = false;

  // State
  DebateViewState _viewState = DebateViewState.idle;
  String? _currentDebateId;
  DebateModel? _currentDebate;
  List<DebateTurn> _turns = [];
  String? _errorMessage;

  // Setup state
  String _dilemma = '';
  DebatePresetModel? _selectedPreset;

  // Stream subscriptions
  StreamSubscription<DebateModel?>? _debateSubscription;
  StreamSubscription<List<DebateTurn>>? _turnsSubscription;
  StreamSubscription<DebateStreamEvent>? _debateStreamSubscription;

  // Streaming state
  final bool _useStreaming = true;        // Toggle for streaming vs Firestore mode
  final Map<int, String> _turnBuffers = {};         // Buffer tokens per turn
  int? _currentStreamingTurn;
  String? _currentStreamingAgent;

  // Getters
  String get userId => _auth.currentUser?.uid ?? '';
  DebateViewState get viewState => _viewState;
  String? get currentDebateId => _currentDebateId;
  DebateModel? get currentDebate => _currentDebate;
  List<DebateTurn> get turns => _turns;
  String? get errorMessage => _errorMessage;
  String get dilemma => _dilemma;
  DebatePresetModel? get selectedPreset => _selectedPreset;
  List<DebatePresetModel> get availablePresets => _debateService.getAvailablePresets();

  bool get canStartDebate =>
      _dilemma.trim().isNotEmpty &&
      _selectedPreset != null &&
      _viewState == DebateViewState.setup;

  bool get isDebateActive =>
      _viewState == DebateViewState.connecting ||
      _viewState == DebateViewState.inProgress ||
      _viewState == DebateViewState.summarizing;

  int? get currentStreamingTurn => _currentStreamingTurn;
  String? get currentStreamingAgent => _currentStreamingAgent;

  @override
  void dispose() {
    _disposed = true;
    _debateSubscription?.cancel();
    _turnsSubscription?.cancel();
    _debateStreamSubscription?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _updateState(DebateViewState newState) {
    _viewState = newState;
    _safeNotifyListeners();
  }

  /// Initialize for new debate setup
  void initSetup() {
    _viewState = DebateViewState.setup;
    _dilemma = '';
    _selectedPreset = availablePresets.firstWhere(
      (p) => p.isDefault,
      orElse: () => availablePresets.first,
    );
    _currentDebateId = null;
    _currentDebate = null;
    _turns = [];
    _errorMessage = null;
    _safeNotifyListeners();
  }

  /// Set the dilemma text
  void setDilemma(String dilemma) {
    _dilemma = dilemma;
    _safeNotifyListeners();
  }

  /// Select a preset for the custom agent
  void selectPreset(DebatePresetModel preset) {
    _selectedPreset = preset;
    _safeNotifyListeners();
  }

  /// Start a new debate
  Future<void> startDebate() async {
    if (!canStartDebate) return;

    _updateState(DebateViewState.connecting);
    _errorMessage = null;

    try {
      // Generate debate ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final debateId = 'debate_$timestamp';
      _currentDebateId = debateId;

      if (_useStreaming) {
        _startStreamingDebate(debateId);      // Use streaming mode
      } else {
        await _debateService.startDebate(
          dilemma: _dilemma.trim(),
          customAgentPresetId: _selectedPreset!.id,
        );
        _subscribeToDebate(debateId);
        _subscribeToTurns(debateId);
      }
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        information: ['Failed to start debate']
      );
      _errorMessage = 'Failed to start debate. Please try again.';
      _updateState(DebateViewState.error);
    }
  }

  /// Start streaming debate
  void _startStreamingDebate(String debateId) {
    _turnBuffers.clear();
    _currentStreamingTurn = null;
    _currentStreamingAgent = null;

    _debateStreamSubscription = _streamService.startDebateStream(
          dilemma: _dilemma.trim(),
          customAgentPresetId: _selectedPreset!.id,
          debateId: debateId,
        ).listen(
          _handleStreamEvent,
          onError: (error, stackTrace) {
            FirebaseCrashlytics.instance.recordError(
              error,
              stackTrace,
              information: ['Debate stream error'],
            );
            _errorMessage = 'Stream connection error';
            _updateState(DebateViewState.error);
          },
      // Stream completed
      onDone: () {
            if (_viewState != DebateViewState.complete &&
                _viewState != DebateViewState.error) {
              _updateState(DebateViewState.complete);
            }
          },
      cancelOnError: false,
    );
  }

  /// Handle incoming stream events
  void _handleStreamEvent(DebateStreamEvent event) {
    if (_disposed) return;

    if (event is ConnectedEvent) {
      // Connection established
      _updateState(DebateViewState.inProgress);
    } else if (event is TurnStartEvent) {
      // New turn starting
      _currentStreamingTurn = event.turnNumber;
      _currentStreamingAgent = event.agentName;
      _turnBuffers[event.turnNumber] = '';
      _safeNotifyListeners();
    } else if (event is TokenEvent) {
      // Token received - buffer it
      if (_currentStreamingTurn == event.turnNumber) {
        _turnBuffers[event.turnNumber] =
            (_turnBuffers[event.turnNumber] ?? '') + event.text;
        _safeNotifyListeners();
      }
    } else if (event is TurnEndEvent) {
      // Turn complete
      final turn = DebateTurn(
        turnNumber: event.turnNumber,
        agentType: event.agentType,
        agentName: event.agentName,
        text: event.fullText,
        phase: event.phase,
        timestamp: DateTime.now(),
      );
      _turns.add(turn);
      _currentStreamingTurn = null;
      _safeNotifyListeners();
    } else if (event is AudioReadyEvent) {
      // Audio available - could auto-play here if desired
      // For now, just note that audio is ready
      // Audio playback can be triggered by UI
    } else if (event is SummaryStartEvent) {
      _updateState(DebateViewState.summarizing);
    } else if (event is DebateCompleteEvent) {
      // Debate finished
      _updateState(DebateViewState.complete);
    } else if (event is ErrorEvent) {
      _errorMessage = event.message;
      _updateState(DebateViewState.error);
    }
  }

  /// Get current streaming text for a turn (for display)
  String? getStreamingTextForTurn(int turnNumber) {
    return _turnBuffers[turnNumber];
  }

  /// Play audio for a specific turn
  Future<void> playTurnAudio(String audioStoragePath, String turnId) async {
    try {
      await _audioService.playTurnAudio(audioStoragePath, turnId);
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        information: ['Failed to play turn audio'],
      );
    }
  }

  /// Stop audio playback
  Future<void> stopAudio() async {
    await _audioService.stop();
  }

  /// Pause audio
  Future<void> pauseAudio() async {
    await _audioService.pause();
  }

  /// Resume audio
  Future<void> resumeAudio() async {
    await _audioService.resume();
  }

  /// Get audio service for direct access (e.g., for UI controls)
  DebateAudioService get audioService => _audioService;

  /// Resume watching an existing debate
  Future<void> resumeDebate(String debateId) async {
    _currentDebateId = debateId;
    _updateState(DebateViewState.connecting);

    try {
      _subscribeToDebate(debateId);
      _subscribeToTurns(debateId);
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        information: ['Failed to resume debate: $debateId']
      );
      _errorMessage = 'Failed to resume debate.';
      _updateState(DebateViewState.error);
    }
  }

  void _subscribeToDebate(String debateId) {
    _debateSubscription?.cancel();
    _debateSubscription = _debateService.getDebateStream(debateId).listen(
      (debate) {
        if (_disposed) return;

        _currentDebate = debate;

        if (debate == null) {
          _updateState(DebateViewState.error);
          _errorMessage = 'Debate not found';
          return;
        }

        // Update view state based on debate state
        switch (debate.state) {
          case DebateState.idle:
          case DebateState.opening:
            _updateState(DebateViewState.connecting);
            break;
          case DebateState.exchange:
            _updateState(DebateViewState.inProgress);
            break;
          case DebateState.summary:
            _updateState(DebateViewState.summarizing);
            break;
          case DebateState.complete:
            _updateState(DebateViewState.complete);
            break;
          case DebateState.error:
            _errorMessage = debate.error ?? 'An error occurred';
            _updateState(DebateViewState.error);
            break;
        }

        // Check for limit reached
        if (debate.status == DebateStatus.limitReached) {
          _errorMessage = debate.error ?? 'Daily debate limit reached';
          _updateState(DebateViewState.error);
        }
      },
      onError: (error, stackTrace) {
        if (_disposed) return;
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          information: ['Debate stream error: $debateId']
        );
        _errorMessage = 'Connection error. Please try again.';
        _updateState(DebateViewState.error);
      },
    );
  }

  void _subscribeToTurns(String debateId) {
    _turnsSubscription?.cancel();
    _turnsSubscription = _debateService.getDebateTurnsStream(debateId).listen(
      (turns) {
        if (_disposed) return;
        _turns = turns;
        _safeNotifyListeners();
      },
      onError: (error, stackTrace) {
        if (_disposed) return;
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          information: ['Turns stream error: $debateId']
        );
      },
    );
  }

  /// Cancel the current debate
  Future<void> cancelDebate() async {
    if (_currentDebateId == null) return;

    try {
      await _debateService.cancelDebate(_currentDebateId!);
      _cleanup();
      _updateState(DebateViewState.idle);
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        information: ['Failed to cancel debate: $_currentDebateId']
      );
    }
  }

  /// Save feedback on which agent resonated
  Future<void> saveFeedback({
    required String preferredAgent,
    String? notes,
  }) async {
    if (_currentDebateId == null) return;

    try {
      await _debateService.saveDebateFeedback(
        debateId: _currentDebateId!,
        preferredAgent: preferredAgent,
        additionalNotes: notes,
      );
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        information: ['Failed to save debate feedback']
      );
    }
  }

  /// Reset to start a new debate
  void startNewDebate() {
    _cleanup();
    initSetup();
  }

  /// View a completed debate from history
  Future<void> viewDebateFromHistory(String debateId) async {
    _currentDebateId = debateId;
    _updateState(DebateViewState.connecting);

    try {
      final debate = await _debateService.getDebate(debateId);
      final turns = await _debateService.getDebateTurns(debateId);

      if (debate == null) {
        _errorMessage = 'Debate not found';
        _updateState(DebateViewState.error);
        return;
      }

      _currentDebate = debate;
      _turns = turns;

      if (debate.status == DebateStatus.completed) {
        _updateState(DebateViewState.complete);
      } else if (debate.isActive) {
        _subscribeToDebate(debateId);
        _subscribeToTurns(debateId);
      } else {
        _updateState(DebateViewState.complete);
      }
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        information: ['Failed to load debate from history: $debateId']
      );
      _errorMessage = 'Failed to load debate';
      _updateState(DebateViewState.error);
    }
  }

  void _cleanup() {
    _debateSubscription?.cancel();
    _turnsSubscription?.cancel();
    _debateStreamSubscription?.cancel();
    _debateSubscription = null;
    _turnsSubscription = null;
    _debateStreamSubscription = null;
    _currentDebateId = null;
    _currentDebate = null;
    _turns = [];
    _turnBuffers.clear();
    _currentStreamingTurn = null;
    _currentStreamingAgent = null;
    _errorMessage = null;
    _audioService.stop();
  }

  /// Get stream of all debates for history view
  Stream<List<DebateModel>> getDebatesStream() {
    return _debateService.getDebatesStream();
  }

  /// Delete a debate from history
  Future<void> deleteDebate(String debateId) async {
    try {
      await _debateService.deleteDebate(debateId);
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        information: ['Failed to delete debate: $debateId']
      );
      rethrow;
    }
  }
}
