import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String? imageUrl;
  final String? base64Data; // data:image/...;base64,...

  const FullScreenImageViewer({
    super.key,
    this.imageUrl,
    this.base64Data,
  });

  Future<void> _downloadImage(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("កំពុងរក្សាទុករូបភាព..."), duration: Duration(seconds: 2)),
      );

      Uint8List bytes;
      String extension = 'jpg';
      
      if (base64Data != null) {
        final base64Val = base64Data!.split(',').last;
        bytes = base64Decode(base64Val);
        if (base64Data!.contains("image/png")) {
          extension = 'png';
        } else if (base64Data!.contains("image/gif")) {
          extension = 'gif';
        }
      } else if (imageUrl != null) {
        final response = await http.get(Uri.parse(imageUrl!));
        if (response.statusCode != 200) {
          throw Exception("Server status: ${response.statusCode}");
        }
        bytes = response.bodyBytes;
        final uri = Uri.parse(imageUrl!);
        final path = uri.path;
        final dotIndex = path.lastIndexOf('.');
        if (dotIndex != -1) {
          extension = path.substring(dotIndex + 1);
        }
      } else {
        return;
      }

      Directory? dir;
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          dir = await getExternalStorageDirectory();
        } else {
          dir = Directory('/storage/emulated/0/Download');
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        throw Exception("មិនអាចរកឃើញទីតាំងរក្សាទុកឯកសារ");
      }

      final fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final savePath = '${dir.path}/$fileName';
      final file = File(savePath);
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("📥 រក្សាទុករូបភាពជោគជ័យ! រក្សាទុកនៅ៖ $savePath"),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error downloading image: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ រក្សាទុកបរាជ័យ៖ $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    if (base64Data != null) {
      try {
        final base64Val = base64Data!.split(',').last;
        final bytes = base64Decode(base64Val);
        imageProvider = MemoryImage(bytes);
      } catch (e) {
        imageProvider = const AssetImage('assets/placeholder.png');
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
          // Back Button
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
          // Download Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                onPressed: () => _downloadImage(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
