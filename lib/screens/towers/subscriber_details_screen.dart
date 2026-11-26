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

  Future<void> _showEditTransactionDialog(
    BuildContext context,
    WidgetRef ref,
    SubscriberTransaction tx,
  ) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: tx.amount.toStringAsFixed(0));
    final notesController = TextEditingController(text: tx.notes ?? '');
    final currencyFmt = NumberFormat('#,##0', 'en_US');
    String? errorMsg;
    bool isLoading = false;

    final bool isPlanTx = tx.planName != null && tx.costPrice != null;
    final bool isCashSub = tx.type == 'cash_subscription';
    final bool isPayment = tx.type == 'payment';

    String headerTitle;
    if (isCashSub) {
      headerTitle = 'تعديل اشتراك (${tx.planName}) - نقداً';
    } else if (isPayment) {
      headerTitle = 'تعديل تسديد واصل';
    } else if (tx.planName != null) {
      headerTitle = 'تعديل اشتراك (${tx.planName}) - آجل';
    } else {
      headerTitle = 'تعديل إضافة دين';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final enteredAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
          final updatedProfit = isPlanTx ? (enteredAmount - tx.costPrice!) : 0.0;

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
                        Expanded(
                          child: Text(
                            headerTitle,
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

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المبلغ المسجل سابقاً:', style: TextStyle(fontSize: 12)),
                              Text(
                                '${currencyFmt.format(tx.amount)} د.ع',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          if (isPlanTx) ...[
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'كلفة الشركة: ${currencyFmt.format(tx.costPrice)} د.ع',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                Text(
                                  'الربح الجديد: ${currencyFmt.format(updatedProfit)} د.ع',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: updatedProfit >= 0 ? AppColors.paidGreen : AppColors.debtRed,
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
                        labelText: isPlanTx ? 'سعر البيع المعدّل (د.ع) *' : 'المبلغ المعدّل (د.ع) *',
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      onChanged: (_) => setState(() => errorMsg = null),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                        final val = double.tryParse(v.trim());
                        if (val == null || val <= 0) return 'أدخل مبلغاً صحيحاً أكبر من 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'الملاحظات (تعديل أو إضافة)',
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
                            color: AppColors.debtRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
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
                                await ref.read(appServiceProvider).updateSubscriberTransaction(
                                      oldTx: tx,
                                      newAmount: newAmount,
                                      newNotes: notesController.text,
                                    );

                                ref.invalidate(subscriberByIdProvider(tx.subscriberId));
                                ref.invalidate(subscriberTransactionsProvider(tx.subscriberId));
                                ref.invalidate(subscribersByTowerProvider);
                                ref.invalidate(unpaidSubscribersProvider);
                                ref.invalidate(financialSummaryProvider);
                                ref.invalidate(profitTransactionsProvider);
                                ref.invalidate(cashBoxTransactionsProvider);

                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم تعديل الحركة وتحديث الرصيد بنجاح'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveSubAsync = ref.watch(subscriberByIdProvider(subscriber.id));
    final liveSub = liveSubAsync.value ?? subscriber;

    final transactionsAsync = ref.watch(subscriberTransactionsProvider(subscriber.id));
    final currencyFormatter = NumberFormat('#,##0', 'en_US');
    final dateFormatter = DateFormat('yyyy/MM/dd - hh:mm a');

    final hasDebt = liveSub.debtAmount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل وسجل المشترك'),
        actions: [
          IconButton(
            tooltip: 'حذف المشترك',
            icon: const Icon(Icons.delete_outline, color: AppColors.debtRed),
            onPressed: () async {
              await AppDialogs.showDeleteSubscriberConfirm(context, ref, liveSub);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(subscriberByIdProvider(subscriber.id));
          ref.invalidate(subscriberTransactionsProvider(subscriber.id));
          ref.invalidate(subscribersByTowerProvider);
          ref.invalidate(unpaidSubscribersProvider);
          ref.invalidate(profitTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. بطاقة معلومات المشترك والرصيد الحقيقي المحدّث
              Container(
                padding: const EdgeInsets.all(18),
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
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: hasDebt
                          ? AppColors.debtRed.withValues(alpha: 0.1)
                          : AppColors.paidGreen.withValues(alpha: 0.1),
                      child: Icon(
                        hasDebt ? Icons.person_outline : Icons.check_circle_outline,
                        size: 38,
                        color: hasDebt ? AppColors.debtRed : AppColors.paidGreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      liveSub.fullName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      liveSub.phone,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    if (liveSub.towerName != null) ...[
                      const SizedBox(height: 6),
                      Chip(
                        avatar: const Icon(Icons.cell_tower, size: 16, color: AppColors.primary),
                        label: Text(liveSub.towerName!),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                        side: BorderSide.none,
                      ),
                    ],
                    const Divider(height: 24, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('الدين المتبقي',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              '${currencyFormatter.format(liveSub.debtAmount)} د.ع',
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
                            const Text('إجمالي الواصل',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              '${currencyFormatter.format(liveSub.paidAmount)} د.ع',
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

              // زر إضافة حركة مالية سريعة
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.add_card, color: Colors.white),
                label: const Text('تسديد دين أو تفعيل اشتراك جديد',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await AppDialogs.showUpdateDebt(context, ref, liveSub);
                  ref.invalidate(subscriberByIdProvider(subscriber.id));
                },
              ),

              const SizedBox(height: 24),

              // 2. سجل الحركات والملاحظات (مع زر التعديل لكل حركة)
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
                      final isCashSub = item.type == 'cash_subscription';
                      final isPayment = item.type == 'payment';
                      final isPositiveCash = isPayment || isCashSub;

                      String title;
                      if (isCashSub) {
                        title = 'تفعيل اشتراك (${item.planName ?? 'باقة'}) - نقداً';
                      } else if (isPayment) {
                        title = 'تسديد دفعة واصلة';
                      } else if (item.planName != null) {
                        title = 'تفعيل اشتراك (${item.planName}) - آجل';
                      } else {
                        title = 'إضافة دين جديد';
                      }

                      final statusColor = isPositiveCash ? AppColors.paidGreen : AppColors.debtRed;

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
                                  backgroundColor: statusColor.withValues(alpha: 0.12),
                                  child: Icon(
                                    isCashSub
                                        ? Icons.wifi_tethering
                                        : (isPayment ? Icons.south_west : Icons.north_east),
                                    color: statusColor,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                          fontSize: 13,
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
                                      isCashSub
                                          ? '${currencyFormatter.format(item.amount)} د.ع (كاش)'
                                          : '${isPayment ? "-" : "+"}${currencyFormatter.format(item.amount)} د.ع',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: statusColor,
                                      ),
                                    ),
                                    Text(
                                      'المتبقي: ${currencyFormatter.format(item.remainingDebt)} د.ع',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'تعديل الحركة',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 19,
                                    color: AppColors.secondary,
                                  ),
                                  onPressed: () => _showEditTransactionDialog(context, ref, item),
                                ),
                              ],
                            ),

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