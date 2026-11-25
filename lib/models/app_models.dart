// 1. نموذج بيانات المستخدم (Profile)
class UserProfile {
  final String id;
  final String fullName;
  final String phone;
  final String role; // 'admin' أو 'user'
  final String? passcode; // الرمز للكشف من قبل الأدمن
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.role = 'user',
    this.passcode,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      passcode: json['passcode'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      if (passcode != null) 'passcode': passcode,
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? role,
    String? passcode,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      passcode: passcode ?? this.passcode,
      createdAt: createdAt,
    );
  }
}

// 2. نموذج بيانات البرج (Tower)
class Tower {
  final String id;
  final String userId;
  final String name;
  final String? location;
  final DateTime createdAt;

  Tower({
    required this.id,
    required this.userId,
    required this.name,
    this.location,
    required this.createdAt,
  });

  factory Tower.fromJson(Map<String, dynamic> json) {
    return Tower(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      location: json['location'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      if (location != null) 'location': location,
    };
  }
}

// 3. نموذج بيانات المشترك (Subscriber)
class Subscriber {
  final String id;
  final String userId;
  final String towerId;
  final String fullName;
  final String phone;
  final double debtAmount;
  final double paidAmount;
  final DateTime lastDebtUpdatedAt;
  final DateTime createdAt;
  final String? towerName;

  Subscriber({
    required this.id,
    required this.userId,
    required this.towerId,
    required this.fullName,
    required this.phone,
    required this.debtAmount,
    required this.paidAmount,
    required this.lastDebtUpdatedAt,
    required this.createdAt,
    this.towerName,
  });

  factory Subscriber.fromJson(Map<String, dynamic> json) {
    return Subscriber(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      towerId: json['tower_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      debtAmount: (json['debt_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      lastDebtUpdatedAt: DateTime.parse(
        json['last_debt_updated_at'] as String? ?? json['created_at'] as String,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      towerName: json['towers'] != null ? json['towers']['name'] as String? : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'tower_id': towerId,
      'full_name': fullName,
      'phone': phone,
      'debt_amount': debtAmount,
      'paid_amount': paidAmount,
    };
  }

  Subscriber copyWith({
    String? fullName,
    String? phone,
    String? towerId,
    double? debtAmount,
    double? paidAmount,
    DateTime? lastDebtUpdatedAt,
    String? towerName,
  }) {
    return Subscriber(
      id: id,
      userId: userId,
      towerId: towerId ?? this.towerId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      debtAmount: debtAmount ?? this.debtAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      lastDebtUpdatedAt: lastDebtUpdatedAt ?? this.lastDebtUpdatedAt,
      createdAt: createdAt,
      towerName: towerName ?? this.towerName,
    );
  }
}

// 4. نموذج سجل الحركات المالية والملاحظات للمشترك (Subscriber Transaction)
class SubscriberTransaction {
  final String id;
  final String userId;
  final String subscriberId;
  final String type; // 'payment' أو 'debt_addition' أو 'adjustment'
  final double amount;
  final double remainingDebt;
  final String? notes;
  final DateTime createdAt;

  SubscriberTransaction({
    required this.id,
    required this.userId,
    required this.subscriberId,
    required this.type,
    required this.amount,
    required this.remainingDebt,
    this.notes,
    required this.createdAt,
  });

  factory SubscriberTransaction.fromJson(Map<String, dynamic> json) {
    return SubscriberTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      subscriberId: json['subscriber_id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      remainingDebt: (json['remaining_debt'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'subscriber_id': subscriberId,
      'type': type,
      'amount': amount,
      'remaining_debt': remainingDebt,
      if (notes != null) 'notes': notes,
    };
  }
}

// 5. نموذج حركات صندوق النقد (Cash Box Transaction)
class CashBoxTransaction {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final String? notes;
  final DateTime createdAt;

  CashBoxTransaction({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    this.notes,
    required this.createdAt,
  });

  factory CashBoxTransaction.fromJson(Map<String, dynamic> json) {
    return CashBoxTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'amount': amount,
      if (notes != null) 'notes': notes,
    };
  }
}