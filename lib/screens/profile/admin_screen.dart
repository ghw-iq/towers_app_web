import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../models/app_models.dart';
import '../../providers/app_providers.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _searchController = TextEditingController();
  final Set<String> _revealedUserIds = {}; // لتتبع الحسابات المكشوف رمزها

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showChangeUserPasswordDialog(UserProfile user) async {
    final formKey = GlobalKey<FormState>();
    final passController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('تغيير رمز: ${user.fullName}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الهاتف: ${user.phone}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passController,
                  decoration: const InputDecoration(
                    labelText: 'الرمز الجديد *',
                    hintText: '6 خانات على الأقل',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                  validator: AppValidators.validatePassword,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => isLoading = true);
                      try {
                        await ref.read(appServiceProvider).adminUpdateUserPassword(
                              targetUserId: user.id,
                              newPassword: passController.text.trim(),
                            );
                        ref.invalidate(adminUsersListProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تغيير رمز المستخدم بنجاح'),
                              backgroundColor: AppColors.paidGreen,
                            ),
                          );
                        }
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
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('حفظ الرمز'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAdminRole(UserProfile user) async {
    if (user.phone == '07823665565') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن سحب صلاحية الأدمن الرئيسي!'),
          backgroundColor: AppColors.debtRed,
        ),
      );
      return;
    }

    final willBeAdmin = !user.isAdmin;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willBeAdmin ? 'تعيين كأدمن' : 'إلغاء صلاحية الأدمن'),
        content: Text(
          willBeAdmin
              ? 'هل تريد منح صلاحيات الأدمن الكاملة للحساب "${user.fullName}"؟'
              : 'هل تريد إزالة صلاحية الأدمن من الحساب "${user.fullName}" وإرجاعه كمستخدم عادي؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willBeAdmin ? AppColors.primary : AppColors.debtRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(appServiceProvider).adminSetUserRole(
              targetUserId: user.id,
              newRole: willBeAdmin ? 'admin' : 'user',
            );
        ref.invalidate(adminUsersListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(willBeAdmin ? 'تم تعيينه كأدمن بنجاح' : 'تم إلغاء صلاحية الأدمن'),
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersListProvider);
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الأدمن'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminUsersListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط بحث عن المستخدمين
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الهاتف...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminUsersListProvider),
              child: usersAsync.when(
                data: (users) {
                  final filtered = query.isEmpty
                      ? users
                      : users.where((u) {
                          return u.fullName.toLowerCase().contains(query) ||
                              u.phone.contains(query);
                        }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد حسابات مطابقة',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final user = filtered[index];
                      final isRevealed = _revealedUserIds.contains(user.id);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: user.isAdmin
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : AppColors.border,
                            width: user.isAdmin ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: user.isAdmin
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : AppColors.background,
                                  child: Icon(
                                    user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                                    color: user.isAdmin ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              user.fullName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: user.isAdmin
                                                  ? AppColors.primary.withValues(alpha: 0.1)
                                                  : Colors.grey.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              user.isAdmin ? 'أدمن' : 'مستخدم',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: user.isAdmin ? AppColors.primary : AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.phone,
                                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 20, color: AppColors.border),

                            // قسم كشف الرمز وتغييره
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'الرمز: ',
                                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    ),
                                    Text(
                                      isRevealed
                                          ? (user.passcode ?? 'غير محفوظ')
                                          : '••••••',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        letterSpacing: isRevealed ? 0.5 : 2.0,
                                        color: isRevealed ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: isRevealed ? 'إخفاء الرمز' : 'كشف الرمز',
                                      icon: Icon(
                                        isRevealed ? Icons.visibility_off : Icons.visibility,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (isRevealed) {
                                            _revealedUserIds.remove(user.id);
                                          } else {
                                            _revealedUserIds.add(user.id);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.lock_reset, size: 16),
                                      label: const Text('تغيير الرمز', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _showChangeUserPasswordDialog(user),
                                    ),
                                    IconButton(
                                      tooltip: user.isAdmin ? 'إلغاء الأدمن' : 'تعيين كأدمن',
                                      icon: Icon(
                                        user.isAdmin ? Icons.person_remove_outlined : Icons.verified_user_outlined,
                                        color: user.isAdmin ? AppColors.debtRed : AppColors.paidGreen,
                                        size: 20,
                                      ),
                                      onPressed: () => _toggleAdminRole(user),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('خطأ: $err', textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}