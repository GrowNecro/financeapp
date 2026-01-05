class WhatsAppUser {
  final String? id;
  final String userId; // Firebase user ID
  final String phoneNumber; // WhatsApp number
  final bool isVerified;
  final String? verificationCode;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  WhatsAppUser({
    this.id,
    required this.userId,
    required this.phoneNumber,
    this.isVerified = false,
    this.verificationCode,
    this.verifiedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'phoneNumber': phoneNumber,
      'isVerified': isVerified,
      'verificationCode': verificationCode,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WhatsAppUser.fromJson(Map<String, dynamic> json) {
    return WhatsAppUser(
      id: json['id']?.toString(),
      userId: json['userId'],
      phoneNumber: json['phoneNumber'],
      isVerified: json['isVerified'] ?? false,
      verificationCode: json['verificationCode'],
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  WhatsAppUser copyWith({
    String? id,
    String? userId,
    String? phoneNumber,
    bool? isVerified,
    String? verificationCode,
    DateTime? verifiedAt,
    DateTime? createdAt,
  }) {
    return WhatsAppUser(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isVerified: isVerified ?? this.isVerified,
      verificationCode: verificationCode ?? this.verificationCode,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
