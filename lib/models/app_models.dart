// 1. نموذج بيانات المستخدم (Profile)
class UserProfile {
  final String id;
  final String fullName;
  final String phone;
  final String role;
  final String? passcode;
  final int backupIntervalDays;
  final DateTime? lastBackupAt;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.role = 'user',
    this.passcode,
    this.backupIntervalDays = 0,
    this.lastBackupAt,
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
      backupIntervalDays: (json['backup_interval_days'] as num?)?.toInt() ?? 0,
      lastBackupAt: json['last_backup_at'] != null
          ? DateTime.parse(json['last_backup_at'] as String)
          : null,
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
      'backup_interval_days': backupIntervalDays,
      if (lastBackupAt != null) 'last_backup_at': lastBackupAt!.toUtc().toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? role,
    String? passcode,
    int? backupIntervalDays,
    DateTime? lastBackupAt,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      passcode: passcode ?? this.passcode,
      backupIntervalDays: backupIntervalDays ?? this.backupIntervalDays,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
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

// 4. نموذج باقات الشركة المزودة (Subscription Plan)
class SubscriptionPlan {
  final String id;
  final String userId;
  final String name;
  final double costPrice;
  final DateTime createdAt;

  SubscriptionPlan({
    required this.id,
    required this.userId,
    required this.name,
    required this.costPrice,
    required this.createdAt,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'cost_price': costPrice,
    };
  }
}

// 5. نموذج سجل الحركات المالية والملاحظات والأرباح للمشترك
class SubscriberTransaction {
  final String id;
  final String userId;
  final String subscriberId;
  final String type;
  final double amount;
  final double remainingDebt;
  final String? notes;
  final DateTime createdAt;

  final String? planId;
  final String? planName;
  final double? costPrice;
  final double? sellingPrice;
  final double? profit;
  final String? paymentMode;

  final String? subscriberName;
  final String? towerId;
  final String? towerName;

  SubscriberTransaction({
    required this.id,
    required this.userId,
    required this.subscriberId,
    required this.type,
    required this.amount,
    required this.remainingDebt,
    this.notes,
    required this.createdAt,
    this.planId,
    this.planName,
    this.costPrice,
    this.sellingPrice,
    this.profit,
    this.paymentMode,
    this.subscriberName,
    this.towerId,
    this.towerName,
  });

  factory SubscriberTransaction.fromJson(Map<String, dynamic> json) {
    final subMap = json['subscribers'] as Map<String, dynamic>?;
    final towerMap = subMap != null ? subMap['towers'] as Map<String, dynamic>? : null;

    return SubscriberTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      subscriberId: json['subscriber_id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      remainingDebt: (json['remaining_debt'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      planId: json['plan_id'] as String?,
      planName: json['plan_name'] as String?,
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      sellingPrice: (json['selling_price'] as num?)?.toDouble(),
      profit: (json['profit'] as num?)?.toDouble(),
      paymentMode: json['payment_mode'] as String?,
      subscriberName: subMap?['full_name'] as String?,
      towerId: subMap?['tower_id'] as String?,
      towerName: towerMap?['name'] as String?,
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
      if (planId != null) 'plan_id': planId,
      if (planName != null) 'plan_name': planName,
      if (costPrice != null) 'cost_price': costPrice,
      if (sellingPrice != null) 'selling_price': sellingPrice,
      if (profit != null) 'profit': profit,
      if (paymentMode != null) 'payment_mode': paymentMode,
    };
  }
}

// 6. نموذج حركات صندوق النقد (مع التصنيف: مصاريف أو تسديد)
class CashBoxTransaction {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final String category; // 'expense' (مصاريف تشغيلية) أو 'payment' (تسديد عادي)
  final String? notes;
  final DateTime createdAt;

  CashBoxTransaction({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    this.category = 'expense',
    this.notes,
    required this.createdAt,
  });

  bool get isExpense => category == 'expense';

  factory CashBoxTransaction.fromJson(Map<String, dynamic> json) {
    return CashBoxTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'expense',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'amount': amount,
      'category': category,
      if (notes != null) 'notes': notes,
    };
  }
}