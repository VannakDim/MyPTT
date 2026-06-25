import 'dart:convert';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String? imageUrl;
  final String? base64Data; // data:image/...;base64,...

  const FullScreenImageViewer({
    super.key,
    this.imageUrl,
    this.base64Data,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    if (base64Data != null) {
      try {
        final base64Val = base64Data!.split(',').last;
        final bytes = base64Decode(base64Val);
        imageProvider = MemoryImage(bytes);
      } catch (e) {
        imageProvider = const AssetImage('assets/placeholder.png'); // fallback
      }
    } else if (imageUrl != null) {
      imageProvider = NetworkImage(imageUrl!);
    } else {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              clipBehavior: Clip.none,
              child: Image(
                image: imageProvider,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
