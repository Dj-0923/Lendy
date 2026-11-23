// lib/screens/request_account_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../utils/college_programs.dart';
import '../utils/year_level.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_notice.dart';
import '../widgets/plain_dropdown_field.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

/// Lets a Student/Faculty submit an account request for admin review.
class RequestAccountScreen extends StatefulWidget {
  const RequestAccountScreen({super.key});

  @override
  State<RequestAccountScreen> createState() => _RequestAccountScreenState();
}

class _RequestAccountScreenState extends State<RequestAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();
  final _fullNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _emailController = TextEditingController();

  static const List<String> _genders = ['Male', 'Female'];
  static const List<String> _yearLevels = ['1', '2', '3', '4', '5'];
  static const double _collegeMenuMaxHeight =
      PlainDropdownField.menuRowHeight * 5;
  static final List<String> _blocks = List.generate(
    11,
    (index) => '${index + 1}',
  );

  UserRole _selectedRole = UserRole.student;
  String? _selectedGender;
  CollegeProgram? _selectedCollege;
  FacultyCollege? _selectedFacultyCollege;
  String? _selectedYearLevel;
  String? _selectedBlock;
  bool _isLoading = false;
  String? _requestEmail;
  String? _emailValidationError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _idNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  String? _validateIdNumber(String? value) {
    final requiredError = _required(value, 'ID number');
    if (requiredError != null) return requiredError;
    if (value!.trim().length != 8) {
      final label = _selectedRole == UserRole.student
          ? 'Student ID No.'
          : 'Faculty ID No.';
      return '$label must be exactly 8 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (_emailValidationError != null) return _emailValidationError;
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
      college: _selectedRole == UserRole.student
          ? _selectedCollege!.short
          : _selectedFacultyCollege!.short,
      gender: _selectedGender!,
      yearLevel: _selectedRole == UserRole.student
          ? yearLevelToLabel(_selectedYearLevel)
          : null,
      block: _selectedRole == UserRole.student ? _selectedBlock : null,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      if (result.code == 'email-already-in-use' ||
          result.code == 'request-already-pending') {
        setState(() {
          _emailValidationError = result.code == 'request-already-pending'
              ? 'A request using this email is already waiting for admin approval.'
              : 'This email already belongs to an approved account.';
        });
        _emailFieldKey.currentState?.validate();
        return;
      }
      AppNotice.show(context, result.error!, type: AppNoticeType.error);
      return;
    }

    _requestEmail = _emailController.text.trim();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request submitted'),
        content: Text(
          'Your request was submitted successfully. The admin will review it. '
          'If approved, a temporary password will be emailed to $_requestEmail.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await _goToLogin();
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: _selectedRole == UserRole.student
                                ? 'Student ID No.'
                                : 'Faculty ID No.',
                            hint: 'e.g. 20243781',
                            controller: _idNumberController,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(8),
                            ],
                            validator: _validateIdNumber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PlainDropdownField<String>(
                            label: 'Gender',
                            hint: 'Select gender',
                            value: _selectedGender,
                            options: _genders,
                            rightContentPadding: 0,
                            labelOf: (gender) => gender,
                            onChanged: (gender) =>
                                setState(() => _selectedGender = gender),
                            validator: (gender) =>
                                gender == null ? 'Gender is required' : null,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedRole == UserRole.student) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: PlainDropdownField<String>(
                              label: 'Year level',
                              hint: 'Select year',
                              value: _selectedYearLevel,
                              options: _yearLevels,
                              rightContentPadding: 0,
                              labelOf: (yearLevel) => yearLevel,
                              onChanged: (yearLevel) => setState(
                                () => _selectedYearLevel = yearLevel,
                              ),
                              validator: (yearLevel) => yearLevel == null
                                  ? 'Year level is required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PlainDropdownField<String>(
                              label: 'Block',
                              hint: 'Select block',
                              value: _selectedBlock,
                              options: _blocks,
                              menuMaxHeight:
                                  PlainDropdownField.menuRowHeight * 5,
                              rightContentPadding: 0,
                              labelOf: (block) => block,
                              onChanged: (block) =>
                                  setState(() => _selectedBlock = block),
                              validator: (block) =>
                                  block == null ? 'Block is required' : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_selectedRole == UserRole.student)
                      PlainDropdownField<CollegeProgram>(
                        label: 'Course',
                        hint: 'Select course',
                        value: _selectedCollege,
                        options: collegeProgramOptions,
                        menuMaxHeight: _collegeMenuMaxHeight,
                        rightContentPadding: 0,
                        labelOf: (program) => program.menuLabel,
                        onChanged: (program) =>
                            setState(() => _selectedCollege = program),
                        validator: (program) =>
                            program == null ? 'Course is required' : null,
                      )
                    else
                      PlainDropdownField<FacultyCollege>(
                        label: 'College',
                        hint: 'Select college',
                        value: _selectedFacultyCollege,
                        options: facultyCollegeOptions,
                        menuMaxHeight: _collegeMenuMaxHeight,
                        rightContentPadding: 0,
                        labelOf: (college) => college.menuLabel,
                        onChanged: (college) =>
                            setState(() => _selectedFacultyCollege = college),
                        validator: (college) =>
                            college == null ? 'College is required' : null,
                      ),
                    const SizedBox(height: 16),
                    AppTextField(
                      fieldKey: _emailFieldKey,
                      label: 'Email',
                      hint: 'e.g. username@gmail.com',
                      icon: Icons.email_outlined,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      onChanged: (_) {
                        if (_emailValidationError == null) return;
                        setState(() {
                          _emailValidationError = null;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _emailFieldKey.currentState?.validate();
                        });
                      },
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
