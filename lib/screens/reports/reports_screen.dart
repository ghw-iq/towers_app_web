import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../providers/app_providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  Future<void> _pickDate({required bool isFromDate}) async {
    final currentFrom = ref.read(reportsFromDateProvider);
    final currentTo = ref.read(reportsToDateProvider);

    final picked = await showDatePicker(
      context: context,
      initialDate: (isFromDate ? currentFrom : currentTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isFromDate ? 'اختر تاريخ البداية (من)' : 'اختر تاريخ النهاية (إلى)',
    );

    if (picked != null) {
      if (isFromDate) {
        ref.read(reportsFromDateProvider.notifier).state = picked;
      } else {
        ref.read(reportsToDateProvider.notifier).state = picked;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromDate = ref.watch(reportsFromDateProvider);
    final toDate = ref.watch(reportsToDateProvider);
    final countsAsync = ref.watch(planSubscriberCountsProvider);
    final shortDateFmt = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير الاشتراكات والمشتركين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: () => ref.invalidate(planSubscriberCountsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(planSubscriberCountsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================= 1. شريط فلترة التاريخ =================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.date_range, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              (fromDate == null && toDate == null)
                                  ? 'الفترة: كافة المشتركين منذ البداية'
                                  : 'الفترة المحددة للتقرير:',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (fromDate != null || toDate != null)
                          InkWell(
                            onTap: () {
                              ref.read(reportsFromDateProvider.notifier).state = null;
                              ref.read(reportsToDateProvider.notifier).state = null;
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.debtRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.close, size: 13, color: AppColors.debtRed),
                                  SizedBox(width: 3),
                                  Text(
                                    'عرض الكل',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.debtRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _pickDate(isFromDate: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: fromDate != null ? AppColors.primary : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      fromDate != null
                                          ? 'من: ${shortDateFmt.format(fromDate)}'
                                          : 'من تاريخ (الكل)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: fromDate != null ? FontWeight.bold : FontWeight.normal,
                                        color: fromDate != null ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _pickDate(isFromDate: false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: toDate != null ? AppColors.primary : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      toDate != null
                                          ? 'إلى: ${shortDateFmt.format(toDate)}'
                                          : 'إلى تاريخ (الكل)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: toDate != null ? FontWeight.bold : FontWeight.normal,
                                        color: toDate != null ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ================= 2. محتوى التقرير والإحصائيات =================
              countsAsync.when(
                data: (counts) {
                  final totalSubscribers = counts.values.fold<int>(0, (sum, val) => sum + val);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // بطاقة إجمالي المشتركين في الفترة
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6D28D9).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'إجمالي المشتركين في الفترة',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'توزيع المشتركين حسب الباقات',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$totalSubscribers يوزر',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'عدد المشتركين (اليوزرات) في كل باقة:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),

                      if (counts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'لا توجد باقات أو مبيعات مسجلة في هذه الفترة',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: counts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, index) {
                            final entry = counts.entries.elementAt(index);
                            final planName = entry.key;
                            final userCount = entry.value;
                            final ratio = totalSubscribers > 0
                                ? (userCount / totalSubscribers)
                                : 0.0;
                            final percentage = (ratio * 100).toStringAsFixed(1);

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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(0xFF6D28D9).withValues(alpha: 0.1),
                                            child: const Icon(
                                              Icons.wifi_tethering,
                                              size: 16,
                                              color: Color(0xFF6D28D9),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            planName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$userCount يوزر ($percentage%)',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // شريط النسبة المئوية للباقة
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 7,
                                      backgroundColor: AppColors.background,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6D28D9)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
                error: (err, _) => Center(child: Text('خطأ في تحميل التقرير: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}