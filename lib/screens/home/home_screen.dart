import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/app_models.dart';
import '../../providers/app_providers.dart';
import '../../services/app_service.dart';
import '../../widgets/app_dialogs.dart';
import '../towers/subscriber_details_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(financialSummaryProvider);
    final unpaidAsync = ref.watch(unpaidSubscribersProvider);
    final currentLimit = ref.watch(unpaidLimitProvider);
    final currentSort = ref.watch(homeDebtSortProvider);

    final currencyFormatter = NumberFormat('#,##0', 'en_US');
    final dateFormatter = DateFormat('yyyy-MM-dd hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم المالية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: () {
              ref.invalidate(financialSummaryProvider);
              ref.invalidate(unpaidSubscribersProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financialSummaryProvider);
          ref.invalidate(unpaidSubscribersProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. بطاقات الملخص المالي
              summaryAsync.when(
                data: (summary) {
                  final totalDebt = summary['totalDebt'] ?? 0;
                  final totalPaid = summary['totalPaid'] ?? 0;

                  return Row(
                    children: [
                      Expanded(
                        child: _buildFinancialCard(
                          title: 'إجمالي الديون',
                          amount: '${currencyFormatter.format(totalDebt)} د.ع',
                          icon: Icons.trending_down,
                          color: AppColors.debtRed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFinancialCard(
                          title: 'إجمالي النقد',
                          amount: '${currencyFormatter.format(totalPaid)} د.ع',
                          icon: Icons.account_balance_wallet_outlined,
                          color: AppColors.paidGreen,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(child: Text('خطأ في جلب الإحصائيات: $err')),
              ),

              const SizedBox(height: 18),

              // 2. أزرار الإجراءات السريعة
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      icon: const Icon(Icons.cell_tower, color: AppColors.primary),
                      label: const Text(
                        'إضافة برج',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      onPressed: () => AppDialogs.showAddTower(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      label: const Text(
                        'إضافة مشترك',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => AppDialogs.showAddSubscriber(context, ref),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // 3. شريط البحث التنبئي
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'بحث تنبئي بالاسم أو رقم الهاتف...',
                  prefixIcon: const Icon(Icons.search, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(homeSearchQueryProvider.notifier).state = '';
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  ref.read(homeSearchQueryProvider.notifier).state = value;
                  setState(() {});
                },
              ),

              const SizedBox(height: 16),

              // 4. خيارات التصفية (أقدم الديون أو أعلى الديون)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'قائمة الديون:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('أقدم الديون'),
                        selected: currentSort == DebtSortType.oldestDebt,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: currentSort == DebtSortType.oldestDebt ? Colors.white : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) {
                            ref.read(homeDebtSortProvider.notifier).state = DebtSortType.oldestDebt;
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('أعلى الديون'),
                        selected: currentSort == DebtSortType.highestDebt,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: currentSort == DebtSortType.highestDebt ? Colors.white : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) {
                            ref.read(homeDebtSortProvider.notifier).state = DebtSortType.highestDebt;
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. قائمة المشتركين
              unpaidAsync.when(
                data: (subscribers) {
                  if (subscribers.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.done_all, size: 48, color: AppColors.paidGreen),
                          SizedBox(height: 12),
                          Text(
                            'لا توجد ديون مطابقة لبحثك حالياً',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: subscribers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final sub = subscribers[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubscriberDetailsScreen(subscriber: sub),
                                ),
                              );
                            },
                            child: _buildSubscriberCard(
                              context: context,
                              ref: ref,
                              sub: sub,
                              currencyFormatter: currencyFormatter,
                              dateFormatter: dateFormatter,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          ref.read(unpaidLimitProvider.notifier).update((state) => state + 10);
                        },
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                        label: Text(
                          'إظهار 10 مشتركين إضافيين (المعروض حالياً: $currentLimit)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(child: Text('حدث خطأ: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriberCard({
    required BuildContext context,
    required WidgetRef ref,
    required Subscriber sub,
    required NumberFormat currencyFormatter,
    required DateFormat dateFormatter,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      sub.phone,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    if (sub.towerName != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sub.towerName!,
                          style: const TextStyle(fontSize: 11, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 13, color: AppColors.debtRed),
                    const SizedBox(width: 4),
                    Text(
                      'آخر تعديل: ${dateFormatter.format(sub.lastDebtUpdatedAt.toLocal())}',
                      style: const TextStyle(fontSize: 11, color: AppColors.debtRed),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${currencyFormatter.format(sub.debtAmount)} د.ع',
                style: const TextStyle(
                  color: AppColors.debtRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(80, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  backgroundColor: AppColors.secondary,
                ),
                onPressed: () => AppDialogs.showUpdateDebt(context, ref, sub),
                child: const Text('تسديد / تعديل', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}