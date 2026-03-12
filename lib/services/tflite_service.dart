import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> initialize() async {
    // Load model
    _interpreter = await Interpreter.fromAsset('assets/mobilenet_v2.tflite');
    
    // Load labels
    final labelData = await rootBundle.loadString('assets/labels.txt');
    _labels = labelData.split('\n');
  }

  Future<String> classifyItem(File imageFile) async {
    if (_interpreter == null || _labels == null) {
      await initialize();
    }

    // Read image
    final imageBytes = await imageFile.readAsBytes();
    img.Image? decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      return "Unknown Item";
    }

    // Resize image to 224x224
    img.Image resizedImage = img.copyResize(decodedImage, width: 224, height: 224);

    final inputTensor = _interpreter!.getInputTensor(0);
    final isFloat = inputTensor.type == TensorType.float32;

    // Convert to array required by MobileNetV2
    // Shape: [1, 224, 224, 3]
    var input = isFloat 
        ? List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) => List.filled(3, 0.0))))
        : List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) => List.filled(3, 0))));
    
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

    // Prepare output array
    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final outLength = outputShape.isNotEmpty && outputShape.length > 1 ? outputShape[1] : 1001;
    
    var output = outputTensor.type == TensorType.float32
        ? List.generate(1, (i) => List.filled(outLength, 0.0))
        : List.generate(1, (i) => List.filled(outLength, 0));

    // Run inference
    _interpreter!.run(input, output);

    // Extract highest confidence
    int highestIndex = 0;
    double highestConfidence = 0.0;
    
    final results = output[0];
    for (int i = 0; i < results.length; i++) {
      double conf = outputTensor.type == TensorType.float32 
          ? (results[i] as double)
          : ((results[i] as int) / 255.0); // Uint8 models return 0-255

      if (conf > highestConfidence) {
        highestConfidence = conf;
        highestIndex = i;
      }
    }

    // Logic Gate: Implement the > 0.40 (40%) confidence threshold. 
    // Return the label if passed, else return "Unknown Item".
    // Note: Re-adjusted to 0.40 because mobilenet predictions are distributed.
    if (highestConfidence > 0.20) {
      if (highestIndex < _labels!.length) {
        return _labels![highestIndex].trim();
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

    img.Image resizedImage = img.copyResize(decodedImage, width: 224, height: 224);
    final inputTensor = _interpreter!.getInputTensor(0);
    final isFloat = inputTensor.type == TensorType.float32;

    var input = isFloat
        ? List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) => List.filled(3, 0.0))))
        : List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) => List.filled(3, 0))));

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
    final outLength = outputShape.isNotEmpty && outputShape.length > 1 ? outputShape[1] : 1001;

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
    for(int i=0; i<count && i<confidences.length; i++) {
        if(confidences[i].value >= 0.02 && confidences[i].key < _labels!.length) { // grab all slightly viable visual queues
            topLabels.add(_labels![confidences[i].key].trim().toLowerCase());
        }
    }
    return topLabels;
  }

  void dispose() {
    _interpreter?.close();
  }
}
