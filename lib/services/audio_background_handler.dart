import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

/// Global singleton handler instance
NFileAudioHandler? _audioHandlerInstance;

/// Returns the global audio handler, creating it lazily if needed.
NFileAudioHandler getAudioHandler() {
  _audioHandlerInstance ??= NFileAudioHandler._();
  return _audioHandlerInstance!;
}

/// Bridges media_kit [Player] to [audio_service] so the OS shows a proper
/// media notification with play / pause / skip controls.
class NFileAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  NFileAudioHandler._();

  Player? _player;
  final List<StreamSubscription<dynamic>> _subs = [];

  // ─── Attach / detach ────────────────────────────────────────────────────

  /// Call this whenever you want background mode to start (or restart with a
  /// new player / queue).
  void attach({
    required Player player,
    required List<MediaItem> queue,
    required int currentIndex,
  }) {
    detach();
    _player = player;

    // Push the queue
    this.queue.add(queue);
    if (queue.isNotEmpty) {
      mediaItem.add(queue[currentIndex]);
    }

    // Mirror playing state
    _subs.add(player.stream.playing.listen((playing) {
      _emitPlaybackState(playing: playing);
    }));

    // Mirror position
    _subs.add(player.stream.position.listen((pos) {
      _emitPlaybackState(playing: _player?.state.playing ?? false, position: pos);
    }));

    // Mirror track completion → advance
    _subs.add(player.stream.completed.listen((completed) {
      if (completed) skipToNext();
    }));
  }

  void detach() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player = null;
  }

  // ─── AudioHandler overrides ─────────────────────────────────────────────

  @override
  Future<void> play() async {
    await _player?.play();
  }

  @override
  Future<void> pause() async {
    await _player?.pause();
  }

  @override
  Future<void> stop() async {
    detach();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
    ));
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    final q = queue.value;
    final current = mediaItem.value;
    if (q.isEmpty || current == null) return;
    final idx = q.indexOf(current);
    final nextIdx = (idx + 1) % q.length;
    mediaItem.add(q[nextIdx]);
    // Actual file open is handled by the screen listener
    _onSkipCallback?.call(nextIdx);
  }

  @override
  Future<void> skipToPrevious() async {
    final q = queue.value;
    final current = mediaItem.value;
    if (q.isEmpty || current == null) return;
    final idx = q.indexOf(current);
    final prevIdx = (idx - 1 + q.length) % q.length;
    mediaItem.add(q[prevIdx]);
    _onSkipCallback?.call(prevIdx);
  }

  // ─── Callback for skip (screen must update player) ──────────────────────

  void Function(int index)? _onSkipCallback;

  void setSkipCallback(void Function(int index) cb) {
    _onSkipCallback = cb;
  }

  /// Update the current media item displayed in the notification.
  void updateCurrentItem(MediaItem item) {
    mediaItem.add(item);
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  void _emitPlaybackState({
    required bool playing,
    Duration position = Duration.zero,
  }) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: position,
        bufferedPosition: position,
        speed: _player?.state.rate ?? 1.0,
      ),
    );
  }
}
