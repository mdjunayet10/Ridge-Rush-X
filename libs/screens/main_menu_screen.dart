import 'package:flutter/material.dart';

import '../services/save_service.dart';
import '../services/sfx_service.dart';
import '../widgets/buggy_preview.dart';
import '../widgets/cartoon_background.dart';
import '../widgets/game_button.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    required this.saveService,
    required this.sfxService,
    super.key,
  });

  final SaveService saveService;
  final SfxService sfxService;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  Future<void> _open(BuildContext context, String route) async {
    await widget.sfxService.unlock();
    widget.sfxService.play(SfxCue.buttonClick, volume: 0.45);
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).pushNamed(route);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openAccountDialog() async {
    await widget.sfxService.unlock();
    widget.sfxService.play(SfxCue.buttonClick, volume: 0.45);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xAA000000),
      builder: (_) => _AccountDialog(
        saveService: widget.saveService,
        sfxService: widget.sfxService,
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CartoonBackground(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 720;
                    final panelWidth = constraints.maxWidth
                        .clamp(320, desktop ? 720 : 430)
                        .toDouble();

                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 22),
                                  child: child,
                                ),
                              );
                            },
                            child: SizedBox(
                              width: panelWidth,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: desktop ? 30 : 20,
                                  vertical: desktop ? 18 : 12,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _GameTitle(desktop: desktop),
                                    SizedBox(height: desktop ? 14 : 10),
                                    _PreviewBay(
                                      desktop: desktop,
                                      saveService: widget.saveService,
                                    ),
                                    SizedBox(height: desktop ? 14 : 12),
                                    _StatsStrip(
                                      saveService: widget.saveService,
                                      desktop: desktop,
                                    ),
                                    SizedBox(height: desktop ? 18 : 16),
                                    GameButton(
                                      label:
                                          'Start ${widget.saveService.selectedStage.shortName}',
                                      icon: Icons.play_arrow_rounded,
                                      color: const Color(0xFFFFB703),
                                      primary: true,
                                      onPressed: () => _open(context, '/play'),
                                    ),
                                    SizedBox(height: desktop ? 12 : 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GameButton(
                                            label: 'Map',
                                            icon: Icons.map_rounded,
                                            color: const Color(0xFF75B843),
                                            onPressed: () =>
                                                _open(context, '/map'),
                                          ),
                                        ),
                                        SizedBox(width: desktop ? 12 : 10),
                                        Expanded(
                                          child: GameButton(
                                            label: 'Garage',
                                            icon: Icons.garage_rounded,
                                            color: const Color(0xFFE0B46C),
                                            onPressed: () =>
                                                _open(context, '/garage'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: desktop ? 12 : 10),
                                    GameButton(
                                      label: 'Settings',
                                      icon: Icons.settings_rounded,
                                      color: const Color(0xFF2EA7A0),
                                      onPressed: () =>
                                          _open(context, '/settings'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 12),
                child: _AccountCornerButton(
                  saveService: widget.saveService,
                  onPressed: _openAccountDialog,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCornerButton extends StatelessWidget {
  const _AccountCornerButton({
    required this.saveService,
    required this.onPressed,
  });

  final SaveService saveService;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final signedIn = saveService.isSignedIn;
    final label = signedIn
        ? saveService.accountDisplayName
        : 'Sign in / Sign up';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xDD070B13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: signedIn
                  ? const Color(0xFF75B843)
                  : const Color(0x99E7FDFF),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 5),
                blurRadius: 12,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                signedIn
                    ? Icons.account_circle_rounded
                    : Icons.person_add_alt_1_rounded,
                color: signedIn
                    ? const Color(0xFF75B843)
                    : const Color(0xFFFFD166),
                size: 20,
              ),
              const SizedBox(width: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE7FDFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.saveService, required this.sfxService});

  final SaveService saveService;
  final SfxService sfxService;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _signUpMode = true;
  String _message = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.sfxService.unlock();
    final success = _signUpMode
        ? await widget.saveService.signUp(
            name: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          )
        : await widget.saveService.signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
    widget.sfxService.play(
      success ? SfxCue.buttonClick : SfxCue.crash,
      volume: success ? 0.45 : 0.18,
    );
    if (!mounted) {
      return;
    }
    if (success) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _message = _signUpMode
          ? 'Use a name, valid email, and password with at least 4 characters.'
          : 'Email or password does not match the saved local account.';
    });
  }

  Future<void> _signOut() async {
    await widget.saveService.signOut();
    widget.sfxService.play(SfxCue.buttonClick, volume: 0.45);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.saveService.isSignedIn;
    return AlertDialog(
      backgroundColor: const Color(0xF2070B13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x77E0B46C), width: 1.4),
      ),
      title: Row(
        children: [
          Icon(
            signedIn ? Icons.cloud_done_rounded : Icons.account_circle_rounded,
            color: const Color(0xFFFFD166),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              signedIn
                  ? 'Account'
                  : (_signUpMode ? 'Create Account' : 'Sign In'),
              style: const TextStyle(
                color: Color(0xFFE7FDFF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: signedIn
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AccountInfoRow(
                    label: 'Name',
                    value: widget.saveService.accountDisplayName,
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Email',
                    value: widget.saveService.accountEmail,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your coins, gems, vehicles, upgrades, best distance, and unlocked levels are saved locally on this device under this account. Cloud sync can be connected later.',
                    style: TextStyle(
                      color: Color(0xFF92A6C5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ModeChip(
                          label: 'Sign up',
                          selected: _signUpMode,
                          onTap: () => setState(() => _signUpMode = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ModeChip(
                          label: 'Sign in',
                          selected: !_signUpMode,
                          onTap: () => setState(() => _signUpMode = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_signUpMode) ...[
                    _AccountField(
                      controller: _nameController,
                      label: 'Player name',
                      icon: Icons.badge_rounded,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _AccountField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _AccountField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_rounded,
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _message.isEmpty
                        ? 'Prototype account: stores progress on this device now. Later this can be upgraded to cloud sync.'
                        : _message,
                    style: TextStyle(
                      color: _message.isEmpty
                          ? const Color(0xFF92A6C5)
                          : const Color(0xFFFF8A8A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (signedIn)
          FilledButton.tonalIcon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          )
        else
          FilledButton.icon(
            onPressed: _submit,
            icon: Icon(
              _signUpMode
                  ? Icons.person_add_alt_1_rounded
                  : Icons.login_rounded,
            ),
            label: Text(_signUpMode ? 'Create' : 'Sign in'),
          ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFB703) : const Color(0xFF172033),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x66E7FDFF)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? const Color(0xFF070B13) : const Color(0xFFE7FDFF),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Color(0xFFE7FDFF),
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFFFFD166)),
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF92A6C5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x557FD9DF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFFD166), width: 1.4),
        ),
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x337FD9DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: const TextStyle(
                color: Color(0xFF92A6C5),
                fontWeight: FontWeight.w900,
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE7FDFF),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTitle extends StatelessWidget {
  const _GameTitle({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final fontSize = desktop ? 68.0 : 50.0;
    final strokeWidth = desktop ? 8.0 : 6.5;

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.72, end: 1),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOut,
          builder: (context, value, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: const Offset(0, 7),
                  child: Text(
                    'Hill Rider',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                      color: const Color(
                        0xFFE0B46C,
                      ).withValues(alpha: 0.16 + value * 0.18),
                    ),
                  ),
                ),
                Text(
                  'Hill Rider',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 0.9,
                    fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = strokeWidth
                      ..color = const Color(0xFF030712),
                  ),
                ),
                Text(
                  'Hill Rider',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 0.9,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE7FDFF),
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: desktop ? 8 : 6),
        DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE0B46C).withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            height: desktop ? 8 : 7,
            width: desktop ? 230 : 166,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB703), Color(0xFF75B843)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE7FDFF), width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewBay extends StatelessWidget {
  const _PreviewBay({required this.desktop, required this.saveService});

  final bool desktop;
  final SaveService saveService;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9070B13),
        borderRadius: BorderRadius.circular(desktop ? 24 : 20),
        border: Border.all(color: const Color(0x77E0B46C), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0B46C).withValues(alpha: 0.18),
            blurRadius: desktop ? 24 : 18,
            offset: const Offset(0, 8),
          ),
          const BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 6, 14, desktop ? 10 : 8),
        child: BuggyPreview(
          height: desktop ? 188 : 136,
          vehicle: saveService.selectedVehicle,
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.saveService, required this.desktop});

  final SaveService saveService;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final best = saveService
        .stageBestDistance(saveService.selectedStage.id)
        .floor();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9070B13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x66E0B46C), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0B46C).withValues(alpha: 0.13),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: desktop ? 18 : 14,
          vertical: desktop ? 12 : 10,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatBadge(
              icon: Icons.monetization_on_rounded,
              label: '${saveService.totalCoins}',
              desktop: desktop,
            ),
            _StatBadge(
              icon: Icons.diamond_rounded,
              label: '${saveService.totalGems}',
              desktop: desktop,
            ),
            _StatBadge(
              icon: Icons.flag_rounded,
              label:
                  'L${saveService.selectedStage.levelNumber} ${saveService.selectedStage.shortName}  ${saveService.selectedStage.goalMeters}m  Best ${best}m',
              desktop: desktop,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.desktop,
  });

  final IconData icon;
  final String label;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFFB703), size: desktop ? 25 : 22),
          SizedBox(width: desktop ? 8 : 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: desktop ? 19 : 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFE7FDFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
