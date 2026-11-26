import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/app_models.dart';
import '../../providers/app_providers.dart';

class CashBoxScreen extends ConsumerWidget {
  const CashBoxScreen({super.key});

  Future<void> _showNewCashDialog(
    BuildContext context,
    WidgetRef ref,
    double availableCash, {
    required bool isExpense, // true = مصاريف (رواتب وغيرها) | false = تسديد عادي
  }) async {
    if (availableCash <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رصيد صندوق النقد صفر، لا يوجد نقد متاح للصرف!'),
          backgroundColor: AppColors.debtRed,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final currencyFmt = NumberFormat('#,##0', 'en_US');
    bool isLoading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final entered = double.tryParse(amountController.text.trim()) ?? 0.0;
          final remaining = availableCash - entered;
          final isExceeded = entered > availableCash;

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
                          isExpense ? Icons.work_history_outlined : Icons.payments_outlined,
                          color: isExpense ? AppColors.debtRed : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isExpense ? 'تسجيل مصاريف (رواتب / تشغيل)' : 'تسديد من صندوق النقد',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (isExpense)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.debtRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.debtRed.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppColors.debtRed),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'تنبيه: سيتم استقطاع هذا المبلغ من صندوق النقد ويُخصم تلقائياً من صافي الأرباح.',
                                style: TextStyle(fontSize: 11, color: AppColors.debtRed),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isExceeded
                            ? AppColors.debtRed.withValues(alpha: 0.08)
                            : AppColors.paidGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المتوفر حالياً في الصندوق:'),
                              Text(
                                '${currencyFmt.format(availableCash)} د.ع',
                                style: const TextStyle(
                                  color: AppColors.paidGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          if (entered > 0) ...[
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('المتبقي بعد الصرف:', style: TextStyle(fontSize: 12)),
                                Text(
                                  isExceeded
                                      ? 'يتجاوز الرصيد المتاح!'
                                      : '${currencyFmt.format(remaining)} د.ع',
                                  style: TextStyle(
                                    color: isExceeded ? AppColors.debtRed : AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: isExpense
                            ? 'بند المصروف (مثال: راتب مهندس، وقود، إيجار...) *'
                            : 'قيمة التسديد (الوصف / الجهة) *',
                        prefixIcon: Icon(isExpense ? Icons.badge_outlined : Icons.description_outlined),
                      ),
                      validator: (v) => AppValidators.validateRequired(
                        v,
                        isExpense ? 'بند المصروف' : 'قيمة التسديد',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ (د.ع) *',
                        hintText: 'مثال: 50000',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                        final val = double.tryParse(v.trim());
                        if (val == null || val <= 0) return 'يرجى إدخال مبلغ صحيح أكبر من 0';
                        if (val > availableCash) {
                          return 'لا يمكن تجاوز الرصيد المتاح (${currencyFmt.format(availableCash)} د.ع)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات إضافية (اختياري)',
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isExpense ? AppColors.debtRed : AppColors.secondary,
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() => isLoading = true);
                              try {
                                final amount = double.parse(amountController.text.trim());
                                await ref.read(appServiceProvider).addCashBoxPayment(
                                      title: titleController.text,
                                      amount: amount,
                                      category: isExpense ? 'expense' : 'payment',
                                      notes: notesController.text,
                                    );

                                ref.invalidate(cashBoxTransactionsProvider);
                                ref.invalidate(financialSummaryProvider);

                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('حدث خطأ: $e'),
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
                          : Text(isExpense ? 'تأكيد وحفظ المصاريف' : 'تأكيد وحفظ التسديد'),
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

  Future<void> _showEditCashPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    CashBoxTransaction tx,
    double currentNetCash,
  ) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: tx.title);
    final amountController = TextEditingController(text: tx.amount.toStringAsFixed(0));
    final notesController = TextEditingController(text: tx.notes ?? '');
    final currencyFmt = NumberFormat('#,##0', 'en_US');
    final double maxAllowed = currentNetCash + tx.amount;
    String? errorMsg;
    bool isLoading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final entered = double.tryParse(amountController.text.trim()) ?? 0.0;
          final newRemaining = maxAllowed - entered;
          final isExceeded = entered > maxAllowed;

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
                        const Icon(Icons.edit_outlined, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Text(
                          tx.isExpense ? 'تعديل حركة المصاريف' : 'تعديل حركة التسديد',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isExceeded
                            ? AppColors.debtRed.withValues(alpha: 0.08)
                            : AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الحد الأقصى المتاح للتعديل:', style: TextStyle(fontSize: 12)),
                              Text(
                                '${currencyFmt.format(maxAllowed)} د.ع',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('رصيد الصندوق بعد التعديل:', style: TextStyle(fontSize: 12)),
                              Text(
                                isExceeded
                                    ? 'يتجاوز المتاح!'
                                    : '${currencyFmt.format(newRemaining)} د.ع',
                                style: TextStyle(
                                  color: isExceeded ? AppColors.debtRed : AppColors.paidGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'البيان / الوصف *',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      validator: (v) => AppValidators.validateRequired(v, 'البيان أو الوصف'),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المعدّل (د.ع) *',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      onChanged: (_) => setState(() => errorMsg = null),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                        final val = double.tryParse(v.trim());
                        if (val == null || val <= 0) return 'أدخل مبلغاً صحيحاً أكبر من 0';
                        if (val > maxAllowed) {
                          return 'المبلغ يتجاوز الحد المتاح (${currencyFmt.format(maxAllowed)} د.ع)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات إضافية (اختياري)',
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                    ),

                    if (errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.debtRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMsg!,
                          style: const TextStyle(
                              color: AppColors.debtRed, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setState(() {
                                isLoading = true;
                                errorMsg = null;
                              });
                              try {
                                final newAmount = double.parse(amountController.text.trim());
                                await ref.read(appServiceProvider).updateCashBoxPayment(
                                      oldTx: tx,
                                      newTitle: titleController.text,
                                      newAmount: newAmount,
                                      newNotes: notesController.text,
                                    );

                                ref.invalidate(cashBoxTransactionsProvider);
                                ref.invalidate(financialSummaryProvider);

                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم تعديل الحركة بنجاح'),
                                      backgroundColor: AppColors.paidGreen,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  setState(() {
                                    errorMsg = e.toString().replaceFirst('Exception: ', '');
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
                          : const Text('حفظ التعديل'),
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

  Widget _buildTransactionTile(
    BuildContext context,
    WidgetRef ref,
    CashBoxTransaction tx,
    double netCash,
    NumberFormat currencyFormatter,
    DateFormat dateFormatter,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: tx.isExpense
                    ? AppColors.debtRed.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                child: Icon(
                  tx.isExpense ? Icons.north_east : Icons.payments_outlined,
                  color: tx.isExpense ? AppColors.debtRed : AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          dateFormatter.format(tx.createdAt.toLocal()),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '- ${currencyFormatter.format(tx.amount)} د.ع',
                style: TextStyle(
                  color: tx.isExpense ? AppColors.debtRed : AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'تعديل الحركة',
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.secondary),
                onPressed: () => _showEditCashPaymentDialog(context, ref, tx, netCash),
              ),
            ],
          ),
          if (tx.notes != null && tx.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ملاحظة: ${tx.notes!}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financialSummaryProvider);
    final transactionsAsync = ref.watch(cashBoxTransactionsProvider);
    final expenseLimit = ref.watch(cashBoxExpenseLimitProvider);
    final paymentLimit = ref.watch(cashBoxPaymentLimitProvider);

    final currencyFormatter = NumberFormat('#,##0', 'en_US');
    final dateFormatter = DateFormat('yyyy/MM/dd - hh:mm a');

    final netCash = summaryAsync.value?['totalPaid'] ?? 0.0;
    final totalCollected = summaryAsync.value?['totalCollected'] ?? 0.0;
    final totalExpenses = summaryAsync.value?['totalExpenses'] ?? 0.0;
    final totalDisbursed = summaryAsync.value?['totalDisbursed'] ?? 0.0;
    final bool hasCash = netCash > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوق النقد والمصاريف'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: () {
              ref.invalidate(financialSummaryProvider);
              ref.invalidate(cashBoxTransactionsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financialSummaryProvider);
          ref.invalidate(cashBoxTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. بطاقة رصيد الصندوق الكلي
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF2563EB)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'الصافي المتوفر في صندوق النقد',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currencyFormatter.format(netCash)} د.ع',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الواصل من المشتركين',
                                  style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(
                                '${currencyFormatter.format(totalCollected)} د.ع',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          Container(height: 24, width: 1, color: Colors.white24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('المصاريف والرواتب',
                                  style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(
                                '${currencyFormatter.format(totalExpenses)} د.ع',
                                style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                          Container(height: 24, width: 1, color: Colors.white24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('إجمالي المنصرف',
                                  style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(
                                '${currencyFormatter.format(totalDisbursed)} د.ع',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. زرين واضحين: زر مصاريف (رواتب) + زر تسديد عادي
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasCash ? AppColors.debtRed : Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.work_history_outlined, color: Colors.white, size: 18),
                      label: const Text(
                        'مصاريف (رواتب)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: hasCash
                          ? () => _showNewCashDialog(context, ref, netCash, isExpense: true)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasCash ? AppColors.secondary : Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.payment, color: Colors.white, size: 18),
                      label: const Text(
                        'تسديد عادي',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: hasCash
                          ? () => _showNewCashDialog(context, ref, netCash, isExpense: false)
                          : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ================= 3. فصل حركات المصاريف والتسديد في منتصف الشاشة =================
              transactionsAsync.when(
                data: (allItems) {
                  final expenseList = allItems.where((tx) => tx.isExpense).toList();
                  final paymentList = allItems.where((tx) => !tx.isExpense).toList();

                  final visibleExpenses = expenseList.take(expenseLimit).toList();
                  final visiblePayments = paymentList.take(paymentLimit).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- القسم الأول: حركات المصاريف والرواتب (آخر 5 + زر المزيد) ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.work_history, size: 18, color: AppColors.debtRed),
                              const SizedBox(width: 6),
                              const Text(
                                'حركات المصاريف والرواتب',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            'المعروض: ${visibleExpenses.length} من ${expenseList.length}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (visibleExpenses.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'لا توجد حركات مصاريف ورواتب مسجلة بعد',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ),
                        )
                      else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: visibleExpenses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) => _buildTransactionTile(
                            context,
                            ref,
                            visibleExpenses[i],
                            netCash,
                            currencyFormatter,
                            dateFormatter,
                          ),
                        ),
                        if (expenseList.length > expenseLimit)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: TextButton.icon(
                              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                              label: const Text('إظهار 5 مصاريف إضافية'),
                              onPressed: () {
                                ref.read(cashBoxExpenseLimitProvider.notifier).update((v) => v + 5);
                              },
                            ),
                          ),
                      ],

                      const SizedBox(height: 24),

                      // --- القسم الثاني: حركات التسديدات العادية (آخر 5 + زر المزيد) ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments, size: 18, color: AppColors.primary),
                              const SizedBox(width: 6),
                              const Text(
                                'حركات التسديدات العادية',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            'المعروض: ${visiblePayments.length} من ${paymentList.length}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (visiblePayments.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'لا توجد تسديدات عادية مسجلة بعد',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ),
                        )
                      else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: visiblePayments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) => _buildTransactionTile(
                            context,
                            ref,
                            visiblePayments[i],
                            netCash,
                            currencyFormatter,
                            dateFormatter,
                          ),
                        ),
                        if (paymentList.length > paymentLimit)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: TextButton.icon(
                              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                              label: const Text('إظهار 5 تسديدات إضافية'),
                              onPressed: () {
                                ref.read(cashBoxPaymentLimitProvider.notifier).update((v) => v + 5);
                              },
                            ),
                          ),
                      ],
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(child: Text('خطأ: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}