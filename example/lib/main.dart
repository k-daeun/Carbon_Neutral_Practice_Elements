import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'dart:async';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image_picker/image_picker.dart';

// 객체 감지, 이미지 객체 감지, 텍스트 추출 옵션을 나타내는 열거형
enum Options { none, image, frame, tesseract, vision }

// 카메라 리스트
late List<CameraDescription> cameras;

// 앱 시작점
main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  runApp(
    const MaterialApp(
      home: MyApp(),
    ),
  );
}

// 메인 앱 클래스
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

// 앱 상태 관리 클래스
class _MyAppState extends State<MyApp> {
  Options option = Options.none; //현재 선택된 옵션
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: task(option),
      floatingActionButton: SpeedDial(
        //margin bottom
        icon: Icons.menu, //icon on Floating action button
        activeIcon: Icons.close, //icon when menu is expanded on button
        backgroundColor: Colors.black12, //background color of button
        foregroundColor: Colors.white, //font color, icon color in button
        activeBackgroundColor:
        Colors.deepPurpleAccent, //background color when menu is expanded
        activeForegroundColor: Colors.white,
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        buttonSize: const Size(56.0, 56.0),
        children: [
          SpeedDialChild(
            //speed dial child
            child: const Icon(Icons.video_call),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            label: 'Yolo on Frame',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () {
              setState(() {
                option = Options.frame;
              });
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.camera),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            label: 'Yolo on Image',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () {
              setState(() {
                option = Options.image;
              });
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.text_snippet_outlined),
            foregroundColor: Colors.white,
            backgroundColor: Colors.green,
            label: 'Tesseract',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () {
              setState(() {
                option = Options.tesseract;
              });
            },
          ),
          // SpeedDialChild(
          //   child: const Icon(Icons.document_scanner),
          //   foregroundColor: Colors.white,
          //   backgroundColor: Colors.green,
          //   label: 'Vision',
          //   labelStyle: const TextStyle(fontSize: 18.0),
          //   onTap: () {
          //     setState(() {
          //       option = Options.vision;
          //     });
          //   },
          // ),
        ],
      ),
    );
  }

  //선택된 옵션에 따라 화면 변경 메소드
  Widget task(Options option) {
    if (option == Options.frame) {
      return YoloVideo();
    }
    if (option == Options.image) {
      return YoloImage();
    }
    if (option == Options.tesseract) {
      return const TesseractImage();
    }
    return const Center(child: Text("Choose Task")); // 기본 화면
  }
}

// 객체 감지 기능 구현 클래스
class YoloVideo extends StatefulWidget {
  YoloVideo({Key? key}) : super(key: key);

  @override
  State<YoloVideo> createState() => _YoloVideoState();
}

class _YoloVideoState extends State<YoloVideo> {
  late CameraController controller;
  late FlutterVision vision;
  late List<Map<String, dynamic>> yoloResults;
  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();
    init(); // 객체 감지 기능 초기화
  }

  // 객체 감지 기능 초기화 메소드
  init() async {
    cameras = await availableCameras(); // 사용 가능한 카메라 정보 가져오기
    vision = FlutterVision(); // FlutterVision 인스턴스 생성
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((value) {
      loadYoloModel().then((value) {
        setState(() {
          isLoaded = true;
          isDetecting = false;
          yoloResults = []; // 감지 결과 초기화
        });
      });
    });
  }

  @override
  void dispose() async {
    super.dispose();
    controller.dispose(); // 카메라 컨트롤러 해제
    await vision.closeYoloModel(); // YOLO 모델 해제
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: Text("Model not loaded, waiting for it"),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(
            controller,
          ),
        ),
        ...displayBoxesAroundRecognizedObjects(size), // 인식된 객체 주위에 박스 표시
        Positioned(
          bottom: 75,
          width: MediaQuery.of(context).size.width,
          child: Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  width: 5, color: Colors.white, style: BorderStyle.solid),
            ),
            child: isDetecting
                ? IconButton(
              onPressed: () async {
                stopDetection();
              },
              icon: const Icon(
                Icons.stop,
                color: Colors.red,
              ),
              iconSize: 50,
            )
                : IconButton(
              onPressed: () async {
                await startDetection();
              },
              icon: const Icon(
                Icons.play_arrow,
                color: Colors.white,
              ),
              iconSize: 50,
            ),
          ),
        ),
      ],
    );
  }

  // YOLO 모델 로딩 메소드
  Future<void> loadYoloModel() async {
    await vision.loadYoloModel(
        labels: 'assets/labels.txt',
        modelPath: 'assets/best5_float32.tflite',
        modelVersion: "yolov8",
        numThreads: 2,
        useGpu: true);
    setState(() {
      isLoaded = true; // YOLO 모델 로딩 완료
    });
  }

  // 프레임에서 객체 감지하는 메소드
  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    final result = await vision.yoloOnFrame(
        bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
        imageHeight: cameraImage.height,
        imageWidth: cameraImage.width,
        iouThreshold: 0.4,
        confThreshold: 0.4,
        classThreshold: 0.5);
    if (result.isNotEmpty) {
      setState(() {
        yoloResults = result; // 객체 감지 결과 저장
      });
    }
  }

  // 객체 감지 시작 메소드
  Future<void> startDetection() async {
    setState(() {
      isDetecting = true; // 객체 감지 중 상태로 설정
    });
    if (controller.value.isStreamingImages) {
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
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
  }

  // 인식된 객체 주위에 박스를 표시하는 메소드
  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];
    double factorX = screen.width / (cameraImage?.height ?? 1);
    double factorY = screen.height / (cameraImage?.width ?? 1);

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);

    List<Map<String, dynamic>> filteredResults = yoloResults
        .where((result) => result['box'][4] >= 0.6) // 인식률이 60% 이상인지 확인
        .toList();

    return filteredResults.map((result) {
      return Positioned(
        left: result["box"][0] * factorX,
        top: result["box"][1] * factorY,
        width: (result["box"][2] - result["box"][0]) * factorX,
        height: (result["box"][3] - result["box"][1]) * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(color: Colors.pink, width: 2.0),
          ),
          child: Text(
            "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: Colors.white,
              fontSize: 18.0,
            ),
          ),
        ),
      );
    }).toList();
  }
}

