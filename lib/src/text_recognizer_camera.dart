import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:screenshot/screenshot.dart';

class TextRecognizerCamera extends StatefulWidget {
  const TextRecognizerCamera({
    super.key,
    required this.onTextRecognised,
    required this.onValidText,
    this.textCorrection,
    this.cameraSize,
  });

  final void Function(String) onTextRecognised;
  final bool Function(String) onValidText;
  final String Function(String)? textCorrection;
  final Size? cameraSize;

  @override
  State<TextRecognizerCamera> createState() => _TextRecognizerCameraState();
}

class _TextRecognizerCameraState extends State<TextRecognizerCamera> {
  final screenshotController = ScreenshotController();
  late List<CameraDescription> _cameras;
  late CameraController cameraController;
  var loadedCamera = false;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    _cameras = await availableCameras();
    cameraController = CameraController(
      _cameras[0],
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21 // for Android
          : ImageFormatGroup.bgra8888, // for iOS,
    );
    await cameraController.initialize();

    setState(() {
      loadedCamera = true;
    });

    imageStream();
    // cameraController.startImageStream(imageStream);
  }

  Future<void> imageStream() async {
    Future.delayed(const Duration(seconds: 1), () async {
      // final inputImage = Utils.inputImageFromCameraImage(
      //   image: image,
      //   camera: _cameras[0],
      //   deviceOrientation: cameraController.value.deviceOrientation,
      // );

      final xFile = await cameraController.takePicture();
      final path = xFile.path;
      final imageWidget = await screenshotController.capture();
      final finalFile = await File(path).writeAsBytes(imageWidget!);
      final inputImage = InputImage.fromFile(finalFile);

      final textDetector = TextRecognizer();
      final recognisedText = await textDetector.processImage(inputImage);
      textDetector.close();

      for (var block in recognisedText.blocks) {
        final correctedText = widget.textCorrection?.call(block.text) ?? block.text;
        if (widget.onValidText(correctedText)) {
          widget.onTextRecognised(correctedText.replaceAll(' ', ''));
        }
      }

      // widget.onTextRecognised(recognisedText.text);
      // log(recognisedText.text);

      imageStream();
    });
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loadedCamera == false) {
      return const Center(child: CircularProgressIndicator());
    }

    return Screenshot(
      controller: screenshotController,
      child: Center(
        child: ClipRRect(
          child: SizedOverflowBox(
            size: widget.cameraSize ?? const Size(300, 100),
            alignment: Alignment.center,
            child: RotatedBox(
              quarterTurns: 1,
              child: cameraController.buildPreview(),
            ),
          ),
        ),
      ),
    );
  }
}
