import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../providers/app_providers.dart';

class CashBoxScreen extends ConsumerWidget {
  const CashBoxScreen({super.key});

  Future<void> _showNewCashPaymentDialog(BuildContext context, WidgetRef ref, double availableCash) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'تسديد من صندوق النقد',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      color: AppColors.paidGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المتوفر حالياً في الصندوق:'),
                        Text(
                          '${NumberFormat('#,##0', 'en_US').format(availableCash)} د.ع',
                          style: const TextStyle(
                            color: AppColors.paidGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // حقل قيمة التسديد (وصف / جهة التسديد)
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'قيمة التسديد (الوصف / الجهة) *',
                      hintText: 'مثال: تسديد المزود الرئيسي، شراء راوتر، صيانة...',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    validator: (v) => AppValidators.validateRequired(v, 'قيمة التسديد أو الوصف'),
                  ),
                  const SizedBox(height: 12),

                  // حقل المبلغ
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ (د.ع) *',
                      hintText: 'مثال: 50000',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                      final val = double.tryParse(v);
                      if (val == null || val <= 0) return 'يرجى إدخال مبلغ صحيح أكبر من 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // حقل ملاحظات إضافية
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
                        : const Text('تأكيد وحفظ التسديد'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financialSummaryProvider);
    final transactionsAsync = ref.watch(cashBoxTransactionsProvider);
    final currencyFormatter = NumberFormat('#,##0', 'en_US');
    final dateFormatter = DateFormat('yyyy/MM/dd - hh:mm a');

    final netCash = summaryAsync.value?['totalPaid'] ?? 0.0;
    final totalCollected = summaryAsync.value?['totalCollected'] ?? 0.0;
    final totalDisbursed = summaryAsync.value?['totalDisbursed'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوق النقد والأرشفة'),
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
                padding: const EdgeInsets.all(20),
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
                        Icon(Icons.account_balance_wallet, color: Colors.white70, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'الصافي المتوفر في صندوق النقد',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${currencyFormatter.format(netCash)} د.ع',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
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
                              const Text('الواصل من المشتركين', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(
                                '${currencyFormatter.format(totalCollected)} د.ع',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          Container(height: 24, width: 1, color: Colors.white24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('إجمالي تسديدات الصندوق', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(
                                '${currencyFormatter.format(totalDisbursed)} د.ع',
                                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. زر التسديد من الصندوق
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                icon: const Icon(Icons.payment, color: Colors.white),
                label: const Text(
                  'تسديد (صرف من الصندوق)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showNewCashPaymentDialog(context, ref, netCash),
              ),

              const SizedBox(height: 24),

              // 3. أرشيف التسديدات بالتواريخ والأوقات
              const Row(
                children: [
                  Icon(Icons.archive_outlined, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'أرشيف تسديدات الصندوق',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              transactionsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary),
                          SizedBox(height: 12),
                          Text(
                            'لا توجد تسديدات مؤرشفة في الصندوق بعد',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final tx = items[index];
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
                                  radius: 18,
                                  backgroundColor: AppColors.debtRed.withValues(alpha: 0.1),
                                  child: const Icon(Icons.north_east, color: AppColors.debtRed, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 13, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            dateFormatter.format(tx.createdAt.toLocal()),
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '- ${currencyFormatter.format(tx.amount)} د.ع',
                                  style: const TextStyle(
                                    color: AppColors.debtRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'ملاحظة: ${tx.notes!}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                error: (err, _) => Center(child: Text('خطأ: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}