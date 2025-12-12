class HomeMessage {
  final String? id;
  final String message;
  final DateTime? updatedAt;
  final bool isActive;

  const HomeMessage({
    required this.message,
    this.id,
    this.updatedAt,
    this.isActive = true,
  });

  factory HomeMessage.fromJson(Map<String, dynamic> json) {
    return HomeMessage(
      id: json['id'] as String?,
      message: (json['message'] ?? '') as String,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
    };
  }
}