class YoloImage extends StatefulWidget {
  YoloImage({Key? key}) : super(key: key);

  @override
  State<YoloImage> createState() => _YoloImageState();
}

class _YoloImageState extends State<YoloImage> {
  late FlutterVision vision;
  late List<Map<String, dynamic>> yoloResults;
  File? imageFile;
  int imageHeight = 1;
  int imageWidth = 1;
  bool isLoaded = false;

  @override
  void initState() {
    super.initState();
    vision = FlutterVision();
    loadYoloModel().then((value) {
      setState(() {
        yoloResults = [];
        isLoaded = true;
      });
    });
  }

  @override
  void dispose() async {
    super.dispose();
    await vision.closeYoloModel();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: Text("Model not loaded, waiting for it"),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        imageFile != null ? Image.file(imageFile!) : const SizedBox(),
        Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: pickImage,
                child: const Text("Pick image"),
              ),
              ElevatedButton(
                onPressed: yoloOnImage,
                child: const Text("Detect"),
              )
            ],
          ),
        ),
        ...displayBoxesAroundRecognizedObjects(size),
      ],
    );
  }

  // YOLO 모델 로딩 메소드
  Future<void> loadYoloModel() async {
    await vision.loadYoloModel(
        labels: 'assets/labels.txt',
        modelPath: 'assets/best5_float32.tflite',
        modelVersion: "yolov8",
        numThreads: 2,
        useGpu: true);
    setState(() {
      isLoaded = true;
    });
  }

  // 이미지 선택 메소드
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Capture a photo
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        imageFile = File(photo.path);
      });
    }
  }

  // 이미지에서 객체 감지 메소드
  yoloOnImage() async {
    yoloResults.clear();
    Uint8List byte = await imageFile!.readAsBytes();
    final image = await decodeImageFromList(byte);

    imageHeight = image.height;
    imageWidth = image.width;
    final result = await vision.yoloOnImage(
        bytesList: byte,
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.8,
        confThreshold: 0.4,
        classThreshold: 0.5);
    if (result.isNotEmpty) {
      setState(() {
        yoloResults = result; // 객체 감지 결과 저장
      });
    }
  }

  // 인식된 객체 주위에 박스 표시 메소드
  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];

    double factorX = screen.width / (imageWidth);
    double imgRatio = imageWidth / imageHeight;
    double newWidth = imageWidth * factorX;
    double newHeight = newWidth / imgRatio;
    double factorY = newHeight / (imageHeight);

    double pady = (screen.height - newHeight) / 2;

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);

    List<Map<String, dynamic>> filteredResults = yoloResults
        .where((result) => result['box'][4] >= 0.6) // 인식률이 60% 이상인지 확인
        .toList();

    return filteredResults.map((result) {
      return Positioned(
        left: result["box"][0] * factorX,
        top: result["box"][1] * factorY + pady,
        width: (result["box"][2] - result["box"][0]) * factorX,
        height: (result["box"][3] - result["box"][1]) * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(color: Colors.pink, width: 2.0),
          ),
          child: Text(
            "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: Colors.white,
              fontSize: 18.0,
            ),
          ),
        ),
      );
    }).toList();
  }
}

// 텍스트 추출 기능 구현 클래스
class TesseractImage extends StatefulWidget {
  const TesseractImage({Key? key}) : super(key: key);

  @override
  State<TesseractImage> createState() => _TesseractImageState();
}

class _TesseractImageState extends State<TesseractImage> {
  late FlutterVision vision;
  late List<Map<String, dynamic>> tesseractResults = [];
  File? imageFile;
  bool isLoaded = false;

  @override
  void initState() {
    super.initState();
    vision = FlutterVision();
    loadTesseractModel().then((value) {
      setState(() {
        isLoaded = true;
        tesseractResults = [];
      });
    });
  }

  @override
  void dispose() async {
    super.dispose();
    await vision.closeTesseractModel();
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
    return SingleChildScrollView(
      child: Column(
        children: [
          imageFile != null ? Image.file(imageFile!) : const SizedBox(),
          tesseractResults.isEmpty
              ? const SizedBox()
              : Align(child: Text(tesseractResults[0]["text"])),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: pickImage,
                child: const Text("Pick image"),
              ),
              ElevatedButton(
                onPressed: tesseractOnImage,
                child: const Text("Get Text"),
              )
            ],
          ),
        ],
      ),
    );
  }

  Future<void> loadTesseractModel() async {
    await vision.loadTesseractModel(
      args: {
        'psm': '11',
        'oem': '1',
        'preserve_interword_spaces': '1',
      },
      language: 'spa',
    );
    setState(() {
      isLoaded = true;
    });
  }

  // 이미지 선택 메소드
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Capture a photo
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        imageFile = File(photo.path);
      });
    }
  }

  tesseractOnImage() async {
    tesseractResults.clear();
    Uint8List byte = await imageFile!.readAsBytes();
    final result = await vision.tesseractOnImage(bytesList: byte);
    if (result.isNotEmpty) {
      setState(() {
        tesseractResults = result;
      });
    }
  }
}
