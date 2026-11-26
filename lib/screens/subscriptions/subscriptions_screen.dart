import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/app_models.dart';
import '../../providers/app_providers.dart';

class _PlanInputRow {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  final List<_PlanInputRow> _inputRows = [_PlanInputRow()];
  bool _isSavingPlans = false;

  @override
  void dispose() {
    for (var row in _inputRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addNewEmptyRow() {
    setState(() {
      _inputRows.add(_PlanInputRow());
    });
  }

  void _removeInputRow(int index) {
    if (_inputRows.length <= 1) {
      _inputRows[0].nameController.clear();
      _inputRows[0].priceController.clear();
      setState(() {});
      return;
    }
    setState(() {
      _inputRows[index].dispose();
      _inputRows.removeAt(index);
    });
  }

  Future<void> _saveNewPlans() async {
    final validPlans = <Map<String, dynamic>>[];

    for (int i = _inputRows.length - 1; i >= 0; i--) {
      final name = _inputRows[i].nameController.text.trim();
      final priceText = _inputRows[i].priceController.text.trim();

      if (name.isEmpty && priceText.isEmpty) {
        if (_inputRows.length > 1) {
          _inputRows[i].dispose();
          _inputRows.removeAt(i);
        }
        continue;
      }

      if (name.isEmpty || priceText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إكمال اسم الاشتراك وسعره أو إفراغ الحقلين لحذفه'),
            backgroundColor: AppColors.debtRed,
          ),
        );
        setState(() {});
        return;
      }

      final price = double.tryParse(priceText);
      if (price == null || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('سعر غير صالح للاشتراك "$name"'),
            backgroundColor: AppColors.debtRed,
          ),
        );
        return;
      }

