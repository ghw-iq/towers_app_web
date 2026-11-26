import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/app_models.dart';
import '../../providers/app_providers.dart';
import 'admin_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isExportingReport1 = false;
  bool _isExportingReport2 = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initFields(UserProfile profile) {
    if (!_isEditing) {
      _nameController.text = profile.fullName;
      _phoneController.text = profile.phone;
    }
  }

  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(appServiceProvider).updateProfile(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
      ref.invalidate(profileProvider);
      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث البيانات بنجاح'),
            backgroundColor: AppColors.paidGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ البيانات: $e'),
            backgroundColor: AppColors.debtRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleExportReport1() async {
    setState(() => _isExportingReport1 = true);
    try {
      await ref.read(appServiceProvider).exportDebtsAndCashBoxReport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('تم تنزيل تقرير الديون والصندوق بنجاح'),
              ],
            ),
            backgroundColor: AppColors.paidGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تصدير التقرير الأول: $e'),
            backgroundColor: AppColors.debtRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingReport1 = false);
    }
  }

  Future<void> _handleExportReport2() async {
    setState(() => _isExportingReport2 = true);
    try {
      await ref.read(appServiceProvider).exportFullReportWithAllTransactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('تم تنزيل التقرير الشامل بكافة الحركات بنجاح'),
              ],
            ),
            backgroundColor: AppColors.paidGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تصدير التقرير الثاني: $e'),
            backgroundColor: AppColors.debtRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingReport2 = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final passwordController = TextEditingController();
    final passFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تغيير كلمة المرور'),
        content: Form(
          key: passFormKey,
          child: TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: AppValidators.validatePassword,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!passFormKey.currentState!.validate()) return;
              try {
                await ref.read(appServiceProvider).updatePassword(passwordController.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تغيير كلمة السر بنجاح'),
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
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final dateFormatter = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي والإعدادات'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined, size: 22),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          _initFields(profile);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(
                      profile.isAdmin ? Icons.admin_panel_settings : Icons.account_circle,
                      size: 54,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    profile.fullName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'تاريخ الانضمام: ${dateFormatter.format(profile.createdAt.toLocal())}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),

                // زر لوحة تحكم الأدمن (يظهر للأدمن فقط)
                if (profile.isAdmin) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                      title: const Text(
                        'لوحة تحكم الأدمن',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      subtitle: const Text(
                        'كشف الرموز، تغيير كلمات السر، وتعيين المشرفين',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.primary),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // 1. نموذج تعديل البيانات
                Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'البيانات الأساسية',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          enabled: _isEditing,
                          decoration: const InputDecoration(
                            labelText: 'الاسم الكامل أو اسم البرج',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => AppValidators.validateRequired(v, 'الاسم'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          enabled: _isEditing,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف المسجل',
                            hintText: '07xxxxxxxxx',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: AppValidators.validatePhone,
                        ),
                        if (_isEditing) ...[
                          const SizedBox(height: 18),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleSaveProfile,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('حفظ التعديلات'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // 2. تقارير الإكسل
                const Text(
                  'تقارير الإكسل والنسخ الاحتياطي',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.paidGreen.withValues(alpha: 0.4)),
                  ),
                  child: ListTile(
                    leading: _isExportingReport1
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.paidGreen),
                          )
                        : const Icon(Icons.table_chart, color: AppColors.paidGreen),
                    title: const Text(
                      'تقرير الديون وصندوق النقد',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'كل برج وتحته مشتركوه المدينون فقط + عمود حركات الصندوق',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.download, color: AppColors.paidGreen),
                    onTap: _isExportingReport1 ? null : _handleExportReport1,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                  ),
                  child: ListTile(
                    leading: _isExportingReport2
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary),
                          )
                        : const Icon(Icons.assessment_outlined, color: AppColors.secondary),
                    title: const Text(
                      'التقرير الشامل (كل الحركات)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'الأبراج وكافة حركات المشتركين والملاحظات + عمود حركات الصندوق',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.download, color: AppColors.secondary),
                    onTap: _isExportingReport2 ? null : _handleExportReport2,
                  ),
                ),

                const SizedBox(height: 18),

                // 3. زر تغيير كلمة المرور
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.vpn_key_outlined, color: AppColors.primary),
                    title: const Text('تغيير كلمة المرور'),
                    trailing: const Icon(Icons.arrow_back_ios_new, size: 16),
                    onTap: _showChangePasswordDialog,
                  ),
                ),

                const SizedBox(height: 24),

                // 4. زر تسجيل الخروج مع تصفير كافة المزودات بالكامل
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.debtRed),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout, color: AppColors.debtRed),
                  label: const Text(
                    'تسجيل الخروج من الحساب',
                    style: TextStyle(color: AppColors.debtRed, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('تسجيل الخروج'),
                        content: const Text('هل أنت متأكد من رغبتك بتسجيل الخروج؟'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.debtRed),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('خروج'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      ref.invalidate(profileProvider);
                      ref.invalidate(towersListProvider);
                      ref.invalidate(financialSummaryProvider);
                      ref.invalidate(unpaidSubscribersProvider);
                      ref.invalidate(subscribersByTowerProvider);
                      ref.invalidate(cashBoxTransactionsProvider);
                      ref.invalidate(adminUsersListProvider);
                      ref.invalidate(subscriptionPlansProvider);
                      ref.invalidate(profitTransactionsProvider);
                      ref.read(selectedTowerFilterProvider.notifier).state = null;
                      ref.read(selectedProfitTowerProvider.notifier).state = null;
                      ref.read(homeSearchQueryProvider.notifier).state = '';

                      await ref.read(appServiceProvider).signOut();
                    }
                  },
                ),

                const SizedBox(height: 36),

                // حقوق التصميم والتطوير
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.code, size: 16, color: AppColors.primary.withValues(alpha: 0.7)),
                          const SizedBox(width: 6),
                          Text(
                            'Design by AHMED AL-JANABI',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.textPrimary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'إصدار 1.0.0 • جميع الحقوق محفوظة',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('خطأ في تحميل الملف الشخصي: $err')),
      ),
    );
  }
}