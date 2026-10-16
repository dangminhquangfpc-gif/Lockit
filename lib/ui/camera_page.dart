import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../data/models.dart';
import 'common.dart';

class CameraPage extends StatefulWidget {
  const CameraPage(
      {super.key,
      required this.repository,
      this.loadCameras,
      this.localOnly = false});
  final SocialRepository repository;
  final bool localOnly;
  final Future<List<CameraDescription>> Function()? loadCameras;
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _devices = [];
  final _caption = TextEditingController();
  Uint8List? _image;
  String? _error;
  bool _initializing = true;
  bool _taking = false;
  bool _sending = false;
  bool _flash = false;
  bool _active = true;
  int _index = 0;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<int> _release() async {
    final generation = ++_generation;
    final previous = _controller;
    _controller = null;
    if (previous != null) {
      try {
        await previous.dispose();
      } catch (_) {/* Already disconnected. */}
    }
    return generation;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _release();
    } else if (_image == null) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    final generation = await _release();
    if (!mounted || !_active || generation != _generation) return;
    setState(() {
      _initializing = true;
      _error = null;
      _flash = false;
    });
    CameraController? next;
    try {
      _devices = await (widget.loadCameras ?? availableCameras)();
      if (!mounted || generation != _generation || !_active) return;
      if (_devices.isEmpty) {
        setState(() => _error = 'Không tìm thấy camera trên thiết bị này.');
        return;
      }
      if (_index >= _devices.length) _index = 0;
      next = CameraController(_devices[_index], ResolutionPreset.high,
          enableAudio: false);
      await next.initialize();
      if (!mounted || generation != _generation || !_active) {
        await next.dispose();
        return;
      }
      setState(() => _controller = next);
    } on CameraException catch (error) {
      if (next != null) {
        try {
          await next.dispose();
        } catch (_) {}
      }
      if (mounted && generation == _generation) {
        setState(() {
          _error = error.code.contains('Access')
              ? 'Hãy cho phép Lockit dùng camera trong phần Cài đặt của điện thoại, rồi thử lại.'
              : 'Chưa mở được camera. Hãy thử lại.';
        });
      }
    } catch (_) {
      if (next != null) {
        try {
          await next.dispose();
        } catch (_) {}
      }
      if (mounted && generation == _generation) {
        setState(() => _error = 'Chưa mở được camera. Hãy thử lại.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _initializing = false);
      }
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _taking) {
      return;
    }
    setState(() => _taking = true);
    final generation = _generation;
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted && generation == _generation) {
        setState(() => _image = bytes);
        await _release();
      }
    } catch (_) {
      if (mounted) notice(context, 'Không chụp được ảnh. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || _taking) return;
    setState(() => _taking = true);
    try {
      await controller.setFlashMode(_flash ? FlashMode.off : FlashMode.auto);
      if (mounted) setState(() => _flash = !_flash);
    } catch (_) {
      if (mounted) notice(context, 'Camera này không hỗ trợ đèn flash.');
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _image == null) return;
    setState(() => _sending = true);
    try {
      await widget.repository.publish(_image!, _caption.text);
      if (mounted) {
        notice(
            context,
            widget.localOnly
                ? 'Đã lưu ảnh trong phiên thử.'
                : 'Đã chia sẻ khoảnh khắc của bạn!');
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) notice(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: const Color(0xFF162E28),
        appBar: AppBar(
            title: Text(widget.localOnly ? 'Chụp ảnh thử' : 'Hôm nay của bạn'),
            backgroundColor: const Color(0xFF162E28),
            foregroundColor: Colors.white),
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Text('Giữ lại một điều bình dị.',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 24),
            ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(
                    color: Colors.black26,
                    child: _image != null
                        ? Image.memory(_image!, fit: BoxFit.cover)
                        : _error != null
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      const Icon(Icons.no_photography_outlined,
                                          color: Colors.white, size: 40),
                                      const SizedBox(height: 16),
                                      Text(_error!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white)),
                                      TextButton(
                                          onPressed: _initialize,
                                          child: const Text('Thử lại',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                    ])))
                            : _initializing || controller == null
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white))
                                : Center(child: CameraPreview(controller)),
                  ),
                )),
            const SizedBox(height: 24),
            if (_image != null) ...[
              TextField(
                  controller: _caption,
                  maxLength: 280,
                  minLines: 1,
                  maxLines: 3,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                      hintText: 'Một vài lời cho khoảnh khắc này…',
                      counterStyle: TextStyle(color: Colors.white70))),
              const SizedBox(height: 8),
              Text(
                  widget.localOnly
                      ? 'Ảnh chỉ lưu trong phiên thử, không gửi cho người khác.\nThoát phiên sẽ xóa ảnh thử.'
                      : 'Chia sẻ với tất cả bạn bè đã kết bạn.\nBạn bè mới cũng xem được những ảnh trước đây.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF4C95D),
                          foregroundColor: Colors.black87),
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(_sending
                          ? 'Đang lưu…'
                          : widget.localOnly
                              ? 'Lưu ảnh thử'
                              : 'Chia sẻ khoảnh khắc'))),
              TextButton(
                  onPressed: _sending
                      ? null
                      : () {
                          setState(() {
                            _image = null;
                            _caption.clear();
                          });
                          _initialize();
                        },
                  child: const Text('Chụp lại',
                      style: TextStyle(color: Colors.white))),
            ] else
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(
                    tooltip: 'Đèn flash',
                    onPressed:
                        controller == null || _taking ? null : _toggleFlash,
                    icon: Icon(_flash ? Icons.flash_auto : Icons.flash_off,
                        color: Colors.white)),
                Semantics(
                    label: 'Chụp ảnh',
                    button: true,
                    child: SizedBox(
                        width: 88,
                        height: 88,
                        child: FilledButton(
                            onPressed:
                                controller == null || _taking ? null : _capture,
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF4C95D),
                                shape: const CircleBorder()),
                            child: _taking
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator())
                                : const Icon(Icons.camera_alt,
                                    size: 36, color: Color(0xFF162E28))))),
                IconButton(
                    tooltip: 'Đổi camera',
                    onPressed: _devices.length < 2 || _taking || _initializing
                        ? null
                        : () {
                            _index = (_index + 1) % _devices.length;
                            _initialize();
                          },
                    icon: const Icon(Icons.cameraswitch_outlined,
                        color: Colors.white)),
              ]),
          ]),
        )),
      ),
    );
  }
}
