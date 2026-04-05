import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../design/colors.dart';
import '../../design/theme.dart';
import '../../design/widgets/jetlag_button.dart';
import '../../design/widgets/jetlag_input.dart';

class JoinGameScreen extends ConsumerStatefulWidget {
  const JoinGameScreen({super.key});

  @override
  ConsumerState<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends ConsumerState<JoinGameScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final displayName = ref.read(displayNameProvider);
    if (displayName != null) {
      _nameController.text = displayName;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _codeController.text.toUpperCase();

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        foregroundColor: context.textPrimary,
        title: Text(
          'Join Game',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter Room Code',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Get the 6-character code from the game host',
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // 6 individual character boxes
            GestureDetector(
              onTap: () => _codeFocusNode.requestFocus(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final hasChar = i < code.length;
                  final isActive = i == code.length && _codeFocusNode.hasFocus;
                  return Container(
                    width: 44,
                    height: 56,
                    margin: EdgeInsets.only(
                      right: i < 5 ? 8 : 0,
                      left: i == 3 ? 8 : 0, // extra gap after 3rd char
                    ),
                    decoration: BoxDecoration(
                      color: context.surface2,
                      borderRadius: BorderRadius.circular(JetlagRadii.sm),
                      border: Border.all(
                        color: isActive
                            ? context.accent
                            : hasChar
                                ? context.border
                                : context.borderSubtle,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      hasChar ? code[i] : '',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                        letterSpacing: 0,
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Hidden text field for keyboard input
            SizedBox(
              height: 0,
              child: TextField(
                controller: _codeController,
                focusNode: _codeFocusNode,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(6),
                  UpperCaseTextFormatter(),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(color: Colors.transparent, height: 0.01),
                cursorColor: Colors.transparent,
                onChanged: (_) => setState(() {
                  _errorMessage = null;
                }),
              ),
            ),
            const SizedBox(height: 28),

            // Display Name
            JetlagInput(
              label: 'Your Name',
              hint: 'Enter your display name',
              controller: _nameController,
            ),
            const SizedBox(height: 24),

            // Error Message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: context.red,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Join Button
            JetlagButton(
              label: 'Join Game',
              icon: Icons.login,
              variant: JetlagButtonVariant.primary,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _joinGame,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGame() async {
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a 6-character room code';
      });
      return;
    }

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save display name
      await ref.read(displayNameProvider.notifier).setDisplayName(name);

      // Join session by code
      final gameActions = ref.read(gameActionsProvider);
      final session = await gameActions.joinSessionByCode(code);

      if (session == null) {
        setState(() {
          _errorMessage = 'Game not found. Check the room code.';
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        context.go('/lobby/${session.id}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error joining game: $e';
        _isLoading = false;
      });
    }
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
