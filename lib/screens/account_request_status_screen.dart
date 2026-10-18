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
  });

  final String email;
  final VoidCallback onContinueToLogin;

  @override
  Widget build(BuildContext context) {
    final request = context.watch<AuthProvider>().accountRequestData;
    final approved = request?['status'] == 'approved';
    final rejected = request?['status'] == 'rejected';
    final temporaryPassword = request?['temporaryPassword'];

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
                          ? 'Your temporary password is ready. Copy it, then sign in with $email.'
                          : rejected
                          ? 'Your request was rejected. Contact the administrator if you think this is a mistake.'
                          : 'Your request is waiting for admin approval. This page will update when it is approved.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (approved && temporaryPassword is String) ...[
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
                                'After signing in, you must set a new password before opening the app.',
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
                    ] else if (!approved && !rejected) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text(
                        'Keep the app signed in. Your status and temporary password will appear here.',
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
