import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class AccountRequestStatusScreen extends StatelessWidget {
  const AccountRequestStatusScreen({
    super.key,
    required this.email,
    required this.onContinueToLogin,
    required this.onRequestAgain,
  });

  final String email;
  final VoidCallback onContinueToLogin;
  final VoidCallback onRequestAgain;

  @override
  Widget build(BuildContext context) {
    final request = context.watch<AuthProvider>().accountRequestData;
    final approved = request?['status'] == 'approved';
    final rejected = request?['status'] == 'rejected';
    final requestDeleted = request?['requestDeleted'] == true;
    final emailSent = request?['credentialEmailStatus'] == 'sent';
    final passwordValue = request?['temporaryPassword'];
    final String? temporaryPassword = passwordValue is String
        ? passwordValue
        : null;
    final hasTemporaryPassword = temporaryPassword != null;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      rejected
                          ? Icons.info_outline_rounded
                          : approved
                          ? Icons.mark_email_read_outlined
                          : Icons.hourglass_top_rounded,
                      color: AppColors.primary,
                      size: 54,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      approved
                          ? 'Your account is approved'
                          : rejected
                          ? 'Request not approved'
                          : 'Waiting for admin approval',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      approved
                          ? emailSent
                                ? 'Your temporary password was emailed to $email. It is also shown below. Sign in with it, then set a new password.'
                                : hasTemporaryPassword
                                ? 'The email could not be sent, but you can use the temporary password below to sign in and set a new one.'
                                : 'Your account is approved, but the password email could not be sent. Please contact the administrator.'
                          : rejected
                          ? requestDeleted
                                ? 'Your rejected request and its unused sign-in account were removed. You can submit a new request using this email.'
                                : 'Your request was not approved. You can submit a new request using this email.'
                          : 'Your request is waiting for admin approval. Your temporary password will be emailed if the admin approves it.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (approved && hasTemporaryPassword) ...[
                      const SizedBox(height: 22),
                      Card(
                        color: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Temporary password',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      temporaryPassword,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Copy password',
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: temporaryPassword),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Temporary password copied.',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'After signing in, set a new password. This temporary password will then be removed from the app.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onContinueToLogin,
                          child: const Text('Continue to Login'),
                        ),
                      ),
                    ] else if (approved && emailSent) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onContinueToLogin,
                          child: const Text('Continue to Login'),
                        ),
                      ),
                    ] else if (!approved && !rejected) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text(
                        'Keep the app signed in. Your request status will update here; approved passwords are sent by email.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ] else if (rejected) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onRequestAgain,
                          child: const Text('Submit a new request'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onContinueToLogin,
                        child: const Text('Back to Login'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
