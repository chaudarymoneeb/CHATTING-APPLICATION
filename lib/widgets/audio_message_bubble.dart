// lib/widgets/audio_message_bubble.dart
//
// Playback UI for a voice message: play/pause button + progress slider +
// elapsed/total duration. Add `audioplayers: ^6.0.0` to pubspec.yaml.

import 'package:audioplayers/audioplayers.dart';
import 'package:chat_app/app_constant.dart';
import 'package:flutter/material.dart';

class AudioMessageBubble extends StatefulWidget {
  const AudioMessageBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  final String audioUrl;
  final bool isMe;

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _player.play(UrlSource(widget.audioUrl));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final fgColor = widget.isMe ? Colors.white : AppColors.primaryGreen;
    final total = _duration.inMilliseconds == 0
        ? const Duration(seconds: 1)
        : _duration;

    return SizedBox(
      width: 210,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _isLoading ? null : _togglePlayback,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: _isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fgColor,
                      ),
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      color: fgColor,
                      size: 32,
                    ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: fgColor,
                    thumbColor: fgColor,
                    inactiveTrackColor: fgColor.withValues(alpha: 0.25),
                  ),
                  child: Slider(
                    min: 0,
                    max: total.inMilliseconds.toDouble(),
                    value: _position.inMilliseconds
                        .clamp(0, total.inMilliseconds)
                        .toDouble(),
                    onChanged: (value) {
                      _player.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                Text(
                  '${_format(_position)} / ${_format(_duration)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isMe ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
