class EducationPetState {
  static const int xpPerLevel = 100;
  static const int xpPerMeal = 18;

  final String name;
  final int level;
  final int currentXp;
  final int totalXp;
  final int feedCount;
  final int foodBalance;
  final int coins;
  final int? lastFedAtMillis;

  const EducationPetState({
    required this.name,
    required this.level,
    required this.currentXp,
    required this.totalXp,
    required this.feedCount,
    required this.foodBalance,
    required this.coins,
    required this.lastFedAtMillis,
  });

  factory EducationPetState.initial() {
    return const EducationPetState(
      name: 'Luma',
      level: 1,
      currentXp: 24,
      totalXp: 24,
      feedCount: 0,
      foodBalance: 1,
      coins: 0,
      lastFedAtMillis: null,
    );
  }

  bool get hasFood => foodBalance > 0;

  double get progress {
    final value = currentXp / xpPerLevel;
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }

  String get moodLabel {
    if (!hasFood) {
      return 'Esperando comida';
    }
    if (feedCount == 0) {
      return 'Curiosa';
    }
    if (progress >= 0.75) {
      return 'Motivada';
    }
    if (progress >= 0.40) {
      return 'Activa';
    }
    return 'Con hambre';
  }

  String get statusMessage {
    if (!hasFood) {
      return '$name necesita comida del juego para seguir creciendo.';
    }
    if (feedCount == 0) {
      return '$name esta lista para aprender contigo.';
    }
    if (progress >= 0.75) {
      return '$name esta con toda la energia para seguir.';
    }
    if (progress >= 0.40) {
      return '$name sigue creciendo con cada actividad.';
    }
    return '$name necesita otra ayuda para subir mas rapido.';
  }

  String get lastFedLabel {
    if (lastFedAtMillis == null) {
      return 'Todavia no la alimentaste.';
    }

    final date = DateTime.fromMillisecondsSinceEpoch(
      lastFedAtMillis!,
    ).toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return 'Ultima comida: $hour:$minute';
  }

  EducationPetState feed() {
    var updatedLevel = level;
    var updatedXp = currentXp + xpPerMeal;

    while (updatedXp >= xpPerLevel) {
      updatedXp -= xpPerLevel;
      updatedLevel += 1;
    }

    return copyWith(
      level: updatedLevel,
      currentXp: updatedXp,
      totalXp: totalXp + xpPerMeal,
      feedCount: feedCount + 1,
      foodBalance: foodBalance - 1,
      lastFedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
  }

  EducationPetState rewardFromGame({
    required int foodEarned,
    required int coinsEarned,
  }) {
    return copyWith(
      foodBalance: foodBalance + foodEarned,
      coins: coins + coinsEarned,
    );
  }

  EducationPetState copyWith({
    String? name,
    int? level,
    int? currentXp,
    int? totalXp,
    int? feedCount,
    int? foodBalance,
    int? coins,
    int? lastFedAtMillis,
  }) {
    return EducationPetState(
      name: name ?? this.name,
      level: level ?? this.level,
      currentXp: currentXp ?? this.currentXp,
      totalXp: totalXp ?? this.totalXp,
      feedCount: feedCount ?? this.feedCount,
      foodBalance: foodBalance ?? this.foodBalance,
      coins: coins ?? this.coins,
      lastFedAtMillis: lastFedAtMillis ?? this.lastFedAtMillis,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'level': level,
      'currentXp': currentXp,
      'totalXp': totalXp,
      'feedCount': feedCount,
      'foodBalance': foodBalance,
      'coins': coins,
      'lastFedAtMillis': lastFedAtMillis,
    };
  }

  factory EducationPetState.fromJson(Map<String, dynamic> json) {
    final initial = EducationPetState.initial();

    return EducationPetState(
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString()
          : initial.name,
      level: _asInt(json['level'], initial.level),
      currentXp: _asInt(json['currentXp'], initial.currentXp),
      totalXp: _asInt(json['totalXp'], initial.totalXp),
      feedCount: _asInt(json['feedCount'], initial.feedCount),
      foodBalance: _asInt(json['foodBalance'], initial.foodBalance),
      coins: _asInt(json['coins'], initial.coins),
      lastFedAtMillis: _asNullableInt(json['lastFedAtMillis']),
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }
}
