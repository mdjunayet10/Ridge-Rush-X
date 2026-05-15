import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import 'save_service.dart';

enum SfxCue {
  buttonClick,
  coinCollect,
  fuelCollect,
  crash,
  engineTick,
  skid,
  jump,
  landing,
}

class SfxService {
  SfxService({required this.saveService});

  final SaveService saveService;

  Future<void>? _preloadFuture;
  Future<void>? _unlockFuture;
  AudioPool? _buttonPool;
  AudioPool? _coinPool;
  AudioPool? _fuelPool;
  bool _unlocked = false;
  DateTime _lastEngineTick = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSkid = DateTime.fromMillisecondsSinceEpoch(0);

  static const _files = <SfxCue, String>{
    SfxCue.buttonClick: 'sfx/button_click.wav',
    SfxCue.coinCollect: 'sfx/coin_collect.wav',
    SfxCue.fuelCollect: 'sfx/fuel_collect.wav',
    SfxCue.crash: 'sfx/crash.wav',
    SfxCue.engineTick: 'sfx/engine_tick.wav',
    SfxCue.skid: 'sfx/skid.wav',
    SfxCue.jump: 'sfx/jump.wav',
    SfxCue.landing: 'sfx/landing.wav',
  };

  Future<void> preload() {
    return _preloadFuture ??= _doPreload();
  }

  Future<void> unlock() {
    return _unlockFuture ??= _doUnlock();
  }

  void play(SfxCue cue, {double volume = 1}) {
    if (!saveService.soundEffectsEnabled) {
      return;
    }

    final file = _files[cue];
    if (file == null) {
      return;
    }

    final safeVolume = volume.clamp(0, 1).toDouble();
    unawaited(_playCue(cue, file, safeVolume));
  }

  void playEngineTick({
    required double throttle,
    required double speedFraction,
  }) {
    if (!saveService.soundEffectsEnabled || throttle <= 0) {
      return;
    }

    final now = DateTime.now();
    final intervalMs = (410 - speedFraction.clamp(0, 1) * 80).round();
    if (now.difference(_lastEngineTick).inMilliseconds < intervalMs) {
      return;
    }

    _lastEngineTick = now;
    play(
      SfxCue.engineTick,
      volume:
          0.028 +
          throttle.clamp(0, 1) * 0.045 +
          speedFraction.clamp(0, 1) * 0.025,
    );
  }

  void playSkid() {
    if (!saveService.soundEffectsEnabled) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastSkid).inMilliseconds < 760) {
      return;
    }

    _lastSkid = now;
    play(SfxCue.skid, volume: 0.08);
  }

  Future<void> dispose() async {
    await _buttonPool?.dispose();
    await _coinPool?.dispose();
    await _fuelPool?.dispose();
    _buttonPool = null;
    _coinPool = null;
    _fuelPool = null;
  }

  Future<void> _doPreload() async {
    try {
      await FlameAudio.audioCache.loadAll(_files.values.toSet().toList());
      _buttonPool ??= await FlameAudio.createPool(
        _files[SfxCue.buttonClick]!,
        minPlayers: 2,
        maxPlayers: 5,
      );
      _coinPool ??= await FlameAudio.createPool(
        _files[SfxCue.coinCollect]!,
        minPlayers: 3,
        maxPlayers: 8,
      );
      _fuelPool ??= await FlameAudio.createPool(
        _files[SfxCue.fuelCollect]!,
        minPlayers: 2,
        maxPlayers: 4,
      );
    } catch (error, stackTrace) {
      _preloadFuture = null;
      _logAudioError('preload', error, stackTrace);
    }
  }

  Future<void> _doUnlock() async {
    try {
      await preload();
      _unlocked = true;
      final file = _files[SfxCue.buttonClick]!;
      final player = await FlameAudio.play(file, volume: 0);
      await player.stop();
      await player.dispose();
    } catch (error, stackTrace) {
      _unlockFuture = null;
      _logAudioError('unlock', error, stackTrace);
    }
  }

  Future<void> _playCue(SfxCue cue, String file, double volume) async {
    try {
      await preload();
      if (!_unlocked) {
        return;
      }

      if (cue == SfxCue.coinCollect && _coinPool != null) {
        await _coinPool!.start(volume: volume);
        return;
      }
      if (cue == SfxCue.buttonClick && _buttonPool != null) {
        await _buttonPool!.start(volume: volume);
        return;
      }
      if (cue == SfxCue.fuelCollect && _fuelPool != null) {
        await _fuelPool!.start(volume: volume);
        return;
      }

      await FlameAudio.play(file, volume: volume);
    } catch (error, stackTrace) {
      _logAudioError('play $cue', error, stackTrace);
    }
  }

  void _logAudioError(String action, Object error, StackTrace stackTrace) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('SfxService $action failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
