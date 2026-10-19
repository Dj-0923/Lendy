// lib/screens/account_info_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_layout.dart';
import '../utils/text_formatters.dart';
import '../utils/year_level.dart';
import '../widgets/simple_header.dart';
import '../widgets/plain_text_field.dart';
import '../widgets/plain_dropdown_field.dart';
import '../widgets/primary_button.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _collegeController;
  late final TextEditingController _yearLevelController;
  late final TextEditingController _blockController;
  bool _isLoading = false;

  String? _selectedGender;

  /// The only two choices offered. Kept as a fixed list so the field can never
  /// hold anything else — a dropdown, not a text box, so nothing can be typed.
  static const List<String> _genders = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _collegeController = TextEditingController(text: user?.college ?? '');
    _yearLevelController = TextEditingController(
      text: yearLevelToDigit(user?.yearLevel) ?? '',
    );
    _blockController = TextEditingController(text: user?.block ?? '');
    // Only keep a stored gender that is still one of the two choices — the
    // dropdown asserts if it is handed a value that is not in its item list.
    final savedGender = user?.gender;
    _selectedGender = _genders.contains(savedGender) ? savedGender : null;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _collegeController.dispose();
    _yearLevelController.dispose();
    _blockController.dispose();
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final error = await context.read<AuthProvider>().updateProfile(
      fullName: _fullNameController.text,
      email: _emailController.text,
      gender: _selectedGender,
      college: _collegeController.text.trim().isEmpty
          ? null
          : _collegeController.text.trim(),
      yearLevel: yearLevelToLabel(_yearLevelController.text),
      block: _blockController.text.trim().isEmpty
          ? null
          : _blockController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account information updated.'),
        backgroundColor: AppColors.primaryLight,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isFaculty =
        context.watch<AuthProvider>().currentUser?.role == UserRole.faculty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const SimpleHeader(title: 'Account Info'),
          Expanded(
            child: ResponsiveContent(
              maxWidth: 620,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PlainTextField(
                        label: 'Full  name',
                        hint: 'e.g. Juan Dela Cruz',
                        controller: _fullNameController,
                        validator: (v) => _required(v, 'Full name'),
                      ),
                      const SizedBox(height: 16),
                      PlainDropdownField<String>(
                        label: 'Gender',
                        hint: 'Select gender',
                        value: _selectedGender,
                        options: _genders,
                        labelOf: (g) => g,
                        onChanged: (value) =>
                            setState(() => _selectedGender = value),
                        validator: (value) =>
                            value == null ? 'Gender is required' : null,
                      ),
                      const SizedBox(height: 16),
                      PlainTextField(
                        label: 'Email Address',
                        hint: 'e.g. dhie@gmail.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      // Free text on purpose: the student may type either the
                      // shortcut or the full title. The 22-letter limit is a
                      // Profile display rule, not an input rule, so a long title
                      // can still be entered here and shortened when displayed.
                      PlainTextField(
                        label: 'College',
                        hint: 'e.g. BSIT or BS Information Technology',
                        controller: _collegeController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: const [UpperCaseTextInputFormatter()],
                      ),
                      if (!isFaculty) ...[
                        const SizedBox(height: 16),
                        PlainTextField(
                          label: 'Year level',
                          hint: 'e.g. 3',
                          controller: _yearLevelController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(1),
                          ],
                          validator: validateYearLevel,
                        ),
                        const SizedBox(height: 16),
                        PlainTextField(
                          label: 'Block',
                          hint: 'e.g. 7',
                          controller: _blockController,
                        ),
                      ],
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: 'Save Changes',
                        isLoading: _isLoading,
                        onPressed: _handleSave,
                      ),
                    ],
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
