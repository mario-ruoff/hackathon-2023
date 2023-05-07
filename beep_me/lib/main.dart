import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

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
  final _debugMode = true;
  final _testMode = true;
  final _cameraFrequency = 1;
  final _endpointUrl = 'https://lololololololol.free.beeceptor.com';
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
      String base64Image = "";
      try {
        final imageFile = await _controller.takePicture();
        final imageBytes = await imageFile.readAsBytes();
        base64Image = base64Encode(imageBytes);
      } catch (e) {
        // If camera capture still in progress, do nothing
        print(e);
      }

      // Define the headers and body for the HTTP request
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({'image': base64Image});

      // Get message from endpoint or test response
      String responseBody = "";
      if (!_testMode) {
        // Send the HTTP request to the endpoint
        print("Posting to endpoint with body length " +
            base64Image.length.toString());
        final response = await http.post(Uri.parse(_endpointUrl),
            headers: headers, body: body);
        // Print the HTTP response status code and body for debugging
        // print('HTTP response: ${response.statusCode} ${response.body}');
        responseBody = response.body;
      } else {
        // Simulate a response for test purposes
        final frequencies = [
          0,
          0,
          0,
          0,
          0,
          0,
          1,
          1,
          1,
          2,
          2,
          2,
          2,
          10,
          10,
          10,
          10,
          10,
          10,
          10,
          10,
          10,
          10,
          10,
          10,
          10,
          10
        ];
        responseBody = (timer.tick >= frequencies.length)
            ? '{"beepFrequency": 10}'
            : '{"beepFrequency": ${frequencies[timer.tick]}}';
        print(responseBody);
      }

      // Parse the HTTP response body as an integer
      final responseBodyDecoded = jsonDecode(responseBody);
      double responseNumber = responseBodyDecoded['beepFrequency'].toDouble();

      if (responseNumber == 0) {
        _beepFrequency = responseNumber;
        startWhiteNoise();
      } else if (responseNumber != _beepFrequency) {
        _beepFrequency = responseNumber;
        _beepTimer.cancel();
        _audioPlayer.stop();
        startBeeping();
        print("Changing beeping to " + responseNumber.toString());
      }
    });
  }

  // Start beeping with a frequency defined by the endpoint
  void startBeeping() {
    print("BEEEP FREQUENCY: " + _beepFrequency.toString());
    // Stop if the beep frequency is 0
    if (_beepFrequency == 0) {
      return;
    }
    // Start sending camera images x times per second
    _beepTimer = Timer.periodic(
        Duration(milliseconds: (1000 ~/ _beepFrequency)), (timer) async {
      // Stop any currently playing beep sound and play a new one
      await _audioPlayer.setPlaybackRate(2);
      await _audioPlayer.play(AssetSource('beep-07a.wav'));
    });
  }

  // Start playing white noise when beep frequency is 0
  void startWhiteNoise() {
    print("Starting white noise");
    _audioPlayer.setVolume(0.5);
    _audioPlayer.play(AssetSource('01-White-Noise-10min.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        appBar: _debugMode ? AppBar(title: const Text('Beep Me')) : null,
        body: _debugMode
            ? FutureBuilder<void>(
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
              )
            : Stack(
                children: [
                  Container(),
                  // Position the message container in the top right corner
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Beep me is running!',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
