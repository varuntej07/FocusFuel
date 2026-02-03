import 'package:cloud_firestore/cloud_firestore.dart';

/// Debate status enum
enum DebateStatus { pending, inProgress, completed, error, cancelled, limitReached }

/// Debate phase enum
enum DebatePhase { idle, opening, exchange, summary, complete }

/// Debate state enum (maps to backend DEBATE_STATES)
enum DebateState { idle, opening, exchange, summary, complete, error }

/// Main debate model
class DebateModel {
  final String id;
  final String userId;
  final String dilemma;
  final DebateStatus status;
  final DebateState state;
  final String? currentPhase;
  final int? currentTurn;
  final String? lastTurnText;
  final String? lastTurnAgent;
  final DebateAgentConfig? customAgent;
  final DebateSummary? summary;
  final int? totalTurns;
  final String? error;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  DebateModel({
    required this.id,
    required this.userId,
    required this.dilemma,
    required this.status,
    required this.state,
    this.currentPhase,
    this.currentTurn,
    this.lastTurnText,
    this.lastTurnAgent,
    this.customAgent,
    this.summary,
    this.totalTurns,
    this.error,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.updatedAt,
  });

  factory DebateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DebateModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      dilemma: data['dilemma'] ?? '',
      status: _parseStatus(data['status']),
      state: _parseState(data['state']),
      currentPhase: data['currentPhase'],
      currentTurn: data['currentTurn'],
      lastTurnText: data['lastTurnText'],
      lastTurnAgent: data['lastTurnAgent'],
      customAgent: data['customAgent'] != null
          ? DebateAgentConfig.fromMap(data['customAgent'])
          : null,
      summary: data['summary'] != null
          ? DebateSummary.fromMap(data['summary'])
          : null,
      totalTurns: data['totalTurns'],
      error: data['error'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'dilemma': dilemma,
      'status': status.name,
      'state': state.name,
      'currentPhase': currentPhase,
      'currentTurn': currentTurn,
      'lastTurnText': lastTurnText,
      'lastTurnAgent': lastTurnAgent,
      'customAgent': customAgent?.toMap(),
      'summary': summary?.toMap(),
      'totalTurns': totalTurns,
      'error': error,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  static DebateStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return DebateStatus.pending;
      case 'in_progress':
        return DebateStatus.inProgress;
      case 'completed':
        return DebateStatus.completed;
      case 'error':
        return DebateStatus.error;
      case 'cancelled':
        return DebateStatus.cancelled;
      case 'limit_reached':
        return DebateStatus.limitReached;
      default:
        return DebateStatus.pending;
    }
  }

  static DebateState _parseState(String? state) {
    switch (state) {
      case 'idle':
        return DebateState.idle;
      case 'opening':
        return DebateState.opening;
      case 'exchange':
        return DebateState.exchange;
      case 'summary':
        return DebateState.summary;
      case 'complete':
        return DebateState.complete;
      case 'error':
        return DebateState.error;
      default:
        return DebateState.idle;
    }
  }

  bool get isActive =>
      status == DebateStatus.pending || status == DebateStatus.inProgress;

  bool get isComplete => status == DebateStatus.completed;

  bool get hasError => status == DebateStatus.error;
}

/// Individual debate turn
class DebateTurn {
  final String? id;
  final int turnNumber;
  final String agentType; // 'fixed' or 'custom'
  final String agentName;
  final String text;
  final String phase;
  final String? audioStoragePath;
  final DateTime timestamp;

  DebateTurn({
    this.id,
    required this.turnNumber,
    required this.agentType,
    required this.agentName,
    required this.text,
    required this.phase,
    this.audioStoragePath,
    required this.timestamp,
  });

  factory DebateTurn.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DebateTurn(
      id: doc.id,
      turnNumber: data['turnNumber'] ?? 0,
      agentType: data['agentType'] ?? 'fixed',
      agentName: data['agentName'] ?? '',
      text: data['text'] ?? '',
      phase: data['phase'] ?? 'opening',
      audioStoragePath: data['audioStoragePath'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'turnNumber': turnNumber,
      'agentType': agentType,
      'agentName': agentName,
      'text': text,
      'phase': phase,
      'audioStoragePath': audioStoragePath,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  bool get isFixedAgent => agentType == 'fixed';
  bool get isCustomAgent => agentType == 'custom';
}

/// Agent configuration for custom agent selection
class DebateAgentConfig {
  final String id;
  final String name;
  final String tone;
  final String personality;
  final String? voiceId;
  final Map<String, dynamic>? voiceSettings;

  DebateAgentConfig({
    required this.id,
    required this.name,
    required this.tone,
    required this.personality,
    this.voiceId,
    this.voiceSettings,
  });

  factory DebateAgentConfig.fromMap(Map<String, dynamic> data) {
    return DebateAgentConfig(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      tone: data['tone'] ?? 'balanced',
      personality: data['personality'] ?? 'supportive',
      voiceId: data['voiceId'],
      voiceSettings: data['voiceSettings'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tone': tone,
      'personality': personality,
      'voiceId': voiceId,
      'voiceSettings': voiceSettings,
    };
  }
}

/// Debate summary generated after completion
class DebateSummary {
  final List<String> criticKeyPoints;
  final List<String> customAgentKeyPoints;
  final String suggestedAction;
  final String? insight;

  DebateSummary({
    required this.criticKeyPoints,
    required this.customAgentKeyPoints,
    required this.suggestedAction,
    this.insight,
  });

  factory DebateSummary.fromMap(Map<String, dynamic> data) {
    return DebateSummary(
      criticKeyPoints: List<String>.from(data['criticKeyPoints'] ?? []),
      customAgentKeyPoints: List<String>.from(data['customAgentKeyPoints'] ?? []),
      suggestedAction: data['suggestedAction'] ?? '',
      insight: data['insight'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'criticKeyPoints': criticKeyPoints,
      'customAgentKeyPoints': customAgentKeyPoints,
      'suggestedAction': suggestedAction,
      'insight': insight,
    };
  }
}
