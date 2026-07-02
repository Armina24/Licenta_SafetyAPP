import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String? prefilledEmail;

  const ForgotPasswordPage({super.key, this.prefilledEmail});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const _orange = Color(0xFFFF8C42);

  int _step = 0;

  String _email = '';
  String _channel = 'email';
  String _resetToken = '';

  void _onCodeSent({required String email, required String channel}) {
    setState(() {
      _email = email;
      _channel = channel;
      _step = 1;
    });
  }

  void _onCodeVerified(String resetToken) {
    setState(() {
      _resetToken = resetToken;
      _step = 2;
    });
  }

  void _onPasswordReset() {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.settings.name == '/login');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Parola a fost resetată! Te poți autentifica acum.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Resetează parola', 'Introdu codul', 'Parolă nouă'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F1F1F)),
        title: Text(
          titles[_step],
          style: const TextStyle(color: Color(0xFF1F1F1F)),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: switch (_step) {
            0 => _StepChannel(
              key: const ValueKey(0),
              orange: _orange,
              prefilledEmail: widget.prefilledEmail,
              onCodeSent: _onCodeSent,
            ),
            1 => _StepOtp(
              key: const ValueKey(1),
              orange: _orange,
              email: _email,
              channel: _channel,
              onVerified: _onCodeVerified,
            ),
            _ => _StepNewPassword(
              key: const ValueKey(2),
              orange: _orange,
              resetToken: _resetToken,
              onDone: _onPasswordReset,
            ),
          },
        ),
      ),
    );
  }
}

class _StepChannel extends StatefulWidget {
  final Color orange;
  final String? prefilledEmail;
  final void Function({required String email, required String channel})
  onCodeSent;

  const _StepChannel({
    super.key,
    required this.orange,
    required this.prefilledEmail,
    required this.onCodeSent,
  });

  @override
  State<_StepChannel> createState() => _StepChannelState();
}

