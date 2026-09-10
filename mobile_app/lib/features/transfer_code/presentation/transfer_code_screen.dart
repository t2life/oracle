import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

/// 機種引継ぎコード（U-14）。
///
/// 旧端末で「発行」→ 新端末で「引き継ぐ」の2操作で、アカウント
/// （プラン・チケット残数・履歴）を移す。コードは使い捨てで期限つき。
/// アカウントの付け替えはサーバー側の処理のため、オフラインでは使えない
/// （その旨は状態層のメッセージがそのまま表示される）。
class TransferCodeScreen extends StatefulWidget {
  const TransferCodeScreen({super.key});

  @override
  State<TransferCodeScreen> createState() => _TransferCodeScreenState();
}

class _TransferCodeScreenState extends State<TransferCodeScreen> {
  final TextEditingController _input = TextEditingController();

  /// 直近に発行したコード（表示用の整形済み文字列と期限）。
  String? _issuedCode;
  String? _expiresAt;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _issue() async {
    SoundService.instance.play(OracleSound.tap);
    final state = OracleAppStateScope.of(context);
    final issued = await state.issueTransferCode();
    if (!mounted || issued == null) {
      return;
    }
    setState(() {
      _issuedCode = issued['formatted_code'] as String? ??
          issued['code'] as String? ??
          '';
      _expiresAt = _formatExpiry(issued['expires_at'] as String?);
    });
  }

  /// ISO8601 を「2026/09/17 23:59」の形にする。解釈できない値はそのまま出す
  /// （期限を隠すより、生の値でも見せたほうが利用者は判断できる）。
  String? _formatExpiry(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _copy() async {
    final code = _issuedCode;
    if (code == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    messenger.showSnackBar(SnackBar(content: Text(l10n.transferCodeCopied)));
  }

  Future<void> _redeem() async {
    SoundService.instance.play(OracleSound.tap);
    final state = OracleAppStateScope.of(context);
    final moved = await state.redeemTransferCode(_input.text);
    if (!mounted || !moved) {
      return;
    }
    _input.clear();
    setState(() {
      // 引き継いだ時点で、この端末が発行していたコードの表示は意味を失う。
      _issuedCode = null;
      _expiresAt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.transferCodeTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---- 旧端末側: 発行 ----
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.transferCodeIssueTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.transferCodeIssueGuide,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_issuedCode != null) ...[
                        const SizedBox(height: 14),
                        SelectableText(
                          _issuedCode!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(letterSpacing: 2),
                        ),
                        if (_expiresAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.transferCodeExpiresAt(_expiresAt!),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy_all_outlined),
                          onPressed: _copy,
                          label: Text(l10n.transferCodeCopy),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.transferCodeSingleUseNote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: state.loading ? null : _issue,
                        child: Text(
                          _issuedCode == null
                              ? l10n.transferCodeIssueButton
                              : l10n.transferCodeReissueButton,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.transferCodeReissueNote,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ---- 新端末側: 引き継ぎ ----
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.transferCodeRedeemTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.transferCodeRedeemGuide,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _input,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: l10n.transferCodeLabel,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _redeem(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: (state.loading || _input.text.trim().isEmpty)
                            ? null
                            : _redeem,
                        child: Text(l10n.transferCodeRedeemButton),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    resolveStateMessage(context, state.errorMessage!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (state.infoMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(resolveStateMessage(context, state.infoMessage!)),
                ),
            ],
          );
        },
      ),
    );
  }
}
