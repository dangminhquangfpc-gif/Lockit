import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/models.dart';

class PhotoViewer extends StatelessWidget {
  const PhotoViewer(
      {super.key,
      required this.moment,
      required this.bytes,
      this.demo = false});
  final Moment moment;
  final Uint8List bytes;
  final bool demo;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF162E28),
        appBar: AppBar(
            backgroundColor: const Color(0xFF162E28),
            foregroundColor: Colors.white,
            title: Text(moment.author.name)),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                      child: Image.memory(bytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text(
                              'Ảnh không đọc được.',
                              style: TextStyle(color: Colors.white)))))),
          Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                if (moment.caption.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(moment.caption,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18))),
                Text(
                    '${dayLabel(moment.createdAt)} · ${demo ? 'Ảnh trải nghiệm trong phiên' : 'Chỉ bạn bè'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                const Text('Dùng hai ngón tay để phóng to ảnh',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
        ])),
      );
}
