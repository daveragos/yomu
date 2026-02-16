enum QuestType { pages, minutes, earlyBird, nightOwl, bookFinished }

class DailyQuest {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final int targetValue;
  final int currentValue;
  final int xpReward;
  final bool isCompleted;
  final DateTime date;

  DailyQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    required this.xpReward,
    this.isCompleted = false,
    required this.date,
  });

  double get progress => (currentValue / targetValue).clamp(0.0, 1.0);

  DailyQuest copyWith({
    String? id,
    String? title,
    String? description,
    QuestType? type,
    int? targetValue,
    int? currentValue,
    int? xpReward,
    bool? isCompleted,
    DateTime? date,
  }) {
    return DailyQuest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      xpReward: xpReward ?? this.xpReward,
      isCompleted: isCompleted ?? this.isCompleted,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.index,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'xpReward': xpReward,
      'isCompleted': isCompleted ? 1 : 0,
      'date': date.toIso8601String().split('T')[0],
    };
  }

  factory DailyQuest.fromMap(Map<String, dynamic> map) {
    return DailyQuest(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      type: QuestType.values[map['type']],
      targetValue: map['targetValue'],
      currentValue: map['currentValue'],
      xpReward: map['xpReward'],
      isCompleted: map['isCompleted'] == 1,
      date: DateTime.parse(map['date']),
    );
  }
}
