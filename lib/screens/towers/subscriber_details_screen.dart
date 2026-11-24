import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/app_models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/app_dialogs.dart';

class SubscriberDetailsScreen extends ConsumerWidget {
  final Subscriber subscriber;

  const SubscriberDetailsScreen({super.key, required this.subscriber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(subscriberTransactionsProvider(subscriber.id));
    final currencyFormatter = NumberFormat('#,##0', 'en_US');
    final dateFormatter = DateFormat('yyyy/MM/dd - hh:mm a');

    final hasDebt = subscriber.debtAmount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل وسجل المشترك'),
        actions: [
          IconButton(
            tooltip: 'حذف المشترك',
            icon: const Icon(Icons.delete_outline, color: AppColors.debtRed),
            onPressed: () async {
              await AppDialogs.showDeleteSubscriberConfirm(context, ref, subscriber);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(subscriberTransactionsProvider(subscriber.id));
          ref.invalidate(subscribersByTowerProvider);
          ref.invalidate(unpaidSubscribersProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. بطاقة معلومات المشترك والرصيد
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: hasDebt
                          ? AppColors.debtRed.withOpacity(0.1)
                          : AppColors.paidGreen.withOpacity(0.1),
                      child: Icon(
                        hasDebt ? Icons.person_outline : Icons.check_circle_outline,
                        size: 38,
                        color: hasDebt ? AppColors.debtRed : AppColors.paidGreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subscriber.fullName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subscriber.phone,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    if (subscriber.towerName != null) ...[
                      const SizedBox(height: 6),
                      Chip(
                        avatar: const Icon(Icons.cell_tower, size: 16, color: AppColors.primary),
                        label: Text(subscriber.towerName!),
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        side: BorderSide.none,
                      ),
                    ],
                    const Divider(height: 24, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('الدين المتبقي', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              '${currencyFormatter.format(subscriber.debtAmount)} د.ع',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: hasDebt ? AppColors.debtRed : AppColors.paidGreen,
                              ),
                            ),
                          ],
                        ),
                        Container(height: 30, width: 1, color: AppColors.border),
                        Column(
                          children: [
                            const Text('إجمالي الواصل', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              '${currencyFormatter.format(subscriber.paidAmount)} د.ع',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.paidGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // زر إضافة حركة مالية سريعة (تسديد أو زيادة دين)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.add_card, color: Colors.white),
                label: const Text('تسجيل حركة مالية جديدة (تسديد / دين)', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => AppDialogs.showUpdateDebt(context, ref, subscriber),
              ),

              const SizedBox(height: 24),

              // 2. سجل الحركات والملاحظات
              const Row(
                children: [
                  Icon(Icons.history, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'سجل الحركات والملاحظات',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              transactionsAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text(
                          'لا توجد حركات مسجلة بعد لهذا المشترك',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final item = transactions[index];
                      final isPayment = item.type == 'payment';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isPayment
                                      ? AppColors.paidGreen.withOpacity(0.12)
                                      : AppColors.debtRed.withOpacity(0.12),
                                  child: Icon(
                                    isPayment ? Icons.south_west : Icons.north_east,
                                    color: isPayment ? AppColors.paidGreen : AppColors.debtRed,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isPayment ? 'تسديد دفعة واصلة' : 'إضافة دين جديد',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isPayment ? AppColors.paidGreen : AppColors.debtRed,
                                        ),
                                      ),
                                      Text(
                                        dateFormatter.format(item.createdAt.toLocal()),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isPayment ? "-" : "+"}${currencyFormatter.format(item.amount)} د.ع',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isPayment ? AppColors.paidGreen : AppColors.debtRed,
                                      ),
                                    ),
                                    Text(
                                      'المتبقي: ${currencyFormatter.format(item.remainingDebt)} د.ع',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // الملاحظة المدونة للحركة للمراجعة مستقبلاً
                            if (item.notes != null && item.notes!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.edit_note, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.notes!,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(child: Text('خطأ في جلب الحركات: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}