/// Events emitted during real-time debate streaming
/// Corresponds to SSE events from backend
library;

/// Base event type
abstract class DebateStreamEvent {
  final String eventType;

  DebateStreamEvent(this.eventType);
}

/// Sent when connection is established
class ConnectedEvent extends DebateStreamEvent {
  ConnectedEvent() : super('connected');
}

/// Sent when a new turn starts
class TurnStartEvent extends DebateStreamEvent {
  final int turnNumber;
  final String agentType; // 'fixed' or 'custom'
  final String agentName;
  final String phase;

  TurnStartEvent({
    required this.turnNumber,
    required this.agentType,
    required this.agentName,
    required this.phase,
  }) : super('turn_start');

  factory TurnStartEvent.fromJson(Map<String, dynamic> json) {
    return TurnStartEvent(
      turnNumber: json['turnNumber'] ?? 0,
      agentType: json['agentType'] ?? 'fixed',
      agentName: json['agentName'] ?? '',
      phase: json['phase'] ?? 'opening',
    );
  }
}

/// Sent for each text token during streaming
class TokenEvent extends DebateStreamEvent {
  final int turnNumber;
  final String agentType;
  final String text;

  TokenEvent({
    required this.turnNumber,
    required this.agentType,
    required this.text,
  }) : super('token');

  factory TokenEvent.fromJson(Map<String, dynamic> json) {
    return TokenEvent(
      turnNumber: json['turnNumber'] ?? 0,
      agentType: json['agentType'] ?? 'fixed',
      text: json['text'] ?? '',
    );
  }
}

/// Sent when a turn completes
class TurnEndEvent extends DebateStreamEvent {
  final int turnNumber;
  final String agentType;
  final String agentName;
  final String fullText;
  final String phase;

  TurnEndEvent({
    required this.turnNumber,
    required this.agentType,
    required this.agentName,
    required this.fullText,
    required this.phase,
  }) : super('turn_end');

  factory TurnEndEvent.fromJson(Map<String, dynamic> json) {
    return TurnEndEvent(
      turnNumber: json['turnNumber'] ?? 0,
      agentType: json['agentType'] ?? 'fixed',
      agentName: json['agentName'] ?? '',
      fullText: json['fullText'] ?? '',
      phase: json['phase'] ?? 'opening',
    );
  }
}

/// Sent when audio is ready for a turn
class AudioReadyEvent extends DebateStreamEvent {
  final int turnNumber;
  final String agentType;
  final String audioUrl;

  AudioReadyEvent({
    required this.turnNumber,
    required this.agentType,
    required this.audioUrl,
  }) : super('audio_ready');

  factory AudioReadyEvent.fromJson(Map<String, dynamic> json) {
    return AudioReadyEvent(
      turnNumber: json['turnNumber'] ?? 0,
      agentType: json['agentType'] ?? 'fixed',
      audioUrl: json['audioUrl'] ?? '',
    );
  }
}

/// Sent when summary generation starts
class SummaryStartEvent extends DebateStreamEvent {
  final String message;

  SummaryStartEvent({required this.message}) : super('summary_start');

  factory SummaryStartEvent.fromJson(Map<String, dynamic> json) {
    return SummaryStartEvent(
      message: json['message'] ?? 'Generating summary',
    );
  }
}

/// Sent when debate completes
class DebateCompleteEvent extends DebateStreamEvent {
  final int totalTurns;
  final Map<String, dynamic>? summary;

  DebateCompleteEvent({
    required this.totalTurns,
    this.summary,
  }) : super('debate_complete');

  factory DebateCompleteEvent.fromJson(Map<String, dynamic> json) {
    return DebateCompleteEvent(
      totalTurns: json['totalTurns'] ?? 0,
      summary: json['summary'],
    );
  }
}

/// Sent when an error occurs
class ErrorEvent extends DebateStreamEvent {
  final String message;
  final int? turnNumber;

  ErrorEvent({
    required this.message,
    this.turnNumber,
  }) : super('error');

  factory ErrorEvent.fromJson(Map<String, dynamic> json) {
    return ErrorEvent(
      message: json['message'] ?? 'An error occurred',
      turnNumber: json['turnNumber'],
    );
  }
}

/// Sent when stream is done (final event)
class DoneEvent extends DebateStreamEvent {
  DoneEvent() : super('done');
}
