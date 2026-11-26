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

  /// 2. نافذة إضافة مشترك جديد (مع منع تكرار الرقم وإظهار رسالة واضحة)
  static Future<void> showAddSubscriber(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final debtController = TextEditingController(text: '0');
    final sellingPriceController = TextEditingController();

    String? selectedTowerId;
    SubscriptionPlan? selectedPlan;
    String paymentMode = 'credit';
    String? errorMessage;
    bool isLoading = false;

    final towers = ref.read(towersListProvider).value ?? [];
    final plans = ref.read(subscriptionPlansProvider).value ?? [];

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
        builder: (ctx, setState) {
          final sellingPrice = double.tryParse(sellingPriceController.text) ?? 0.0;
          final expectedProfit =
              selectedPlan != null ? (sellingPrice - selectedPlan!.costPrice) : 0.0;

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
                      initialValue: selectedTowerId,
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
                      onChanged: (_) {
                        if (errorMessage != null) {
                          setState(() => errorMessage = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<SubscriptionPlan?>(
                      initialValue: selectedPlan,
                      decoration: const InputDecoration(
                        labelText: 'نوع الاشتراك (الباقة)',
                        prefixIcon: Icon(Icons.wifi_tethering),
                      ),
                      items: [
                        const DropdownMenuItem<SubscriptionPlan?>(
                          value: null,
                          child: Text('بدون باقة (دين سابق فقط)'),
                        ),
                        ...plans.map((p) {
                          return DropdownMenuItem<SubscriptionPlan?>(
                            value: p,
                            child: Text('${p.name} (كلفة: ${p.costPrice.toStringAsFixed(0)} د.ع)'),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          selectedPlan = val;
                          if (val == null) sellingPriceController.clear();
                        });
                      },
                    ),

                    if (selectedPlan != null) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: sellingPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'بكم بيع الاشتراك للمشترك؟ (د.ع) *',
                          hintText: 'مثال: 35000',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                        validator: (v) {
                          if (selectedPlan == null) return null;
                          if (v == null || v.trim().isEmpty) return 'يرجى إدخال سعر البيع';
                          final val = double.tryParse(v);
                          if (val == null || val <= 0) return 'أدخل سعراً صحيحاً أكبر من 0';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: expectedProfit >= 0
                              ? AppColors.paidGreen.withValues(alpha: 0.08)
                              : AppColors.debtRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'كلفة الشركة: ${selectedPlan!.costPrice.toStringAsFixed(0)} د.ع',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              'الربح: ${expectedProfit.toStringAsFixed(0)} د.ع',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: expectedProfit >= 0 ? AppColors.paidGreen : AppColors.debtRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'credit',
                            label: Text('آجل (يضاف للدين)'),
                            icon: Icon(Icons.schedule),
                          ),
                          ButtonSegment(
                            value: 'cash',
                            label: Text('نقد (للصندوق)'),
                            icon: Icon(Icons.payments_outlined),
                          ),
                        ],
                        selected: {paymentMode},
                        onSelectionChanged: (set) {
                          setState(() => paymentMode = set.first);
                        },
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: debtController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: selectedPlan != null
                            ? 'ديون سابقة إضافية (اختياري - د.ع)'
                            : 'الديون السابقة (د.ع)',
                        hintText: '0',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'يرجى إدخال المبلغ (أو 0)';
                        if (double.tryParse(v) == null) return 'أدخل رقماً صحيحاً';
                        return null;
                      },
                    ),

                    // رسالة الخطأ الواضحة داخل النافذة (مثلاً عند تكرار رقم الهاتف)
                    if (errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.debtRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.debtRed.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.debtRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.debtRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() {
                                isLoading = true;
                                errorMessage = null;
                              });
                              try {
                                final debt = double.tryParse(debtController.text) ?? 0.0;
                                final sell = selectedPlan != null
                                    ? double.tryParse(sellingPriceController.text)
                                    : null;

                                await ref.read(appServiceProvider).addSubscriber(
                                      towerId: selectedTowerId!,
                                      fullName: nameController.text,
                                      phone: phoneController.text,
                                      initialDebt: debt,
                                      plan: selectedPlan,
                                      sellingPrice: sell,
                                      paymentMode: paymentMode,
                                    );

                                ref.invalidate(unpaidSubscribersProvider);
                                ref.invalidate(financialSummaryProvider);
                                ref.invalidate(subscribersByTowerProvider);
                                ref.invalidate(profitTransactionsProvider);

                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (ctx.mounted) {
                                  setState(() {
                                    errorMessage = e.toString().replaceFirst('Exception: ', '');
                                  });
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
          );
        },
      ),
    );
  }

  /// 3. نافذة تسديد دين أو تفعيل/تجديد اشتراك أو إضافة دين مع الملاحظات
  static Future<void> showUpdateDebt(
    BuildContext context,
    WidgetRef ref,
    Subscriber subscriber,
  ) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    bool isPayment = true;
    SubscriptionPlan? selectedPlan;
    String paymentMode = 'credit';
    bool isLoading = false;

    final plans = ref.read(subscriptionPlansProvider).value ?? [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final enteredAmount = double.tryParse(amountController.text) ?? 0.0;
          final bool isCashPlan = !isPayment && selectedPlan != null && paymentMode == 'cash';
          final previewDebt = isPayment
              ? (subscriber.debtAmount - enteredAmount).clamp(0.0, double.infinity)
              : (isCashPlan ? subscriber.debtAmount : (subscriber.debtAmount + enteredAmount));
          final expectedProfit =
              (!isPayment && selectedPlan != null) ? (enteredAmount - selectedPlan!.costPrice) : 0.0;

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
                          color: isPayment ? AppColors.secondary : AppColors.primary,
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

                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('تسديد واصل'),
                          icon: Icon(Icons.south_west),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('اشتراك / دين'),
                          icon: Icon(Icons.north_east),
                        ),
                      ],
                      selected: {isPayment},
                      onSelectionChanged: (set) {
                        setState(() {
                          isPayment = set.first;
                          if (isPayment) selectedPlan = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    if (!isPayment) ...[
                      DropdownButtonFormField<SubscriptionPlan?>(
                        initialValue: selectedPlan,
                        decoration: const InputDecoration(
                          labelText: 'نوع الاشتراك / العملية',
                          prefixIcon: Icon(Icons.wifi_tethering),
                        ),
                        items: [
                          const DropdownMenuItem<SubscriptionPlan?>(
                            value: null,
                            child: Text('دين يدوي (بدون باقة)'),
                          ),
                          ...plans.map((p) {
                            return DropdownMenuItem<SubscriptionPlan?>(
                              value: p,
                              child: Text('${p.name} (كلفة: ${p.costPrice.toStringAsFixed(0)} د.ع)'),
                            );
                          }),
                        ],
                        onChanged: (val) => setState(() => selectedPlan = val),
                      ),
                      const SizedBox(height: 12),
                      if (selectedPlan != null) ...[
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'credit',
                              label: Text('آجل (للدين)'),
                              icon: Icon(Icons.schedule),
                            ),
                            ButtonSegment(
                              value: 'cash',
                              label: Text('نقد (للصندوق)'),
                              icon: Icon(Icons.payments_outlined),
                            ),
                          ],
                          selected: {paymentMode},
                          onSelectionChanged: (set) => setState(() => paymentMode = set.first),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isPayment || isCashPlan)
                            ? AppColors.paidGreen.withValues(alpha: 0.08)
                            : AppColors.debtRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('الدين الحالي',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                                  Text(
                                    isCashPlan ? 'يُضاف لصندوق النقد' : 'الدين بعد الحركة',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    isCashPlan
                                        ? '+ ${enteredAmount.toStringAsFixed(0)} د.ع'
                                        : '${previewDebt.toStringAsFixed(0)} د.ع',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: (isPayment || isCashPlan)
                                          ? AppColors.paidGreen
                                          : AppColors.debtRed,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (!isPayment && selectedPlan != null) ...[
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'كلفة الشركة: ${selectedPlan!.costPrice.toStringAsFixed(0)} د.ع',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                Text(
                                  'صافي الربح: ${expectedProfit.toStringAsFixed(0)} د.ع',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: expectedProfit >= 0 ? AppColors.paidGreen : AppColors.debtRed,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isPayment
                            ? 'مبلغ التسديد الواصل (د.ع) *'
                            : (selectedPlan != null
                                ? 'بكم بيع الاشتراك للمشترك؟ (د.ع) *'
                                : 'مبلغ الدين الجديد (د.ع) *'),
                        hintText: 'مثال: 35000',
                        prefixIcon: Icon(
                          (isPayment || isCashPlan) ? Icons.south_west : Icons.north_east,
                        ),
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

                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات (للمراجعة مستقبلاً)',
                        hintText: 'مثال: اشتراك شهر 12، تسديد كاش...',
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (isPayment || isCashPlan)
                            ? AppColors.secondary
                            : AppColors.debtRed,
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() => isLoading = true);
                              try {
                                final changeAmount = double.parse(amountController.text);
                                String txType;
                                double newDebt;

                                if (isPayment) {
                                  txType = 'payment';
                                  newDebt = (subscriber.debtAmount - changeAmount)
                                      .clamp(0.0, double.infinity);
                                } else if (selectedPlan != null && paymentMode == 'cash') {
                                  txType = 'cash_subscription';
                                  newDebt = subscriber.debtAmount;
                                } else {
                                  txType = 'debt_addition';
                                  newDebt = subscriber.debtAmount + changeAmount;
                                }

                                String? finalNotes = notesController.text.trim();
                                if (!isPayment && selectedPlan != null && finalNotes.isEmpty) {
                                  finalNotes = paymentMode == 'cash'
                                      ? 'تفعيل اشتراك (${selectedPlan!.name}) - نقداً'
                                      : 'تفعيل اشتراك (${selectedPlan!.name}) - آجل';
                                }

                                await ref.read(appServiceProvider).updateSubscriberDebt(
                                      subscriberId: subscriber.id,
                                      newDebtAmount: newDebt,
                                      transactionType: txType,
                                      changeAmount: changeAmount,
                                      notes: finalNotes,
                                      plan: !isPayment ? selectedPlan : null,
                                      sellingPrice: (!isPayment && selectedPlan != null)
                                          ? changeAmount
                                          : null,
                                      paymentMode:
                                          (!isPayment && selectedPlan != null) ? paymentMode : null,
                                    );

                                ref.invalidate(unpaidSubscribersProvider);
                                ref.invalidate(financialSummaryProvider);
                                ref.invalidate(subscribersByTowerProvider);
                                ref.invalidate(subscriberTransactionsProvider(subscriber.id));
                                ref.invalidate(profitTransactionsProvider);

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
                          : Text(isPayment
                              ? 'تأكيد التسديد'
                              : (isCashPlan ? 'تفعيل نقداً وإضافة للصندوق' : 'تأكيد وإضافة للدين')),
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
      ref.invalidate(profitTransactionsProvider);
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
      ref.invalidate(profitTransactionsProvider);
    }
  }
}