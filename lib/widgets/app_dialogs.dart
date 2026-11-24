import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';

class AppDialogs {
  /// 1. نافذة إضافة برج جديد
  static Future<void> showAddTower(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    bool isLoading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cell_tower, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'إضافة برج جديد',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم البرج *',
                    hintText: 'مثال: برج المنصور 1',
                  ),
                  validator: (v) => AppValidators.validateRequired(v, 'اسم البرج'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'موقع البرج (اختياري)',
                    hintText: 'مثال: شارع 14 رمضان',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => isLoading = true);
                          try {
                            await ref.read(appServiceProvider).addTower(
                                  name: nameController.text,
                                  location: locationController.text.isEmpty
                                      ? null
                                      : locationController.text,
                                );
                            ref.invalidate(towersListProvider);
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('خطأ: $e'),
                                  backgroundColor: AppColors.debtRed,
                                ),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setState(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('حفظ البرج'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 2. نافذة إضافة مشترك جديد
  static Future<void> showAddSubscriber(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final debtController = TextEditingController(text: '0');
    String? selectedTowerId;
    bool isLoading = false;

    final towersAsync = ref.read(towersListProvider);
    final towers = towersAsync.value ?? [];

    if (towers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة برج أولاً قبل إضافة المشتركين'),
          backgroundColor: AppColors.debtRed,
        ),
      );
      return;
    }

    selectedTowerId = towers.first.id;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_add, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'إضافة مشترك جديد',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedTowerId,
                    decoration: const InputDecoration(labelText: 'البرج التابع له *'),
                    items: towers.map((t) {
                      return DropdownMenuItem(value: t.id, child: Text(t.name));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedTowerId = val),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المشترك *',
                      hintText: 'الاسم الثلاثي أو اللقب',
                    ),
                    validator: (v) => AppValidators.validateRequired(v, 'اسم المشترك'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف *',
                      hintText: '07xxxxxxxxx',
                    ),
                    validator: AppValidators.validatePhone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: debtController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'الديون السابقة (د.ع)',
                      hintText: '0',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'يرجى إدخال المبلغ (أو 0)';
                      if (double.tryParse(v) == null) return 'أدخل رقماً صحيحاً';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setState(() => isLoading = true);
                            try {
                              final debt = double.tryParse(debtController.text) ?? 0.0;
                              await ref.read(appServiceProvider).addSubscriber(
                                    towerId: selectedTowerId!,
                                    fullName: nameController.text,
                                    phone: phoneController.text,
                                    initialDebt: debt,
                                  );

                              ref.invalidate(unpaidSubscribersProvider);
                              ref.invalidate(financialSummaryProvider);
                              ref.invalidate(subscribersByTowerProvider);

                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('خطأ: $e'),
                                    backgroundColor: AppColors.debtRed,
                                  ),
                                );
                              }
                            } finally {
                              if (ctx.mounted) setState(() => isLoading = false);
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('حفظ المشترك'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 3. نافذة تسديد أو زيادة الدين مع إضافة ملاحظات
  static Future<void> showUpdateDebt(
    BuildContext context,
    WidgetRef ref,
    Subscriber subscriber,
  ) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    bool isPayment = true; // true: تسديد دفعة، false: إضافة دين جديد
    bool isLoading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final enteredAmount = double.tryParse(amountController.text) ?? 0.0;
          final previewDebt = isPayment
              ? (subscriber.debtAmount - enteredAmount).clamp(0.0, double.infinity)
              : (subscriber.debtAmount + enteredAmount);

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPayment ? Icons.receipt_long : Icons.add_circle_outline,
                          color: isPayment ? AppColors.secondary : AppColors.debtRed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'حركة مالية: ${subscriber.fullName}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // اختيار نوع الحركة (تسديد أو إضافة دين)
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('تسديد واصل'),
                          icon: Icon(Icons.south_west),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('إضافة دين'),
                          icon: Icon(Icons.north_east),
                        ),
                      ],
                      selected: {isPayment},
                      onSelectionChanged: (set) {
                        setState(() => isPayment = set.first);
                      },
                    ),
                    const SizedBox(height: 14),

                    // بطاقة توضيح الدين الحالي والمتوقع بعد الحركة
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPayment
                            ? AppColors.paidGreen.withOpacity(0.08)
                            : AppColors.debtRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الدين الحالي', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text(
                                '${subscriber.debtAmount.toStringAsFixed(0)} د.ع',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('الدين بعد الحركة', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text(
                                '${previewDebt.toStringAsFixed(0)} د.ع',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isPayment ? AppColors.paidGreen : AppColors.debtRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // حقل المبلغ
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isPayment ? 'مبلغ التسديد الواصل (د.ع) *' : 'مبلغ الدين الجديد (د.ع) *',
                        hintText: 'مثال: 25000',
                        prefixIcon: Icon(isPayment ? Icons.south_west : Icons.north_east),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) return 'أدخل مبلغاً صالحاً أكبر من 0';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // حقل الملاحظات
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات (للمراجعة مستقبلاً)',
                        hintText: 'مثال: تسديد كاش، اشتراك شهر جديد، جهاز راوتر...',
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPayment ? AppColors.secondary : AppColors.debtRed,
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() => isLoading = true);
                              try {
                                final changeAmount = double.parse(amountController.text);
                                final newDebt = isPayment
                                    ? (subscriber.debtAmount - changeAmount).clamp(0.0, double.infinity)
                                    : (subscriber.debtAmount + changeAmount);

                                await ref.read(appServiceProvider).updateSubscriberDebt(
                                      subscriberId: subscriber.id,
                                      newDebtAmount: newDebt,
                                      transactionType: isPayment ? 'payment' : 'debt_addition',
                                      changeAmount: changeAmount,
                                      notes: notesController.text,
                                    );

                                ref.invalidate(unpaidSubscribersProvider);
                                ref.invalidate(financialSummaryProvider);
                                ref.invalidate(subscribersByTowerProvider);
                                ref.invalidate(subscriberTransactionsProvider(subscriber.id));

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
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(isPayment ? 'تأكيد التسديد' : 'تأكيد إضافة الدين'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 4. رسالة تأكيد حذف البرج
  static Future<void> showDeleteTowerConfirm(BuildContext context, WidgetRef ref, Tower tower) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.debtRed),
            SizedBox(width: 8),
            Text('حذف البرج'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف البرج "${tower.name}"؟\nتنبيه: سيتم حذف كافة المشتركين والديون التابعة له نهائياً!',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.debtRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(appServiceProvider).deleteTower(tower.id);
      ref.read(selectedTowerFilterProvider.notifier).state = null;
      ref.invalidate(towersListProvider);
      ref.invalidate(subscribersByTowerProvider);
      ref.invalidate(financialSummaryProvider);
      ref.invalidate(unpaidSubscribersProvider);
    }
  }

  /// 5. رسالة تأكيد حذف المشترك
  static Future<void> showDeleteSubscriberConfirm(BuildContext context, WidgetRef ref, Subscriber sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_remove, color: AppColors.debtRed),
            SizedBox(width: 8),
            Text('حذف المشترك'),
          ],
        ),
        content: Text('هل أنت متأكد من رغبتك في حذف المشترك "${sub.fullName}" وسجل ديونه وحركاته؟'),
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
      await ref.read(appServiceProvider).deleteSubscriber(sub.id);
      ref.invalidate(subscribersByTowerProvider);
      ref.invalidate(financialSummaryProvider);
      ref.invalidate(unpaidSubscribersProvider);
    }
  }
}