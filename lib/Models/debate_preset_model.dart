import 'package:cloud_firestore/cloud_firestore.dart';

/// Preset agent configurations that users can select from
class DebatePresetModel {
  final String id;
  final String name;
  final String tone;
  final String personality;
  final String description;
  final String? iconName;
  final bool isDefault;
  final int displayOrder;

  DebatePresetModel({
    required this.id,
    required this.name,
    required this.tone,
    required this.personality,
    required this.description,
    this.iconName,
    this.isDefault = false,
    this.displayOrder = 0,
  });

  factory DebatePresetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DebatePresetModel(
      id: doc.id,
      name: data['name'] ?? '',
      tone: data['tone'] ?? 'balanced',
      personality: data['personality'] ?? 'supportive',
      description: data['description'] ?? '',
      iconName: data['iconName'],
      isDefault: data['isDefault'] ?? false,
      displayOrder: data['displayOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'tone': tone,
      'personality': personality,
      'description': description,
      'iconName': iconName,
      'isDefault': isDefault,
      'displayOrder': displayOrder,
    };
  }

  // Default presets that match backend CUSTOM_AGENT_PRESETS
  static List<DebatePresetModel> get defaultPresets => [
    DebatePresetModel(
      id: 'motivator',
      name: 'The Motivator',
      tone: 'encouraging',
      personality: 'supportive',
      description: 'An encouraging coach who believes in your potential and helps you see possibilities.',
      iconName: 'emoji_events',
      isDefault: true,
      displayOrder: 0,
    ),
    DebatePresetModel(
      id: 'analyst',
      name: 'The Analyst',
      tone: 'logical',
      personality: 'methodical',
      description: 'A rational strategist who breaks down complex decisions into clear components.',
      iconName: 'analytics',
      isDefault: false,
      displayOrder: 1,
    ),
    DebatePresetModel(
      id: 'dreamer',
      name: 'The Dreamer',
      tone: 'visionary',
      personality: 'expansive',
      description: 'A creative visionary who helps you think bigger and challenges small thinking.',
      iconName: 'lightbulb',
      isDefault: false,
      displayOrder: 2,
    ),
    DebatePresetModel(
      id: 'devil_advocate',
      name: "Devil's Advocate",
      tone: 'contrarian',
      personality: 'provocative',
      description: 'Argues the opposite position to stress-test your ideas and expose blind spots.',
      iconName: 'gavel',
      isDefault: false,
      displayOrder: 3,
    ),
  ];
}

/// User's saved custom preset (for future use)
class UserDebatePresetModel {
  final String id;
  final String userId;
  final String name;
  final String tone;
  final String personality;
  final String? customPrompt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserDebatePresetModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.tone,
    required this.personality,
    this.customPrompt,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserDebatePresetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserDebatePresetModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      tone: data['tone'] ?? 'balanced',
      personality: data['personality'] ?? 'supportive',
      customPrompt: data['customPrompt'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'tone': tone,
      'personality': personality,
      'customPrompt': customPrompt,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
