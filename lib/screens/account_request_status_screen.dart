import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class AccountRequestStatusScreen extends StatelessWidget {
  const AccountRequestStatusScreen({
    super.key,
    required this.email,
    required this.onContinueToLogin,
  });

  final String email;
  final VoidCallback onContinueToLogin;

  @override
  Widget build(BuildContext context) {
    final request = context.watch<AuthProvider>().accountRequestData;
    final approved = request?['status'] == 'approved';
    final rejected = request?['status'] == 'rejected';
    final emailSent = request?['credentialEmailStatus'] == 'sent';

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
                          : 'Request submitted',
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
                                ? 'Your temporary password was emailed to $email. Sign in with it, then set a new password.'
                                : 'Your account is approved, but the password email could not be sent. Please contact the administrator.'
                          : rejected
                          ? 'Your request was rejected. Contact the administrator if you think this is a mistake.'
                          : 'Your request is waiting for admin approval. This page will update when it is approved.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (approved && emailSent) ...[
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
