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

// 3. مراقبة معرف المستخدم الحالي
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user.id ?? supabase.auth.currentUser?.id;
});

// 4. مزود بيانات الملف الشخصي
final profileProvider = FutureProvider<UserProfile>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

  final service = ref.watch(appServiceProvider);
  return await service.getProfile();
});

// 5. مزود قائمة الأبراج
final towersListProvider = FutureProvider<List<Tower>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final service = ref.watch(appServiceProvider);
  return await service.getTowers();
});

// 6. مزود الإحصائيات المالية
final financialSummaryProvider = FutureProvider<Map<String, double>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return {
      'totalDebt': 0.0,
      'totalCollected': 0.0,
      'totalDisbursed': 0.0,
      'totalExpenses': 0.0,
      'totalProfitsAll': 0.0,
      'netRealProfit': 0.0,
      'totalPaid': 0.0,
    };
  }

  final service = ref.watch(appServiceProvider);
  return await service.getFinancialSummary();
});

// 7. مزودات التبويب الأول (الرئيسية)
final unpaidLimitProvider = StateProvider<int>((ref) => 10);
final homeDebtSortProvider = StateProvider<DebtSortType>((ref) => DebtSortType.oldestDebt);
final homeSearchQueryProvider = StateProvider<String>((ref) => '');

final unpaidSubscribersProvider = FutureProvider<List<Subscriber>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

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

// 8. مزودات التبويب الثاني (الأبراج)
final selectedTowerFilterProvider = StateProvider<String?>((ref) => null);

final subscribersByTowerProvider = FutureProvider<List<Subscriber>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final service = ref.watch(appServiceProvider);
  final selectedTowerId = ref.watch(selectedTowerFilterProvider);
  return await service.getSubscribers(
    towerId: selectedTowerId,
    unpaidOnly: false,
  );
});

// 9. مزود جلب بيانات مشترك واحد محدثة لحظياً
final subscriberByIdProvider =
    FutureProvider.family<Subscriber, String>((ref, subscriberId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('المستخدم غير مسجل الدخول');

  final service = ref.watch(appServiceProvider);
  return await service.getSubscriberById(subscriberId);
});

// 10. مزود جلب سجل الحركات والملاحظات لمشترك معين
final subscriberTransactionsProvider =
    FutureProvider.family<List<SubscriberTransaction>, String>((ref, subscriberId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final service = ref.watch(appServiceProvider);
  return await service.getSubscriberTransactions(subscriberId);
});

// 11. مزودات صندوق النقد (المصاريف والتسديدات مع حد 5 + إظهار المزيد لكل منهما)
final cashBoxExpenseLimitProvider = StateProvider<int>((ref) => 5);
final cashBoxPaymentLimitProvider = StateProvider<int>((ref) => 5);

final cashBoxTransactionsProvider = FutureProvider<List<CashBoxTransaction>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final service = ref.watch(appServiceProvider);
  return await service.getCashBoxTransactions();
});

// 12. مزود قائمة المستخدمين في شاشة الأدمن
final adminUsersListProvider = FutureProvider<List<UserProfile>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final service = ref.watch(appServiceProvider);
  return await service.adminGetAllUsers();
});

// 13. مزود باقات واشتراكات الشركة المزودة
final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final service = ref.watch(appServiceProvider);
  return await service.getSubscriptionPlans();
});

// 14. مزودات الأرباح وحركات التفعيل (مع حد آخر 5 اشتراكات مباعة وزر رؤية المزيد)
final selectedProfitTowerProvider = StateProvider<String?>((ref) => null);
final profitFromDateProvider = StateProvider<DateTime?>((ref) => null);
final profitToDateProvider = StateProvider<DateTime?>((ref) => null);
final profitListLimitProvider = StateProvider<int>((ref) => 5);

final profitTransactionsProvider = FutureProvider<List<SubscriberTransaction>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final service = ref.watch(appServiceProvider);
  return await service.getProfitTransactions();
});

// 15. مزودات التبويب الخامس (التقارير: كم يوزر لكل باقة في الفترة المحددة)
final reportsFromDateProvider = StateProvider<DateTime?>((ref) => null);
final reportsToDateProvider = StateProvider<DateTime?>((ref) => null);

final planSubscriberCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final service = ref.watch(appServiceProvider);
  final fromDate = ref.watch(reportsFromDateProvider);
  final toDate = ref.watch(reportsToDateProvider);

  return await service.getPlanSubscriberCounts(
    fromDate: fromDate,
    toDate: toDate,
  );
});