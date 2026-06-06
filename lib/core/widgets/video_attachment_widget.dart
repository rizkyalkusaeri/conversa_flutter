import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoAttachmentWidget extends StatefulWidget {
  final String videoUrl;
  final double? height;
  final double? width;
  final bool autoPlay;
  final bool looping;

  const VideoAttachmentWidget({
    super.key,
    required this.videoUrl,
    this.height,
    this.width,
    this.autoPlay = false,
    this.looping = false,
  });

  @override
  State<VideoAttachmentWidget> createState() => _VideoAttachmentWidgetState();
}

class _VideoAttachmentWidgetState extends State<VideoAttachmentWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: widget.autoPlay,
        looping: widget.looping,
        aspectRatio: 16 / 9,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 42),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: widget.height ?? 200,
        width: widget.width ?? double.infinity,
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: Colors.grey, size: 40),
              SizedBox(height: 8),
              Text(
                'Gagal memuat video',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_chewieController == null ||
        !_chewieController!.videoPlayerController.value.isInitialized) {
      return Container(
        height: widget.height ?? 200,
        width: widget.width ?? double.infinity,
        color: Colors.black12,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Force horizontal aspect ratio (e.g. 16/9) to avoid vertical overflow
    const double forcedAspectRatio = 16 / 9;
    final double maxHeight = widget.height ?? 250;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: widget.width ?? MediaQuery.of(context).size.width * 0.85,
      ),
      child: AspectRatio(
        aspectRatio: forcedAspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
