import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/state_message_l10n.dart';

/// ニックネーム設定画面（④）。
/// 初回起動時は必須（戻る不可）、マイページからは編集として再利用。
class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key, this.isInitialSetup = true});

  final bool isInitialSetup;

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final state = OracleAppStateScope.of(context);
    _controller = TextEditingController(text: state.nickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      return;
    }
    final state = OracleAppStateScope.of(context);
    SoundService.instance.play(OracleSound.tap);
    await state.saveNickname(name);
    if (!mounted || state.errorMessage != null) {
      return;
    }
    if (widget.isInitialSetup) {
      Navigator.of(context).pushReplacementNamed('/shell');
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      // 初回設定はスキップ不可（必須）
      canPop: !widget.isInitialSetup,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isInitialSetup,
          title: Text(l10n.nicknameTitle),
        ),
        body: OracleStateBuilder(
          builder: (context, state) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              children: [
                Center(
                  child: Icon(Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.nicknamePrompt,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  maxLength: 20,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.nicknameLabel,
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _save(),
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      resolveStateMessage(context, state.errorMessage!),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.loading ? null : _save,
                  child: Text(l10n.nicknameSave),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
