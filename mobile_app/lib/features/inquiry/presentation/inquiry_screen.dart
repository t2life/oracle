import 'package:flutter/material.dart';

import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _category = 'general';

  @override
  void dispose() {
    _bodyController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    final email = _emailController.text.trim();
    if (body.isEmpty) {
      return;
    }

    final state = OracleAppStateScope.of(context);
    await state.submitInquiry(
      category: _category,
      body: body,
      email: email.isEmpty ? null : email,
    );

    if (!mounted) {
      return;
    }
    if (state.errorMessage == null) {
      _bodyController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.inquiryScreenTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    resolveStateMessage(context, state.errorMessage!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (state.infoMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(resolveStateMessage(context, state.infoMessage!)),
                ),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(labelText: l10n.categoryLabel),
                items: [
                  DropdownMenuItem(
                    value: 'general',
                    child: Text(l10n.categoryGeneral),
                  ),
                  DropdownMenuItem(
                    value: 'billing',
                    child: Text(l10n.categoryBilling),
                  ),
                  DropdownMenuItem(
                    value: 'bug',
                    child: Text(l10n.categoryBug),
                  ),
                ],
                onChanged: state.loading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _category = value;
                        });
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: l10n.emailOptionalLabel,
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !state.loading,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyController,
                decoration: InputDecoration(
                  labelText: l10n.inquiryBodyLabel,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 8,
                enabled: !state.loading,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: state.loading ? null : _submit,
                child: state.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.sendLabel),
              ),
            ],
          );
        },
      ),
    );
  }
}
