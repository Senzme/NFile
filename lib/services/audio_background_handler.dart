import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../ui/screens/audio_player/audio_artwork_widget.dart';

/// Global singleton handler instance
NFileAudioHandler? _audioHandlerInstance;

/// Returns the global audio handler, creating it lazily if needed.
NFileAudioHandler getAudioHandler() {
  _audioHandlerInstance ??= NFileAudioHandler._();
  return _audioHandlerInstance!;
}

/// Utility to query artwork bytes, cache them locally in a temporary directory,
/// and return the local file [Uri] for the [MediaItem].
Future<Uri?> getArtworkUri(int audioId) async {
  if (audioId <= 0) return null;
  try {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/artwork_$audioId.png');
    if (await file.exists()) {
      return file.uri;
    }
    final data = await AudioArtworkCache.getArtwork(audioId);
    if (data != null && data.isNotEmpty) {
      await file.writeAsBytes(data);
      return file.uri;
    }
  } catch (e) {
    debugPrint('[NFile] Error getting artwork URI: $e');
  }
  return null;
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
    final oldPlayer = _player;
    if (oldPlayer != null && oldPlayer != player) {
      Future.microtask(() async {
        try {
          await oldPlayer.dispose();
        } catch (e) {
          debugPrint('[NFile] Error disposing old player: $e');
        }
      });
    }

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

    // Mirror track completion → advance (only when background, otherwise let screen handle it)
    _subs.add(player.stream.completed.listen((completed) {
      if (completed && _onSkipCallback == null) {
        skipToNext();
      }
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
    playbackState.add(PlaybackState(
      controls: [],
      playing: false,
      processingState: AudioProcessingState.idle,
    ));

    final playerToDispose = _player;
    if (playerToDispose != null) {
      try {
        await playerToDispose.dispose();
      } catch (e) {
        debugPrint('[NFile] Error disposing player on stop: $e');
      }
    }

    detach();
    await super.stop();
  }

  /// Clears and dismisses the background media notification completely,
  /// but keeps the active player alive for foreground playback.
  void stopNotification() {
    playbackState.add(PlaybackState(
      controls: [],
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    detach();
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
    final nextItem = q[nextIdx];
    mediaItem.add(nextItem);

    if (_onSkipCallback != null) {
      _onSkipCallback?.call(nextIdx);
    } else {
      if (_player != null) {
        await _player!.open(Media(nextItem.id), play: true);
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final q = queue.value;
    final current = mediaItem.value;
    if (q.isEmpty || current == null) return;
    final idx = q.indexOf(current);
    final prevIdx = (idx - 1 + q.length) % q.length;
    final prevItem = q[prevIdx];
    mediaItem.add(prevItem);

    if (_onSkipCallback != null) {
      _onSkipCallback?.call(prevIdx);
    } else {
      if (_player != null) {
        await _player!.open(Media(prevItem.id), play: true);
      }
    }
  }

  // ─── Callback for skip (screen must update player) ──────────────────────

  void Function(int index)? _onSkipCallback;

  void setSkipCallback(void Function(int index)? cb) {
    _onSkipCallback = cb;
  }

  /// Update the current media item displayed in the notification.
  void updateCurrentItem(MediaItem item) {
    mediaItem.add(item);
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  void _emitPlaybackState({
    required bool playing,
    Duration? position,
  }) {
    final currentPos = position ?? _player?.state.position ?? Duration.zero;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          const MediaControl(
            androidIcon: 'drawable/ic_close',
            label: 'Close',
            action: MediaAction.stop,
          ),
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: currentPos,
        bufferedPosition: currentPos,
        speed: _player?.state.rate ?? 1.0,
      ),
    );
  }
}
