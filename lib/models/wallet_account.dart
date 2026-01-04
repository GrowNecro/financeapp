class WalletAccount {
  final int? id;
  final String name;
  final String type; // 'cash', 'bank', 'ewallet'
  final String? icon; // Icon name for display
  final double initialBalance;
  final String? color; // Hex color for UI
  final bool isActive;

  WalletAccount({
    this.id,
    required this.name,
    required this.type,
    this.icon,
    this.initialBalance = 0,
    this.color,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'name': name,
      'type': type,
      'icon': icon,
      'initialBalance': initialBalance,
      'color': color,
      'isActive': isActive ? 1 : 0,
    };

    if (id != null) {
      map['id'] = id!;
    }

    return map;
  }

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    return WalletAccount(
      id: json['id'] as int?,
      name: json['name'],
      type: json['type'],
      icon: json['icon'],
      initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? 0,
      color: json['color'],
      isActive: (json['isActive'] as int?) == 1,
    );
  }

  WalletAccount copyWith({
    int? id,
    String? name,
    String? type,
    String? icon,
    double? initialBalance,
    String? color,
    bool? isActive,
  }) {
    return WalletAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      initialBalance: initialBalance ?? this.initialBalance,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
    );
  }
}
