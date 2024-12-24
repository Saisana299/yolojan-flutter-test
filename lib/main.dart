import 'dart:io';

import 'package:camera/camera.dart';
import 'package:custom_ratio_camera/custom_ratio_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:yolojan/theme.dart';
import 'package:yolojan/utils/camera_view_singleton.dart';

late List<CameraDescription> _cameras;
int _camFrameRotation = 0;

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
  late List<ResultObjectDetection> yoloResults;

  late ModelObjectDetection _objectModel;

  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();
    initStateAsync();
  }

  void initStateAsync() async {
    await loadYoloModel();
    initializeCamera();
    setState(() {
      isLoaded = true;
      isDetecting = false;
      yoloResults = [];
    });
  }

  Future loadYoloModel() async {
    _objectModel = await PytorchLite.loadObjectDetectionModel(
      "assets/yolov8n.torchscript", 80, 640, 640,
      labelPath: "assets/labels.txt",
      objectDetectionModelType: ObjectDetectionModelType.yolov8
    );
    setState(() {
      isLoaded = true;
    });
  }

  void initializeCamera() async {
    var idx =
        _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    if (idx < 0) {
      // log("No Back camera found - weird");
      return;
    }
    var desc = _cameras[idx];
    _camFrameRotation = Platform.isAndroid ? desc.sensorOrientation : 0;

    controller = CameraController(
      desc,
      ResolutionPreset.high,
      imageFormatGroup: Platform.isAndroid
        ? ImageFormatGroup.yuv420
        : ImageFormatGroup.bgra8888,
      enableAudio: false,
    );

    initializeControllerFuture = controller.initialize().then((_) async {
      Size? previewSize = controller.value.previewSize;
      CameraViewSingleton.inputImageSize = previewSize!;
      if(mounted) {
        Size screenSize = MediaQuery.of(context).size;
        CameraViewSingleton.screenSize = screenSize;
        CameraViewSingleton.ratio = controller.value.aspectRatio;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: Text("Model not loaded, waiting for it"),
        ),
      );
    }
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: Center(
          child: FutureBuilder<void>(
            future: initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16/9,
                      child: CustomRatioCameraPreview(
                        cameraController: controller,
                        expectedRatio: 16/9,
                      ),
                    ),
                    ...boxWidget(),
                  ],
                );
              } else {
                return const CircularProgressIndicator();
              }
            },
          ),
        ),
      ),

      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
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
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: () {
              if(isDetecting) {
                stopDetection();
              } else {
                startDetection();
              }
            },
            child: Icon(isDetecting ? Icons.stop : Icons.play_arrow),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() async {
    controller.dispose();
    super.dispose();
  }

  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    List<ResultObjectDetection> objDetect = await _objectModel.getCameraImagePrediction(
      cameraImage,
      _camFrameRotation,
      minimumScore: 0.1,
      iOUThreshold: 0.3
    );
    setState(() {
      yoloResults = objDetect;
    });
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    if(controller.value.isStreamingImages) {
      return;
    }
    await controller.startImageStream((image) async {
      if (isDetecting) {
        cameraImage = image;
        yoloOnFrame(image);
      }
    });
  }

  Future<void> stopDetection() async {
    await controller.stopImageStream();
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
  }

  List<Widget> boxWidget() {
    if (yoloResults.isEmpty) return [];

    Color? usedColor = Colors.red;//todo

    Size screenSize = CameraViewSingleton.actualPreviewSizeH;
    double factorX = screenSize.width;
    double factorY = screenSize.height;

    return yoloResults.map((result) {
      return Positioned(
        left: result.rect.left * factorX,
        top: result.rect.top * factorY,
        width: result.rect.width * factorX,
        height: result.rect.height * factorY,

        //left: re?.rect.left.toDouble(),
        //top: re?.rect.top.toDouble(),
        //right: re.rect.right.toDouble(),
        //bottom: re.rect.bottom.toDouble(),
        child: Container(
          width: result.rect.width * factorX,
          height: result.rect.height * factorY,
          decoration: BoxDecoration(
              border: Border.all(color: usedColor!, width: 3),
              borderRadius: const BorderRadius.all(Radius.circular(2))),
          child: Align(
            alignment: Alignment.topLeft,
            child: FittedBox(
              child: Container(
                color: usedColor,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(result.className ?? result.classIndex.toString()),
                    Text(" ${result.score.toStringAsFixed(2)}"),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
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
        child: const Icon(Icons.save),
      ),
    );
  }
}