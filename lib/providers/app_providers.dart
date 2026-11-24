import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/app_models.dart';
import '../services/app_service.dart';

// 1. مزود خدمة التطبيق (AppService)
final appServiceProvider = Provider<AppService>((ref) {
  return AppService();
});

// 2. مراقبة حالة جلسة المستخدم (Auth State)
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

// 3. مزود بيانات الملف الشخصي (Profile)
final profileProvider = FutureProvider<UserProfile>((ref) async {
  final service = ref.watch(appServiceProvider);
  return await service.getProfile();
});

// 4. مزود قائمة الأبراج (Towers)
final towersListProvider = FutureProvider<List<Tower>>((ref) async {
  final service = ref.watch(appServiceProvider);
  return await service.getTowers();
});

// 5. مزود الإحصائيات المالية
final financialSummaryProvider = FutureProvider<Map<String, double>>((ref) async {
  final service = ref.watch(appServiceProvider);
  return await service.getFinancialSummary();
});

// 6. مزودات التبويب الأول (الرئيسية): الترتيب والبحث والحد
final unpaidLimitProvider = StateProvider<int>((ref) => 10);
final homeDebtSortProvider = StateProvider<DebtSortType>((ref) => DebtSortType.oldestDebt);
final homeSearchQueryProvider = StateProvider<String>((ref) => '');

// مزود قائمة الديون في الرئيسية (مع دعم البحث التنبئي والتصفية حسب الأقدم أو الأعلى ديناً)
final unpaidSubscribersProvider = FutureProvider<List<Subscriber>>((ref) async {
  final service = ref.watch(appServiceProvider);
  final limit = ref.watch(unpaidLimitProvider);
  final sortType = ref.watch(homeDebtSortProvider);
  final query = ref.watch(homeSearchQueryProvider);

  return await service.getSubscribers(
    unpaidOnly: true,
    sortType: sortType,
    searchQuery: query,
    limit: limit,
  );
});

// 7. مزودات التبويب الثاني (الأبراج)
final selectedTowerFilterProvider = StateProvider<String?>((ref) => null);

final subscribersByTowerProvider = FutureProvider<List<Subscriber>>((ref) async {
  final service = ref.watch(appServiceProvider);
  final selectedTowerId = ref.watch(selectedTowerFilterProvider);
  return await service.getSubscribers(
    towerId: selectedTowerId,
    unpaidOnly: false,
  );
});

// 8. مزود جلب سجل الحركات والملاحظات لمشترك معين
final subscriberTransactionsProvider =
    FutureProvider.family<List<SubscriberTransaction>, String>((ref, subscriberId) async {
  final service = ref.watch(appServiceProvider);
  return await service.getSubscriberTransactions(subscriberId);
});