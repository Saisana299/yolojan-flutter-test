import 'dart:io';

import 'package:camera/camera.dart';
import 'package:custom_ratio_camera/custom_ratio_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:yolojan/theme.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Camera Demo',
      theme: appTheme(),
      home: const CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => CameraPageState();
}

class CameraPageState extends State<CameraPage> {
  late CameraController controller;
  late Future<void> initializeControllerFuture;

  @override
  void initState() {
    super.initState();

    controller = CameraController(
      _cameras[0],
      ResolutionPreset.max,
    );

    initializeControllerFuture = controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: Center(
          child: FutureBuilder<void>(
            future: initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return AspectRatio(
                  aspectRatio: 16/9,
                  child: CustomRatioCameraPreview(
                    cameraController: controller,
                    expectedRatio: 16/9
                  )
                );
              } else {
                return const CircularProgressIndicator();
              }
            },
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final image = await controller.takePicture();
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DisplayPictureScreen(image: image),
              fullscreenDialog: true,
            )
          );
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

class DisplayPictureScreen extends StatelessWidget {
  const DisplayPictureScreen({super.key, required this.image});

  final XFile image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Captured Photo')),
      body: Center(child: Image.file(File(image.path))),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final Uint8List buffer = await image.readAsBytes();
          await ImageGallerySaverPlus.saveImage(buffer, name: image.name);
          if(context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image saved.')),
            );
            Navigator.of(context).pop();
          }
        },
        child: const Icon(Icons.save_alt),
      ),
    );
  }
}