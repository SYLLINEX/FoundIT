import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset('assets/mobilenet_v2.tflite');

    // Load labels
    final labelData = await rootBundle.loadString('assets/labels.txt');
    _labels = labelData.split('\n');
  }

  Future<String> classifyItem(File imageFile) async {
    if (_interpreter == null || _labels == null) {
      await initialize();
    }

    final imageBytes = await imageFile.readAsBytes();
    img.Image? decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) return "Unknown Item";

    // Center-crop to square before resizing to maintain aspect ratio
    int size = decodedImage.width < decodedImage.height
        ? decodedImage.width
        : decodedImage.height;
    int x = (decodedImage.width - size) ~/ 2;
    int y = (decodedImage.height - size) ~/ 2;
    img.Image croppedImage = img.copyCrop(
      decodedImage,
      x: x,
      y: y,
      width: size,
      height: size,
    );
    img.Image resizedImage = img.copyResize(
      croppedImage,
      width: 224,
      height: 224,
    );

    final inputTensor = _interpreter!.getInputTensor(0);
    final isFloat = inputTensor.type == TensorType.float32;

    var input = isFloat
        ? List.generate(
            1,
            (i) => List.generate(
              224,
              (y) => List.generate(224, (x) => List.filled(3, 0.0)),
            ),
          )
        : List.generate(
            1,
            (i) => List.generate(
              224,
              (y) => List.generate(224, (x) => List.filled(3, 0)),
            ),
          );

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        if (isFloat) {
          input[0][y][x][0] = (pixel.r / 127.5) - 1.0;
          input[0][y][x][1] = (pixel.g / 127.5) - 1.0;
          input[0][y][x][2] = (pixel.b / 127.5) - 1.0;
        } else {
          input[0][y][x][0] = pixel.r.toInt();
          input[0][y][x][1] = pixel.g.toInt();
          input[0][y][x][2] = pixel.b.toInt();
        }
      }
    }

    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final outLength = outputShape.isNotEmpty && outputShape.length > 1
        ? outputShape[1]
        : 1001;

    var output = outputTensor.type == TensorType.float32
        ? List.generate(1, (i) => List.filled(outLength, 0.0))
        : List.generate(1, (i) => List.filled(outLength, 0));

    _interpreter!.run(input, output);

    int highestIndex = 0;
    double highestConfidence = 0.0;

    final results = output[0];
    for (int i = 0; i < results.length; i++) {
      double conf = outputTensor.type == TensorType.float32
          ? (results[i] as double)
          : ((results[i] as int) / 255.0);

      if (conf > highestConfidence) {
        highestConfidence = conf;
        highestIndex = i;
      }
    }

    if (highestConfidence > 0.80) {
      if (highestIndex < _labels!.length) {
        String rawLabel = _labels![highestIndex].trim().toLowerCase();
        // Strict Student Categories Only!
        String? mappedLabel = _mapToStudentItem(rawLabel);
        if (mappedLabel != null) return mappedLabel;
      }
    }

    return "Unknown Item";
  }

  Future<List<String>> getTopLabels(File imageFile, {int count = 5}) async {
    if (_interpreter == null || _labels == null) {
      await initialize();
    }

    final imageBytes = await imageFile.readAsBytes();
    img.Image? decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) return [];

    int size = decodedImage.width < decodedImage.height
        ? decodedImage.width
        : decodedImage.height;
    int x = (decodedImage.width - size) ~/ 2;
    int y = (decodedImage.height - size) ~/ 2;
    img.Image croppedImage = img.copyCrop(
      decodedImage,
      x: x,
      y: y,
      width: size,
      height: size,
    );
    img.Image resizedImage = img.copyResize(
      croppedImage,
      width: 224,
      height: 224,
    );

    final inputTensor = _interpreter!.getInputTensor(0);
    final isFloat = inputTensor.type == TensorType.float32;

    var input = isFloat
        ? List.generate(
            1,
            (i) => List.generate(
              224,
              (y) => List.generate(224, (x) => List.filled(3, 0.0)),
            ),
          )
        : List.generate(
            1,
            (i) => List.generate(
              224,
              (y) => List.generate(224, (x) => List.filled(3, 0)),
            ),
          );

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        if (isFloat) {
          input[0][y][x][0] = (pixel.r / 127.5) - 1.0;
          input[0][y][x][1] = (pixel.g / 127.5) - 1.0;
          input[0][y][x][2] = (pixel.b / 127.5) - 1.0;
        } else {
          input[0][y][x][0] = pixel.r.toInt();
          input[0][y][x][1] = pixel.g.toInt();
          input[0][y][x][2] = pixel.b.toInt();
        }
      }
    }

    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final outLength = outputShape.isNotEmpty && outputShape.length > 1
        ? outputShape[1]
        : 1001;

    var output = outputTensor.type == TensorType.float32
        ? List.generate(1, (i) => List.filled(outLength, 0.0))
        : List.generate(1, (i) => List.filled(outLength, 0));

    _interpreter!.run(input, output);

    final results = output[0];

    List<MapEntry<int, double>> confidences = [];
    for (int i = 0; i < results.length; i++) {
      double conf = outputTensor.type == TensorType.float32
          ? (results[i] as double)
          : ((results[i] as int) / 255.0);
      confidences.add(MapEntry(i, conf));
    }

    confidences.sort((a, b) => b.value.compareTo(a.value));

    List<String> topLabels = [];
    print('--- TFLite Suggested Matches Testing ---');
    for (int i = 0; i < count && i < confidences.length; i++) {
      if (confidences[i].key < _labels!.length) {
        print(
          '- ${_labels![confidences[i].key].trim()}: ${(confidences[i].value * 100).toStringAsFixed(2)}%',
        );
      }
    }
    print('----------------------------------------');

    for (int i = 0; i < count && i < confidences.length; i++) {
      if (confidences[i].value >= 0.80 &&
          confidences[i].key < _labels!.length) {
        String rawLabel = _labels![confidences[i].key].trim().toLowerCase();
        String? mappedLabel = _mapToStudentItem(rawLabel);
        if (mappedLabel != null && !topLabels.contains(mappedLabel)) {
          topLabels.add(mappedLabel);
        }
      }
    }
    return topLabels;
  }

  // --- STUDENT ITEM MAPPING LOGIC ---
  String? _mapToStudentItem(String rawLabel) {
    // 1. Direct Keyword Matches
    final Map<String, String> studentItems = {
      'cellular telephone': 'Mobile Phone',
      'computer keyboard': 'Keyboard',
      'mouse': 'Computer Mouse',
      'laptop': 'Laptop',
      'notebook': 'Laptop',
      'backpack': 'Backpack',
      'wallet': 'Wallet',
      'purse': 'Bag / Purse',
      'water bottle': 'Water Bottle',
      'water jug': 'Water Bottle',
      'sunglasses': 'Accessories',
      'fountain pen': 'Stationery',
      'ballpoint': 'Stationery',
      'binder': 'File / Folder',
    };

    if (studentItems.containsKey(rawLabel)) {
      return studentItems[rawLabel];
    }

    // 2. Loose Keyword Grouping
    if (rawLabel.contains('phone') || rawLabel.contains('ipod'))
      return 'Mobile Phone';
    if (rawLabel.contains('computer') || rawLabel.contains('laptop'))
      return 'Laptop / PC';
    if (rawLabel.contains('bag') || rawLabel.contains('pack'))
      return 'Backpack / Bag';
    if (rawLabel.contains('shoe') || rawLabel.contains('sneaker'))
      return 'Shoes / Wearables';
    if (rawLabel.contains('remote')) return 'Electronic Device';
    if (rawLabel.contains('bottle') || rawLabel.contains('cup'))
      return 'Bottle / Cup';

    // Strict Enforcement: Reject any generic ImageNet label not mapped above
    return null;
  }

  void dispose() {
    _interpreter?.close();
  }
}
