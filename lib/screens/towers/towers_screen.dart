import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/app_models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/app_dialogs.dart';
import 'subscriber_details_screen.dart';

class TowersScreen extends ConsumerStatefulWidget {
  const TowersScreen({super.key});

  @override
  ConsumerState<TowersScreen> createState() => _TowersScreenState();
}

class _TowersScreenState extends ConsumerState<TowersScreen> {
  final TextEditingController _towerController = TextEditingController();

  @override
  void dispose() {
    _towerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final towersAsync = ref.watch(towersListProvider);
    final selectedTowerId = ref.watch(selectedTowerFilterProvider);
    final subscribersAsync = ref.watch(subscribersByTowerProvider);

    final currencyFormatter = NumberFormat('#,##0', 'en_US');
    final dateFormatter = DateFormat('yyyy-MM-dd hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأبراج والمشتركين'),
        actions: [
          IconButton(
            tooltip: 'إضافة برج جديد',
            icon: const Icon(Icons.add_business, size: 24),
            onPressed: () => AppDialogs.showAddTower(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(towersListProvider);
          ref.invalidate(subscribersByTowerProvider);
        },
        child: Column(
          children: [
            // 1. حقل منسدل ذكي وتنبئي لاختيار البرج
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: towersAsync.when(
                data: (towers) {
                  if (towers.isEmpty) {
                    return Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'لا توجد أبراج مضافة حالياً',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => AppDialogs.showAddTower(context, ref),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إضافة برج'),
                        ),
                      ],
                    );
                  }

                  // إيجاد البرج المحدد حالياً
                  Tower? currentTower;
                  try {
                    currentTower = towers.firstWhere((t) => t.id == selectedTowerId);
                  } catch (_) {
                    // افتراضياً اختيار أول برج إذا لم يكن محدد
                    if (selectedTowerId == null && towers.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.read(selectedTowerFilterProvider.notifier).state = towers.first.id;
                        _towerController.text = towers.first.name;
                      });
                      currentTower = towers.first;
                    }
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: DropdownMenu<Tower>(
                          controller: _towerController,
                          enableFilter: true, // يتيح الكتابة والفلترة التنبئية
                          requestFocusOnTap: true,
                          width: MediaQuery.of(context).size.width - 80,
                          leadingIcon: const Icon(Icons.cell_tower, color: AppColors.primary),
                          label: const Text('ابحث أو اختر البرج *'),
                          initialSelection: currentTower,
                          dropdownMenuEntries: towers.map((tower) {
                            return DropdownMenuEntry<Tower>(
                              value: tower,
                              label: tower.name,
                              leadingIcon: const Icon(Icons.cell_tower, size: 18),
                            );
                          }).toList(),
                          onSelected: (Tower? tower) {
                            if (tower != null) {
                              ref.read(selectedTowerFilterProvider.notifier).state = tower.id;
                            }
                          },
                        ),
                      ),
                      // زر حذف البرج المحدد مع رسالة تأكيد
                      if (currentTower != null)
                        IconButton(
                          tooltip: 'حذف هذا البرج',
                          icon: const Icon(Icons.delete_outline, color: AppColors.debtRed),
                          onPressed: () => AppDialogs.showDeleteTowerConfirm(context, ref, currentTower!),
                        ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text('خطأ: $e'),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // 2. قائمة المشتركين في البرج المختار
            Expanded(
              child: subscribersAsync.when(
                data: (subscribers) {
                  if (subscribers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'لا يوجد مشتركين في هذا البرج',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(minimumSize: const Size(180, 42)),
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('إضافة مشترك جديد'),
                            onPressed: () => AppDialogs.showAddSubscriber(context, ref),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: subscribers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final sub = subscribers[index];
                      final hasDebt = sub.debtAmount > 0;

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
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: hasDebt ? AppColors.debtRed.withOpacity(0.3) : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: hasDebt
                                    ? AppColors.debtRed.withOpacity(0.1)
                                    : AppColors.paidGreen.withOpacity(0.1),
                                child: Icon(
                                  hasDebt ? Icons.warning_amber_rounded : Icons.done_all,
                                  color: hasDebt ? AppColors.debtRed : AppColors.paidGreen,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sub.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      sub.phone,
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'آخر حركة: ${dateFormatter.format(sub.lastDebtUpdatedAt.toLocal())}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${currencyFormatter.format(sub.debtAmount)} د.ع',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: hasDebt ? AppColors.debtRed : AppColors.paidGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      // زر التسديد / التعديل
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(60, 30),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          backgroundColor: AppColors.secondary,
                                        ),
                                        onPressed: () => AppDialogs.showUpdateDebt(context, ref, sub),
                                        child: const Text('تسديد', style: TextStyle(fontSize: 11)),
                                      ),
                                      const SizedBox(width: 4),
                                      // زر حذف المشترك مع تأكيد
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textSecondary),
                                        onPressed: () => AppDialogs.showDeleteSubscriberConfirm(context, ref, sub),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('خطأ: $err')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('مشترك جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => AppDialogs.showAddSubscriber(context, ref),
      ),
    );
  }
}