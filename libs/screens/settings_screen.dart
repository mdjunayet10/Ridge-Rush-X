import 'package:flutter/material.dart';

import '../services/save_service.dart';
import '../services/sfx_service.dart';
import '../widgets/cartoon_background.dart';
import '../widgets/game_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.saveService,
    required this.sfxService,
    super.key,
  });

  final SaveService saveService;
  final SfxService sfxService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _setSoundEffects(bool value) async {
    final wasEnabled = widget.saveService.soundEffectsEnabled;
    await widget.sfxService.unlock();
    await widget.saveService.setSoundEffectsEnabled(value);
    if (value || wasEnabled) {
      widget.sfxService.play(SfxCue.buttonClick, volume: 0.45);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setPerformanceMode(bool value) async {
    await widget.sfxService.unlock();
    await widget.saveService.setPerformanceModeEnabled(value);
    widget.sfxService.play(SfxCue.buttonClick, volume: 0.45);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _resetProgress() async {
    await widget.sfxService.unlock();
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF070B13),
          title: const Text('Reset progress?'),
          content: const Text(
            'Coins, best distance, upgrades, and vehicles will return to the starting state.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await widget.saveService.resetProgress();
    widget.sfxService.play(SfxCue.buttonClick, volume: 0.45);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CartoonBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 720;
              final width = constraints.maxWidth
                  .clamp(340, desktop ? 900 : 520)
                  .toDouble();

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: const Text('Settings'),
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFFE7FDFF),
                    elevation: 0,
                    pinned: true,
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: SizedBox(
                        width: width,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 28 : 18,
                            12,
                            desktop ? 28 : 18,
                            30,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SettingsHeader(desktop: desktop),
                              SizedBox(height: desktop ? 20 : 14),
                              _SettingsTile(
                                icon: Icons.volume_up_rounded,
                                title: 'SFX',
                                subtitle:
                                    'Buttons, pickups, engine, jumps, landings, and crashes.',
                                trailing: Switch(
                                  value: widget.saveService.soundEffectsEnabled,
                                  activeThumbColor: const Color(0xFFFFD166),
                                  onChanged: _setSoundEffects,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _SettingsTile(
                                icon: Icons.speed_rounded,
                                title: 'Performance Mode',
                                subtitle:
                                    'Fewer particles and lighter road rendering.',
                                trailing: Switch(
                                  value:
                                      widget.saveService.performanceModeEnabled,
                                  activeThumbColor: const Color(0xFFFFD166),
                                  onChanged: _setPerformanceMode,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const _InfoCard(
                                icon: Icons.touch_app_rounded,
                                title: 'Controls',
                                body:
                                    'BRAKE left, GAS right. Keyboard: A/Left and D/Right.',
                              ),
                              const SizedBox(height: 14),
                              _ProgressCard(saveService: widget.saveService),
                              const SizedBox(height: 18),
                              GameButton(
                                label: 'Reset Progress',
                                icon: Icons.restart_alt_rounded,
                                color: const Color(0xFFFF3D81),
                                onPressed: _resetProgress,
                              ),
                              const SizedBox(height: 14),
                              const _InfoCard(
                                icon: Icons.info_outline_rounded,
                                title: 'Hill Rider v0.4',
                                body:
                                    'Original Golden Mountain Day Ride prototype. Web first, Android/mobile next.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Text(
      'RIDE SETTINGS',
      style: TextStyle(
        color: const Color(0xFFE7FDFF),
        fontSize: desktop ? 34 : 24,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: [
          _PanelIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PanelTitle(title),
                const SizedBox(height: 4),
                _PanelBody(subtitle),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PanelTitle(title),
                const SizedBox(height: 5),
                _PanelBody(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.saveService});

  final SaveService saveService;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: [
          const _PanelIcon(icon: Icons.speed_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelTitle('Progress'),
                const SizedBox(height: 5),
                _PanelBody(
                  '${saveService.totalCoins} coins  /  ${saveService.bestDistanceMeters.floor()}m best  /  ${saveService.completedRuns} runs',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6070B13),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x66E0B46C), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0B46C).withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          const BoxShadow(
            color: Color(0x88000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _PanelIcon extends StatelessWidget {
  const _PanelIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x22E0B46C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66E0B46C)),
      ),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Icon(icon, color: const Color(0xFFFFD166), size: 29),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFE7FDFF),
        fontSize: 19,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF92A6C5),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
