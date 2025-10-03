import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum AudioPlaybackState { stopped, playing, paused }

class AudioService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();

  AudioPlaybackState _state = AudioPlaybackState.stopped;
  Map<String, dynamic>? _currentArticle;
  double _progress = 0.0;
  bool _isInitialized = false;

  // Track position for resume functionality
  String? _fullText;
  int _lastCharPosition = 0;
  String? _remainingText;

  AudioPlaybackState get state => _state;
  Map<String, dynamic>? get currentArticle => _currentArticle;
  double get progress => _progress;
  bool get isPlaying => _state == AudioPlaybackState.playing;
  bool get isPaused => _state == AudioPlaybackState.paused;
  bool get isStopped => _state == AudioPlaybackState.stopped;

  AudioService() {
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    try {
      // Configure TTS settings
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5); // Normal speed
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set up completion handler
      _flutterTts.setCompletionHandler(() {
        _state = AudioPlaybackState.stopped;
        _progress = 1.0;
        _lastCharPosition = 0;
        _remainingText = null;
        notifyListeners();
      });

      // Set up progress handler
      _flutterTts.setProgressHandler((String text, int start, int end, String word) {
        // Calculate progress based on character position in the full text
        if (_fullText != null && _fullText!.isNotEmpty) {
          _lastCharPosition = end;
          _progress = end / _fullText!.length;
          notifyListeners();
        }
      });

      // Set up error handler
      _flutterTts.setErrorHandler((message) {
        debugPrint('TTS Error: $message');
        stop();
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  Future<void> playArticle(Map<String, dynamic> article, {bool resume = false}) async {
    if (!_isInitialized) {
      await _initializeTts();
    }

    // If not resuming, start from beginning
    if (!resume) {
      // Stop any current playback
      if (_state != AudioPlaybackState.stopped) {
        await stop();
      }

      _currentArticle = article;
      _lastCharPosition = 0;
      _progress = 0.0;

      // Prepare text to speak
      final title = article['title'] ?? '';
      final description = article['description'] ?? '';
      _fullText = '$title. $description';
      _remainingText = _fullText;
    }

    _state = AudioPlaybackState.playing;
    notifyListeners();

    try {
      // Speak the remaining text (or full text if starting fresh)
      if (_remainingText != null && _remainingText!.isNotEmpty) {
        await _flutterTts.speak(_remainingText!);
      }
    } catch (e) {
      debugPrint('Error speaking: $e');
      stop();
    }
  }

  Future<void> pause() async {
    if (_state == AudioPlaybackState.playing) {
      await _flutterTts.stop();
      _state = AudioPlaybackState.paused;

      // Calculate remaining text from last position
      if (_fullText != null && _lastCharPosition < _fullText!.length) {
        _remainingText = _fullText!.substring(_lastCharPosition);
        debugPrint('Paused at position $_lastCharPosition, remaining: ${_remainingText!.length} chars');
      }

      notifyListeners();
    }
  }

  Future<void> resume() async {
    if (_state == AudioPlaybackState.paused && _currentArticle != null) {
      // Resume from where we paused
      await playArticle(_currentArticle!, resume: true);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _state = AudioPlaybackState.stopped;
    _currentArticle = null;
    _progress = 0.0;
    _lastCharPosition = 0;
    _fullText = null;
    _remainingText = null;
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