      validPlans.add({'name': name, 'cost_price': price});
    }

    if (validPlans.isEmpty) {
      setState(() {});
      return;
    }

    setState(() => _isSavingPlans = true);
    try {
      await ref.read(appServiceProvider).addSubscriptionPlans(validPlans.reversed.toList());
      ref.invalidate(subscriptionPlansProvider);

      for (var row in _inputRows) {
        row.dispose();
      }
      _inputRows.clear();
      _inputRows.add(_PlanInputRow());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الاشتراكات بنجاح'),
            backgroundColor: AppColors.paidGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.debtRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPlans = false);
    }
  }

  Future<void> _showEditPlanDialog(SubscriptionPlan plan) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: plan.name);
    final priceCtrl = TextEditingController(text: plan.costPrice.toStringAsFixed(0));
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل سعر/اسم الاشتراك'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ملاحظة: تغيير السعر هنا يطبق على الاشتراكات المستقبلية فقط ولا يؤثر على الأرباح والحركات السابقة.',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الاشتراك *'),
                  validator: (v) => AppValidators.validateRequired(v, 'اسم الاشتراك'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'قيمة الاشتراك من الشركة (د.ع) *'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'أدخل السعر';
                    if (double.tryParse(v) == null) return 'رقم غير صالح';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => isLoading = true);
                      try {
                        await ref.read(appServiceProvider).updateSubscriptionPlan(
                              planId: plan.id,
                              name: nameCtrl.text,
                              costPrice: double.parse(priceCtrl.text),
                            );
                        ref.invalidate(subscriptionPlansProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.debtRed),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setState(() => isLoading = false);
                      }
                    },
              child: const Text('حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePlan(SubscriptionPlan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف نوع الاشتراك'),
        content: Text(
          'هل تريد حذف الاشتراك "${plan.name}"؟\n(الحركات والأرباح السابقة المسجلة به ستبقى محفوظة ولن تتأثر).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.debtRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(appServiceProvider).deleteSubscriptionPlan(plan.id);
      ref.invalidate(subscriptionPlansProvider);
    }
  }

  Future<void> _pickDate({required bool isFromDate}) async {
    final currentFrom = ref.read(profitFromDateProvider);
    final currentTo = ref.read(profitToDateProvider);

    final picked = await showDatePicker(
      context: context,
      initialDate: (isFromDate ? currentFrom : currentTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isFromDate ? 'اختر تاريخ البداية (من)' : 'اختر تاريخ النهاية (إلى)',
    );

    if (picked != null) {
      if (isFromDate) {
        ref.read(profitFromDateProvider.notifier).state = picked;
      } else {
        ref.read(profitToDateProvider.notifier).state = picked;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final profitsAsync = ref.watch(profitTransactionsProvider);
    final towersAsync = ref.watch(towersListProvider);
    final selectedTowerId = ref.watch(selectedProfitTowerProvider);
    final fromDate = ref.watch(profitFromDateProvider);
    final toDate = ref.watch(profitToDateProvider);

    final currencyFormatter = NumberFormat('#,##0', 'en_US');
    final dateFormatter = DateFormat('yyyy/MM/dd - hh:mm a');
    final shortDateFmt = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاشتراكات والأرباح'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: () {
              ref.invalidate(subscriptionPlansProvider);
              ref.invalidate(profitTransactionsProvider);
              ref.invalidate(towersListProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(subscriptionPlansProvider);
          ref.invalidate(profitTransactionsProvider);
          ref.invalidate(towersListProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================= القسم 1: باقات الشركة المزودة =================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi_tethering, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'أسعار الاشتراكات من الشركة المزودة',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    plansAsync.when(
                      data: (plans) {
                        if (plans.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              'أضف باقة الاشتراك الأولى بالأسفل (مثل: ايرثلنك لايت / فايبر):',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            ...plans.map((plan) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            plan.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            'كلفة الشركة: ${currencyFormatter.format(plan.costPrice)} د.ع',
                                            style: const TextStyle(fontSize: 12, color: AppColors.primary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'تعديل السعر/الاسم',
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.secondary),
                                      onPressed: () => _showEditPlanDialog(plan),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف الاشتراك',
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debtRed),
                                      onPressed: () => _confirmDeletePlan(plan),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 18),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('خطأ: $e'),
                    ),

                    ...List.generate(_inputRows.length, (index) {
                      final row = _inputRows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row.nameController,
                                decoration: const InputDecoration(
                                  labelText: 'اسم الاشتراك',
                                  hintText: 'اسم باقة الشركة',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'قيمة الشركة',
                                  hintText: 'د.ع',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            if (_inputRows.length > 1 ||
                                row.nameController.text.isNotEmpty ||
                                row.priceController.text.isNotEmpty)
                              IconButton(
                                tooltip: 'إزالة الصف',
                                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                                onPressed: () => _removeInputRow(index),
                              ),
                          ],
                        ),
                      );
                    }),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('إضافة اسم اشتراك جديد', style: TextStyle(fontSize: 12)),
                            onPressed: _addNewEmptyRow,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              backgroundColor: AppColors.secondary,
                            ),
                            onPressed: _isSavingPlans ? null : _saveNewPlans,
                            child: _isSavingPlans
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('حفظ الباقات', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ================= القسم 2: تقارير الأرباح والمبيعات مع فلتر التاريخ =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تقارير الأرباح والمبيعات',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  towersAsync.when(
                    data: (towers) {
                      return DropdownButton<String?>(
                        value: selectedTowerId,
                        hint: const Text('كافة الأبراج'),
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('كافة الأبراج', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ...towers.map((t) {
                            return DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text(t.name),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          ref.read(selectedProfitTowerProvider.notifier).state = val;
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // شريط فلترة التاريخ (من تاريخ -> إلى تاريخ)
              Container(
                padding: const EdgeInsets.all(12),
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
                            const Icon(Icons.date_range, size: 17, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              (fromDate == null && toDate == null)
                                  ? 'الفترة: كل الأرباح من تاريخ التسجيل'
                                  : 'فلترة الأرباح حسب التاريخ:',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (fromDate != null || toDate != null)
                          InkWell(
                            onTap: () {
                              ref.read(profitFromDateProvider.notifier).state = null;
                              ref.read(profitToDateProvider.notifier).state = null;
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _pickDate(isFromDate: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              const SizedBox(height: 12),

              profitsAsync.when(
                data: (allProfits) {
                  // تطبيق فلترة البرج + فلترة التاريخ (من - إلى)
                  final filtered = allProfits.where((tx) {
                    if (selectedTowerId != null && tx.towerId != selectedTowerId) {
                      return false;
                    }
                    final localDate = tx.createdAt.toLocal();

                    if (fromDate != null) {
                      final start = DateTime(fromDate.year, fromDate.month, fromDate.day, 0, 0, 0);
                      if (localDate.isBefore(start)) return false;
                    }
                    if (toDate != null) {
                      final end = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59, 999);
                      if (localDate.isAfter(end)) return false;
                    }
                    return true;
                  }).toList();

                  double cashProfit = 0;
                  double creditProfit = 0;
                  double totalSales = 0;
                  double totalCost = 0;

                  final Map<String, Map<String, double>> towerProfitsMap = {};

                  for (var tx in filtered) {
                    final prof = tx.profit ?? 0;
                    final sell = tx.sellingPrice ?? 0;
                    final cost = tx.costPrice ?? 0;

                    totalSales += sell;
                    totalCost += cost;

                    if (tx.paymentMode == 'cash') {
                      cashProfit += prof;
                    } else {
                      creditProfit += prof;
                    }

                    final tName = tx.towerName ?? 'برج غير محدد';
                    towerProfitsMap.putIfAbsent(tName, () => {'cash': 0, 'credit': 0, 'total': 0});
                    if (tx.paymentMode == 'cash') {
                      towerProfitsMap[tName]!['cash'] = towerProfitsMap[tName]!['cash']! + prof;
                    } else {
                      towerProfitsMap[tName]!['credit'] = towerProfitsMap[tName]!['credit']! + prof;
                    }
                    towerProfitsMap[tName]!['total'] = towerProfitsMap[tName]!['total']! + prof;
                  }

                  final totalProfit = cashProfit + creditProfit;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildProfitCard(
                              title: 'أرباح النقد (الكاش)',
                              amount: '${currencyFormatter.format(cashProfit)} د.ع',
                              icon: Icons.payments_outlined,
                              color: AppColors.paidGreen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildProfitCard(
                              title: 'أرباح الديون (الآجل)',
                              amount: '${currencyFormatter.format(creditProfit)} د.ع',
                              icon: Icons.schedule,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'صافي الربح للفترة:',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                Text(
                                  '${currencyFormatter.format(totalProfit)} د.ع',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'إجمالي البيع: ${currencyFormatter.format(totalSales)} د.ع',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                Text(
                                  'كلفة الشركة: ${currencyFormatter.format(totalCost)} د.ع',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (selectedTowerId == null && towerProfitsMap.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const Text(
                          'ملخص أرباح كل برج:',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...towerProfitsMap.entries.map((entry) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.cell_tower, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      entry.key,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'الربح: ${currencyFormatter.format(entry.value['total'])} د.ع',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'نقد: ${currencyFormatter.format(entry.value['cash'])} | آجل: ${currencyFormatter.format(entry.value['credit'])}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'سجل الاشتراكات المباعة وأرباحها:',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '(${filtered.length} عملية)',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (filtered.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'لا توجد مبيعات اشتراكات في هذه الفترة',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final item = filtered[idx];
                            final isCash = item.paymentMode == 'cash';
                            final badgeColor = isCash ? AppColors.paidGreen : const Color(0xFFD97706);

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
                                      Expanded(
                                        child: Text(
                                          '${item.subscriberName ?? 'مشترك'} (${item.towerName ?? ''})',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isCash ? 'نقد للصندوق' : 'آجل للدين',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'الباقة: ${item.planName ?? '-'}',
                                        style: const TextStyle(fontSize: 13, color: AppColors.primary),
                                      ),
                                      Text(
                                        'الربح: +${currencyFormatter.format(item.profit ?? 0)} د.ع',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: (item.profit ?? 0) >= 0 ? AppColors.paidGreen : AppColors.debtRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'كلفة الشركة: ${currencyFormatter.format(item.costPrice ?? 0)} | البيع: ${currencyFormatter.format(item.sellingPrice ?? 0)}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        dateFormatter.format(item.createdAt.toLocal()),
                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('خطأ: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfitCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}