class _StepChannelState extends State<_StepChannel> {
  late final TextEditingController _emailCtrl;
  String _channel = 'email';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.prefilledEmail ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('Introdu adresa de email.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.forgotPassword(
        email: email,
        channel: _channel,
      );
      if (!mounted) return;
      widget.onCodeSent(email: email, channel: _channel);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e, st) {
      developer.log('forgotPassword error', error: e, stackTrace: st);
      _showError('Nu s-a putut trimite codul. Încearcă din nou.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: widget.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_reset_rounded,
                size: 44,
                color: widget.orange,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ai uitat parola?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Introdu adresa de email și alege cum vrei să primești codul de verificare.',
            style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Trimite codul prin:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _ChannelCard(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  selected: _channel == 'email',
                  orange: widget.orange,
                  onTap: () => setState(() => _channel = 'email'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChannelCard(
                  icon: Icons.sms_outlined,
                  label: 'SMS',
                  selected: _channel == 'sms',
                  orange: widget.orange,
                  onTap: () => setState(() => _channel = 'sms'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Trimite codul',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color orange;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.orange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? orange.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? orange : const Color(0xFFDDDDDD),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? orange : const Color(0xFF999999),
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? orange : const Color(0xFF777777),
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepOtp extends StatefulWidget {
  final Color orange;
  final String email;
  final String channel;
  final void Function(String resetToken) onVerified;

  const _StepOtp({
    super.key,
    required this.orange,
    required this.email,
    required this.channel,
    required this.onVerified,
  });

  @override
  State<_StepOtp> createState() => _StepOtpState();
}

class _StepOtpState extends State<_StepOtp> {
  final List<TextEditingController> _ctrls = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _canResend = false;
  int _countdown = 60;
  Timer? _timer;
  int _expirySeconds = 600;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    _startExpiryCountdown();
  }

  void _startResendCountdown() {
    _countdown = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  void _startExpiryCountdown() {
    _expirySeconds = 600;
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_expirySeconds > 0) {
          _expirySeconds--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    final code = _code;
    if (code.length < 6) {
      _showError('Introdu toate cele 6 cifre.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await AuthService.instance.verifyResetCode(
        email: widget.email,
        code: code,
      );
      if (!mounted) return;
      widget.onVerified(token);
    } on AuthException catch (e) {
      _showError(e.message);
      _clearOtp();
    } catch (e, st) {
      developer.log('verifyResetCode error', error: e, stackTrace: st);
      _showError('Eroare de rețea. Încearcă din nou.');
      _clearOtp();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearOtp() {
    for (final c in _ctrls) {
      c.clear();
    }
    if (_nodes.isNotEmpty) {
      _nodes[0].requestFocus();
    }
  }

  Future<void> _resend() async {
    setState(() => _canResend = false);
    try {
      await AuthService.instance.forgotPassword(
        email: widget.email,
        channel: widget.channel,
      );
      if (!mounted) return;
      _startResendCountdown();
      _startExpiryCountdown();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cod nou trimis!')));
    } on AuthException catch (e) {
      _showError(e.message);
      if (mounted) setState(() => _canResend = true);
    } catch (_) {
      _showError('Nu s-a putut retrimite codul.');
      if (mounted) setState(() => _canResend = true);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _expiryLabel {
    final m = _expirySeconds ~/ 60;
    final s = _expirySeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final channelLabel = widget.channel == 'email'
        ? 'email-ul'
        : 'numărul de telefon';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: widget.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_read_outlined,
                size: 44,
                color: widget.orange,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Verifică codul',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Am trimis un cod de 6 cifre la $channelLabel asociat contului tău.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF777777)),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: _expirySeconds < 60 ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                'Codul expiră în $_expiryLabel',
                style: TextStyle(
                  fontSize: 13,
                  color: _expirySeconds < 60
                      ? Colors.red
                      : const Color(0xFF777777),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(
                width: 44,
                child: TextField(
                  controller: _ctrls[i],
                  focusNode: _nodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: widget.orange, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty && i < 5) {
                      _nodes[i + 1].requestFocus();
                    } else if (val.isEmpty && i > 0) {
                      _nodes[i - 1].requestFocus();
                    }

                    if (_code.length == 6 && val.isNotEmpty) {
                      _verify();
                    }
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Verifică codul',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: _canResend
                ? TextButton(
                    onPressed: _resend,
                    child: Text(
                      'Retrimite codul',
                      style: TextStyle(color: widget.orange),
                    ),
                  )
                : Text(
                    'Poți retrimite codul în $_countdown s',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StepNewPassword extends StatefulWidget {
  final Color orange;
  final String resetToken;
  final VoidCallback onDone;

  const _StepNewPassword({
    super.key,
    required this.orange,
    required this.resetToken,
    required this.onDone,
  });

  @override
  State<_StepNewPassword> createState() => _StepNewPasswordState();
}

class _StepNewPasswordState extends State<_StepNewPassword> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPass = false;
  bool _showConfirm = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (pass.length < 8) {
      _showError('Parola trebuie să aibă minim 8 caractere.');
      return;
    }
    if (pass != confirm) {
      _showError('Parolele nu coincid.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.resetPassword(
        resetToken: widget.resetToken,
        newPassword: pass,
      );
      if (!mounted) return;
      widget.onDone();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e, st) {
      developer.log('resetPassword error', error: e, stackTrace: st);
      _showError('Eroare de rețea. Încearcă din nou.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: widget.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_open_rounded,
                size: 44,
                color: widget.orange,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Parolă nouă',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Alege o parolă nouă de minim 8 caractere.',
            style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _passCtrl,
            obscureText: !_showPass,
            decoration: InputDecoration(
              labelText: 'Parolă nouă',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              suffixIcon: IconButton(
                icon: Icon(_showPass ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmCtrl,
            obscureText: !_showConfirm,
            decoration: InputDecoration(
              labelText: 'Confirmă parola',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirm ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _reset,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Resetează parola',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
