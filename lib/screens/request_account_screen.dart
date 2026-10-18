// lib/screens/request_account_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import 'account_request_status_screen.dart';
import 'login_screen.dart';

/// Lets a Student/Faculty request an account and wait for admin approval.
class RequestAccountScreen extends StatefulWidget {
  const RequestAccountScreen({super.key});

  @override
  State<RequestAccountScreen> createState() => _RequestAccountScreenState();
}

class _RequestAccountScreenState extends State<RequestAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _collegeController = TextEditingController();
  final _emailController = TextEditingController();

  UserRole _selectedRole = UserRole.student;
  bool _isLoading = false;
  bool _submitted = false;
  String? _requestEmail;

  @override
  void dispose() {
    _fullNameController.dispose();
    _idNumberController.dispose();
    _collegeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final result = await context.read<AuthProvider>().requestAccount(
      fullName: _fullNameController.text,
      email: _emailController.text,
      role: _selectedRole,
      idNumber: _idNumberController.text,
      college: _collegeController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error!),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _submitted = true;
      _requestEmail = _emailController.text.trim();
    });
  }

  Future<void> _goToLogin() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(initialEmail: _requestEmail ?? ''),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    if (_submitted) {
      return AccountRequestStatusScreen(
        email: _requestEmail ?? _emailController.text.trim(),
        onContinueToLogin: _goToLogin,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----- Header -----
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(8, statusBarHeight, 24, 24),
              color: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Request Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 8, top: 6, right: 24),
                          child: Text(
                            "Submit your details. An admin will review your request. If approved, your temporary password will appear here in the app.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ----- Form -----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'I am a...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleCard(
                            label: 'Student',
                            icon: Icons.school_outlined,
                            selected: _selectedRole == UserRole.student,
                            onTap: () => setState(
                              () => _selectedRole = UserRole.student,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleCard(
                            label: 'Faculty',
                            icon: Icons.badge_outlined,
                            selected: _selectedRole == UserRole.faculty,
                            onTap: () => setState(
                              () => _selectedRole = UserRole.faculty,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Full name',
                      hint: 'e.g. Juan Dela Cruz',
                      icon: Icons.person_outline,
                      controller: _fullNameController,
                      validator: (v) => _required(v, 'Full name'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: _selectedRole == UserRole.student
                          ? 'Student ID Number'
                          : 'Faculty ID Number',
                      hint: 'e.g. 20243781',
                      icon: Icons.badge_outlined,
                      controller: _idNumberController,
                      validator: (v) => _required(v, 'ID number'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'College',
                      hint: 'e.g. College of Computer Studies',
                      icon: Icons.school_outlined,
                      controller: _collegeController,
                      validator: (v) => _required(v, 'College'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Email',
                      hint: 'e.g. username@gmail.com',
                      icon: Icons.email_outlined,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Submit Request',
                      isLoading: _isLoading,
                      onPressed: _handleSubmit,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? '),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign in',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryLight.withValues(alpha: 0.08)
              : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryLight : AppColors.fieldBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primaryLight : Colors.grey,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.primaryLight
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
