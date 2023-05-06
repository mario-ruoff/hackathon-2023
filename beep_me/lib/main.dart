import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
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
  final _cameraFrequency = 0.2;
  final endpointUrl = 'https://lololololololol.free.beeceptor.com';
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer _beepTimer = Timer(Duration.zero, () {});
  double _beepFrequency = 0;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
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

  // Send camera images to the endpoint
  void startSendingCameraImages() {
    // Start sending camera images x times per second
    Timer.periodic(Duration(milliseconds: (1000 ~/ _cameraFrequency)),
        (timer) async {
      // Check if the controller has been initialized
      if (!_controller.value.isInitialized) {
        return;
      }

      // Take a picture and encode it to base64
      try {
        final imageFile = await _controller.takePicture();
        final imageBytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(imageBytes);

        // Define the headers and body for the HTTP request
        final headers = {'Content-Type': 'application/json'};
        final body = jsonEncode({'image': base64Image});

        // Send the HTTP request to the endpoint
        print("Posting to endpoint with body length " +
            base64Image.length.toString());
        final response = await http.post(Uri.parse(endpointUrl),
            headers: headers, body: body);

        // Print the HTTP response status code and body for debugging
        // print('HTTP response: ${response.statusCode} ${response.body}');

        // Parse the HTTP response body as an integer
        final responseBody = jsonDecode(response.body);
        double responseNumber = responseBody['beepFrequency'].toDouble();

        if (responseNumber != _beepFrequency) {
          _beepFrequency = responseNumber;
          _beepTimer.cancel();
          if (responseNumber != 0) {
            startBeeping();
            print("Changing beeping to " + responseNumber.toString());
          } else {
            print("Stopping beeping");
          }
        }
      } catch (e) {
        // If camera capture still in progress, do nothing
        print(e);
      }
    });
  }

  // Start beeping with a frequency defined by the endpoint
  void startBeeping() {
    // Start sending camera images x times per second
    _beepTimer = Timer.periodic(
        Duration(milliseconds: (1000 ~/ _beepFrequency)), (timer) async {
      // Stop any currently playing beep sound and play a new one
      await _audioPlayer.setPlaybackRate(2);
      await _audioPlayer.play(AssetSource('beep-07a.wav'));
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
