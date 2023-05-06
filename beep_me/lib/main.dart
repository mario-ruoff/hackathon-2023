import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get the list of available cameras
  final cameras = await availableCameras();

  // Initialize the first camera in the list
  final firstCamera = cameras.first;

  runApp(MainPage(
    // Pass the first camera to the app
    camera: firstCamera,
  ));
}

class MainPage extends StatefulWidget {
  final CameraDescription camera;

  const MainPage({
    Key? key,
    required this.camera,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  final _cameraFrequency = 0.5;
  final endpointUrl = 'https://einsteamyolo.free.beeceptor.com';
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      // Use the widget.camera to initialize the controller
      widget.camera,
      // Define the resolution to use
      ResolutionPreset.medium,
    );

    // Initialize the controller
    _initializeControllerFuture = _controller.initialize();
    startSendingCameraImages();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void startSendingCameraImages() {
    // Start sending camera images x times per second
    Timer.periodic(Duration(milliseconds: (1000 ~/ _cameraFrequency)),
        (timer) async {
      // Check if the controller has been initialized
      if (!_controller.value.isInitialized) {
        return;
      }

      // Take a picture and encode it to base64
      final imageFile = await _controller.takePicture();
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Define the headers and body for the HTTP request
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({'image': base64Image});

      // Send the HTTP request to the endpoint
      print("Posting to endpoint widh body length " +
          base64Image.length.toString());
      final response =
          await http.post(Uri.parse(endpointUrl), headers: headers, body: body);

      // Print the HTTP response status code and body for debugging
      print('HTTP response: ${response.statusCode} ${response.body}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Beep Me')),
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              // If the Future is complete, display the camera preview
              return CameraPreview(_controller);
            } else {
              // Otherwise, display a loading indicator
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}
