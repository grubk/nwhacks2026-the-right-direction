import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart' as mlkit;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart' as labeling;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'camera_service.dart';

/// ML Service abstraction for on-device inference
/// Handles object detection, hand landmark detection, and sign language recognition
abstract class MlService {
  /// Initialize ML models
  Future<void> initialize();
  
  /// Check if models are loaded
  bool get isInitialized;
  
  /// Run object detection on camera frame
  Future<List<DetectedObject>> detectObjects(CameraImage image);
  
  /// Run hand landmark detection for sign language
  Future<HandLandmarks?> detectHandLandmarks(CameraImage image);
  
  /// Recognize sign language gesture from landmarks
  Future<SignLanguageResult?> recognizeSign(HandLandmarks landmarks);
  
  /// Estimate distance of detected object (based on bounding box size)
  double estimateDistance(DetectedObject object, int imageWidth, int imageHeight);
  
  /// Dispose ML resources
  Future<void> dispose();
}

/// Hand landmark detection result
class HandLandmarks {
  final List<Landmark> landmarks;
  final double confidence;
  final HandType handType;

  const HandLandmarks({
    required this.landmarks,
    required this.confidence,
    required this.handType,
  });
}

class Landmark {
  final double x;
  final double y;
  final double z;
  final double visibility;

  const Landmark({
    required this.x,
    required this.y,
    required this.z,
    this.visibility = 1.0,
  });
}

enum HandType {
  left,
  right,
  unknown,
}

/// Sign language recognition result
class SignLanguageResult {
  final String gesture;
  final String meaning;
  final double confidence;
  final SignLanguageType type;

  const SignLanguageResult({
    required this.gesture,
    required this.meaning,
    required this.confidence,
    required this.type,
  });
}

enum SignLanguageType {
  asl, // American Sign Language
  bsl, // British Sign Language
  custom,
}

class MlServiceImpl implements MlService {
  static const _channel = MethodChannel('com.therightdirection/ml');
  
  mlkit.ObjectDetector? _mlKitObjectDetector;
  labeling.ImageLabeler? _imageLabeler;
  
  // TFLite interpreter for COCO object detection
  tfl.Interpreter? _tfliteInterpreter;
  List<String> _cocoLabels = [];
  bool _tfliteAvailable = false;
  
  bool _isInitialized = false;
  
  // Model labels - not needed with ML Kit as it provides labels
  List<String> _objectLabels = [];
  List<String> _signLabels = [];

  // Object size reference for distance estimation (in meters)
  // Extended to include common ML Kit Image Labeler labels
  static const Map<String, double> _objectReferenceHeights = {
    // People
    'person': 1.7,
    'man': 1.75,
    'woman': 1.65,
    'child': 1.2,
    'pedestrian': 1.7,
    
    // Vehicles
    'car': 1.5,
    'automobile': 1.5,
    'vehicle': 1.5,
    'truck': 2.5,
    'bus': 3.0,
    'motorcycle': 1.1,
    'bicycle': 1.0,
    'bike': 1.0,
    
    // Animals
    'dog': 0.5,
    'cat': 0.3,
    'bird': 0.2,
    'horse': 1.6,
    'sheep': 0.7,
    'cow': 1.4,
    'elephant': 3.0,
    'bear': 1.5,
    'zebra': 1.4,
    'giraffe': 5.5,
    'pet': 0.4,
    'animal': 0.6,
    
    // Furniture
    'chair': 0.8,
    'table': 0.75,
    'desk': 0.75,
    'couch': 0.9,
    'sofa': 0.9,
    'bed': 0.6,
    'bench': 0.45,
    'furniture': 0.8,
    'shelf': 1.5,
    'cabinet': 1.2,
    'drawer': 0.6,
    
    // Electronics
    'tv': 0.6,
    'television': 0.6,
    'monitor': 0.5,
    'laptop': 0.3,
    'computer': 0.5,
    'cell phone': 0.15,
    'phone': 0.15,
    'tablet': 0.25,
    'keyboard': 0.45,
    'mouse': 0.05,
    
    // Kitchen/dining
    'bottle': 0.25,
    'cup': 0.12,
    'mug': 0.12,
    'glass': 0.15,
    'wine glass': 0.2,
    'bowl': 0.1,
    'plate': 0.03,
    'refrigerator': 1.7,
    'fridge': 1.7,
    'microwave': 0.35,
    'oven': 0.9,
    'stove': 0.9,
    
    // Food
    'banana': 0.2,
    'apple': 0.08,
    'sandwich': 0.1,
    'orange': 0.08,
    'broccoli': 0.15,
    'carrot': 0.2,
    'pizza': 0.35,
    'cake': 0.15,
    'food': 0.15,
    'fruit': 0.1,
    
    // Indoor structures
    'door': 2.0,
    'window': 1.2,
    'wall': 2.5,
    'floor': 0.01,
    'ceiling': 2.5,
    'stairs': 2.0,
    'staircase': 2.0,
    'toilet': 0.4,
    'sink': 0.6,
    'bathtub': 0.6,
    
    // Outdoor structures
    'building': 10.0,
    'house': 6.0,
    'tree': 4.0,
    'pole': 5.0,
    'sign': 1.5,
    'stop sign': 0.75,
    'traffic light': 1.0,
    'fire hydrant': 0.5,
    'fence': 1.5,
    'sidewalk': 0.02,
    'road': 0.01,
    'street': 0.01,
    
    // Personal items
    'backpack': 0.5,
    'bag': 0.4,
    'umbrella': 1.0,
    'handbag': 0.3,
    'purse': 0.3,
    'suitcase': 0.7,
    'luggage': 0.7,
    
    // Sports/recreation
    'sports ball': 0.22,
    'ball': 0.22,
    'kite': 0.8,
    'tennis racket': 0.7,
    'skateboard': 0.1,
    'surfboard': 2.0,
    
    // Utensils
    'fork': 0.2,
    'knife': 0.25,
    'spoon': 0.18,
    'scissors': 0.2,
    
    // Plants
    'potted plant': 0.5,
    'plant': 0.5,
    'flower': 0.3,
    
    // Misc
    'book': 0.25,
    'clock': 0.3,
    'vase': 0.3,
    'tie': 0.5,
    'toothbrush': 0.2,
    'hair drier': 0.25,
    'box': 0.4,
    'pillow': 0.2,
    'blanket': 0.05,
    'curtain': 2.0,
    'lamp': 0.5,
    'light': 0.3,
  };

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('[ML DEBUG] Initializing ML Service with Google ML Kit...');

    try {
      // Load COCO labels for TFLite model
      try {
        final labelsData = await rootBundle.loadString('assets/models/coco_labels.txt');
        _cocoLabels = labelsData.split('\n').where((s) => s.trim().isNotEmpty).toList();
        print('[ML DEBUG] Loaded ${_cocoLabels.length} COCO labels');
      } catch (e) {
        print('[ML DEBUG] Could not load COCO labels: $e');
      }
      
      // Try to load TFLite model (SSD MobileNet COCO)
      try {
        print('[ML DEBUG] Attempting to load TFLite model from assets/models/ssd_mobilenet.tflite...');
        _tfliteInterpreter = await tfl.Interpreter.fromAsset('assets/models/ssd_mobilenet.tflite');
        _tfliteAvailable = true;
        print('[ML DEBUG] TFLite SSD MobileNet model loaded successfully');
      } catch (e, stackTrace) {
        print('[ML DEBUG] TFLite model load FAILED: $e');
        print('[ML DEBUG] TFLite stack trace: $stackTrace');
        _tfliteAvailable = false;
      }
      
      // Configure ML Kit Object Detector with base model (no download needed)
      final options = mlkit.ObjectDetectorOptions(
        mode: mlkit.DetectionMode.stream,
        classifyObjects: true,
        multipleObjects: true,
      );
      
      _mlKitObjectDetector = mlkit.ObjectDetector(options: options);
      print('[ML DEBUG] Google ML Kit Object Detector created successfully');

      // Initialize Image Labeler for better object labeling
      final labelerOptions = labeling.ImageLabelerOptions(
        confidenceThreshold: 0.5,
      );
      _imageLabeler = labeling.ImageLabeler(options: labelerOptions);
      print('[ML DEBUG] Google ML Kit Image Labeler created successfully');

      _isInitialized = true;
      print('[ML DEBUG] ML Service initialization complete');
    } catch (e, stackTrace) {
      print('[ML DEBUG] ML Kit initialization failed: $e');
      print('[ML DEBUG] Stack trace: $stackTrace');
      _isInitialized = false;
    }
  }

  Future<void> _initializePlatformSpecific() async {
    // Not needed with ML Kit - keeping for interface compatibility
    print('[ML DEBUG] Platform-specific initialization not needed with ML Kit');
  }

  Future<List<String>> _loadLabels(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      return content.split('\n').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<DetectedObject>> detectObjects(CameraImage image) async {
    if (!_isInitialized) {
      print('[ML DEBUG] detectObjects called but not initialized');
      return [];
    }

    try {
      final allResults = <DetectedObject>[];
      
      // Convert CameraImage to InputImage for ML Kit first
      final inputImage = _convertToInputImage(image);
      
      // PRIORITY 1: Run ML Kit Image Labeler (most accurate labels, 400+ types)
      List<labeling.ImageLabel> imageLabels = [];
      if (_imageLabeler != null && inputImage != null) {
        try {
          imageLabels = await _imageLabeler!.processImage(inputImage);
          if (imageLabels.isNotEmpty) {
            print('[ML DEBUG] Image labeler found ${imageLabels.length} labels: ${imageLabels.map((l) => '${l.label}(${(l.confidence * 100).toStringAsFixed(0)}%)').join(', ')}');
            
            // Create detections from high-confidence image labels
            // These don't have bounding boxes, so we create center-positioned alerts
            for (final label in imageLabels) {
              if (label.confidence < 0.50) continue; // 50% threshold for image labels
              
              final labelText = label.label.toLowerCase();
              // Skip generic/abstract labels
              if (_isGenericLabel(labelText)) continue;
              
              // Create a center-positioned detection for scene-level objects
              // Note: Image Labeler doesn't provide bounding boxes, so we use a placeholder
              // and estimate distance based on confidence level instead of box size
              final boundingBox = BoundingBox(
                left: 0.25,
                top: 0.25,
                right: 0.75,
                bottom: 0.75,
              );
              
              // For Image Labeler (no real bounding box), estimate distance from confidence:
              // - High confidence (>0.8) often means prominent/closer objects: ~2-3m
              // - Medium confidence (0.6-0.8) suggests medium distance: ~4-5m
              // - Lower confidence (<0.6) suggests farther/smaller objects: ~6-8m
              // This is a heuristic since we don't have actual spatial data
              final distance = _estimateDistanceFromConfidence(label.confidence, labelText);
              
              allResults.add(DetectedObject(
                label: labelText,
                confidence: label.confidence,
                distance: distance,
                direction: ObjectDirection.center,
                boundingBox: boundingBox,
              ));
              
              print('[ML DEBUG] Image Label: ${labelText} (${(label.confidence * 100).toStringAsFixed(1)}%) at ${distance.toStringAsFixed(1)}m (confidence-based)');
            }
          }
        } catch (e) {
          print('[ML DEBUG] Image labeling error: $e');
        }
      }
      
      // PRIORITY 2: Run TFLite for bounding box detection (if we need positions)
      if (_tfliteAvailable && _tfliteInterpreter != null && _cocoLabels.isNotEmpty) {
        print('[ML DEBUG] Attempting TFLite detection...');
        final tfliteResults = await _detectWithTflite(image);
        if (tfliteResults.isNotEmpty) {
          print('[ML DEBUG] TFLite detected ${tfliteResults.length} objects with bounding boxes');
          // Add TFLite results that don't overlap with image labeler results
          for (final tfliteObj in tfliteResults) {
            // Check if this label is already detected by image labeler
            final alreadyDetected = allResults.any((r) => 
              r.label.toLowerCase() == tfliteObj.label.toLowerCase());
            if (!alreadyDetected) {
              allResults.add(tfliteObj);
            }
          }
        }
      }
      
      // PRIORITY 3: Run ML Kit Object Detector for additional bounding boxes
      if (_mlKitObjectDetector != null && inputImage != null) {
        // Run ML Kit object detection
        final detectedObjects = await _mlKitObjectDetector!.processImage(inputImage);
        
        // Convert ML Kit results to our DetectedObject format
        final mlKitResults = <DetectedObject>[];
        
        if (detectedObjects.isNotEmpty) {
          print('[ML DEBUG] ML Kit Object Detector found ${detectedObjects.length} objects');
          
          for (final obj in detectedObjects) {
            // Get the best label from object detection
            String label = 'object';
            double confidence = 0.5;
            
            if (obj.labels.isNotEmpty) {
              final bestLabel = obj.labels.reduce((a, b) => 
                a.confidence > b.confidence ? a : b);
              label = bestLabel.text.toLowerCase();
              confidence = bestLabel.confidence;
            }
            
            // If object detection gave a generic label, try to use image labeling
            if ((label == 'object' || label == 'unknown' || label.isEmpty) && imageLabels.isNotEmpty) {
              // Filter out generic/useless labels
              final usefulLabels = imageLabels.where((l) {
                final text = l.label.toLowerCase();
                return !_isGenericLabel(text);
              }).toList();
              
              if (usefulLabels.isNotEmpty) {
                final bestImageLabel = usefulLabels.reduce((a, b) => 
                  a.confidence > b.confidence ? a : b);
                label = bestImageLabel.label.toLowerCase();
                confidence = bestImageLabel.confidence;
              }
            }

            // Skip low confidence detections
            if (confidence < 0.3) continue;
            
            // Skip if already detected by image labeler
            final alreadyDetected = allResults.any((r) => 
              r.label.toLowerCase() == label.toLowerCase());
            if (alreadyDetected) continue;

            // Convert bounding box (ML Kit uses pixel coordinates)
            final rect = obj.boundingBox;
            final boundingBox = BoundingBox(
              left: rect.left / image.width,
              top: rect.top / image.height,
              right: rect.right / image.width,
              bottom: rect.bottom / image.height,
            );

            // Estimate distance based on bounding box
            final distance = _estimateDistanceFromBox(
              label,
              boundingBox,
              image.width,
              image.height,
            );

            // Determine direction
            final direction = _determineDirection(boundingBox);

            mlKitResults.add(DetectedObject(
              label: label,
              confidence: confidence,
              distance: distance,
              direction: direction,
              boundingBox: boundingBox,
            ));
          }
        }
        
        // Add ML Kit Object Detector results
        if (mlKitResults.isNotEmpty) {
          print('[ML DEBUG] ML Kit Object Detector added ${mlKitResults.length} objects');
          allResults.addAll(mlKitResults);
        }
      }
      
      // If nothing detected, use fallback obstacle detection
      if (allResults.isEmpty) {
        final fallbackResults = _detectObstaclesFallback(image);
        allResults.addAll(fallbackResults);
      }
      
      print('[ML DEBUG] Total combined detections: ${allResults.length}');
      return allResults;
    } catch (e, stackTrace) {
      print('[ML DEBUG] Object detection error: $e');
      print('[ML DEBUG] Stack trace: $stackTrace');
      return [];
    }
  }

  /// Detect objects using TFLite SSD MobileNet model (COCO labels)
  Future<List<DetectedObject>> _detectWithTflite(CameraImage image) async {
    if (_tfliteInterpreter == null || _cocoLabels.isEmpty) {
      print('[TFLite DEBUG] Skipping - interpreter=${_tfliteInterpreter != null}, labels=${_cocoLabels.length}');
      return [];
    }
    
    try {
      // SSD MobileNet expects 300x300 RGB input
      const inputSize = 300;
      
      // Convert YUV to RGB and resize
      final rgbImage = _convertYuvToRgb(image);
      if (rgbImage == null) {
        print('[TFLite DEBUG] YUV to RGB conversion failed');
        return [];
      }
      print('[TFLite DEBUG] Converted to RGB: ${rgbImage.length} bytes');
      
      // Resize to model input size
      final resizedInput = _resizeImage(rgbImage, image.width, image.height, inputSize, inputSize);
      print('[TFLite DEBUG] Resized to ${inputSize}x${inputSize}');
      
      // Get model input/output info
      final inputTensor = _tfliteInterpreter!.getInputTensor(0);
      print('[TFLite DEBUG] Input tensor shape: ${inputTensor.shape}, type: ${inputTensor.type}');
      
      final numOutputs = _tfliteInterpreter!.getOutputTensors().length;
      print('[TFLite DEBUG] Number of output tensors: $numOutputs');
      for (int i = 0; i < numOutputs; i++) {
        final outTensor = _tfliteInterpreter!.getOutputTensor(i);
        print('[TFLite DEBUG] Output $i shape: ${outTensor.shape}, type: ${outTensor.type}');
      }
      
      // Check if model expects uint8 or float32 input
      final inputType = inputTensor.type;
      
      dynamic inputData;
      if (inputType == tfl.TensorType.uint8) {
        // Model expects uint8 input (0-255) - no normalization needed
        final input = Uint8List(1 * inputSize * inputSize * 3);
        for (int i = 0; i < resizedInput.length; i++) {
          input[i] = resizedInput[i].toInt().clamp(0, 255);
        }
        inputData = input.reshape([1, inputSize, inputSize, 3]);
        print('[TFLite DEBUG] Using uint8 input (0-255)');
      } else {
        // Model expects float32 input
        // SSD MobileNet COCO uses mean=127.5, std=127.5 normalization
        // Output range: -1 to 1
        final input = Float32List(1 * inputSize * inputSize * 3);
        for (int i = 0; i < resizedInput.length; i++) {
          input[i] = (resizedInput[i] - 127.5) / 127.5;
        }
        inputData = input.reshape([1, inputSize, inputSize, 3]);
        print('[TFLite DEBUG] Using float32 input (normalized -1 to 1)');
      }
      
      // Prepare output tensors based on actual model output shapes
      // Standard SSD MobileNet COCO outputs: boxes[1,10,4], classes[1,10], scores[1,10], count[1]
      final outputLocations = List.generate(1, (_) => List.generate(10, (_) => List.filled(4, 0.0)));
      final outputClasses = List.generate(1, (_) => List.filled(10, 0.0));
      final outputScores = List.generate(1, (_) => List.filled(10, 0.0));
      final numDetections = List.filled(1, 0.0);
      
      final outputs = <int, Object>{
        0: outputLocations,
        1: outputClasses,
        2: outputScores,
        3: numDetections,
      };
      
      // Run inference
      print('[TFLite DEBUG] Running inference...');
      _tfliteInterpreter!.runForMultipleInputs([inputData], outputs);
      print('[TFLite DEBUG] Inference complete');
      
      print('[TFLite DEBUG] numDetections raw: ${numDetections[0]}');
      final count = numDetections[0].toInt().clamp(0, 10);
      print('[TFLite DEBUG] Detection count: $count');
      
      if (count > 0) {
        print('[TFLite DEBUG] First detection - score: ${outputScores[0][0]}, class: ${outputClasses[0][0]}');
      }
      
      final results = <DetectedObject>[];
      
      for (int i = 0; i < count; i++) {
        final score = outputScores[0][i];
        final classId = outputClasses[0][i].toInt();
        
        // Get label for logging
        String labelForLog = 'unknown';
        if (classId >= 0 && classId < _cocoLabels.length) {
          labelForLog = _cocoLabels[classId];
        }
        print('[TFLite DEBUG] Detection $i: score=${(score * 100).toStringAsFixed(1)}%, classId=$classId ($labelForLog)');
        
        // Require 60% confidence for reliable detections
        if (score < 0.60) continue;
        
        if (classId < 0 || classId >= _cocoLabels.length) {
          print('[TFLite DEBUG] Invalid classId: $classId');
          continue;
        }
        
        final label = _cocoLabels[classId];
        
        // Skip background/unknown labels (marked as "???" in labelmap)
        if (label == '???' || label.isEmpty) {
          print('[TFLite DEBUG] Skipping background/unknown label at index $classId');
          continue;
        }
        
        // Get bounding box (normalized coordinates)
        final top = outputLocations[0][i][0].clamp(0.0, 1.0);
        final left = outputLocations[0][i][1].clamp(0.0, 1.0);
        final bottom = outputLocations[0][i][2].clamp(0.0, 1.0);
        final right = outputLocations[0][i][3].clamp(0.0, 1.0);
        
        final boundingBox = BoundingBox(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        );
        
        final distance = _estimateDistanceFromBox(label, boundingBox, image.width, image.height);
        final direction = _determineDirection(boundingBox);
        
        results.add(DetectedObject(
          label: label,
          confidence: score,
          distance: distance,
          direction: direction,
          boundingBox: boundingBox,
        ));
        
        print('[ML DEBUG] TFLite: $label (${(score * 100).toStringAsFixed(1)}%) at ${distance.toStringAsFixed(1)}m ${direction.name}');
      }
      
      return results;
    } catch (e, stackTrace) {
      print('[ML DEBUG] TFLite detection error: $e');
      print('[ML DEBUG] Stack trace: $stackTrace');
      return [];
    }
  }
  
  /// Convert YUV camera image to RGB bytes
  Uint8List? _convertYuvToRgb(CameraImage image) {
    try {
      if (image.planes.isEmpty) return null;
      
      final width = image.width;
      final height = image.height;
      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes.length > 1 ? image.planes[1].bytes : null;
      final vPlane = image.planes.length > 2 ? image.planes[2].bytes : null;
      
      final rgb = Uint8List(width * height * 3);
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * width + x;
          final yValue = yPlane[yIndex];
          
          int r, g, b;
          if (uPlane != null && vPlane != null) {
            // YUV420 to RGB conversion
            final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);
            final uValue = uPlane.length > uvIndex ? uPlane[uvIndex] : 128;
            final vValue = vPlane.length > uvIndex ? vPlane[uvIndex] : 128;
            
            r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
            g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round().clamp(0, 255);
            b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);
          } else {
            // Grayscale fallback
            r = g = b = yValue;
          }
          
          final rgbIndex = (y * width + x) * 3;
          rgb[rgbIndex] = r;
          rgb[rgbIndex + 1] = g;
          rgb[rgbIndex + 2] = b;
        }
      }
      
      return rgb;
    } catch (e) {
      print('[ML DEBUG] YUV to RGB conversion error: $e');
      return null;
    }
  }
  
  /// Resize RGB image to target dimensions
  Float32List _resizeImage(Uint8List rgb, int srcWidth, int srcHeight, int dstWidth, int dstHeight) {
    final result = Float32List(dstWidth * dstHeight * 3);
    
    final xRatio = srcWidth / dstWidth;
    final yRatio = srcHeight / dstHeight;
    
    for (int y = 0; y < dstHeight; y++) {
      for (int x = 0; x < dstWidth; x++) {
        final srcX = (x * xRatio).floor().clamp(0, srcWidth - 1);
        final srcY = (y * yRatio).floor().clamp(0, srcHeight - 1);
        
        final srcIndex = (srcY * srcWidth + srcX) * 3;
        final dstIndex = (y * dstWidth + x) * 3;
        
        if (srcIndex + 2 < rgb.length) {
          result[dstIndex] = rgb[srcIndex].toDouble();
          result[dstIndex + 1] = rgb[srcIndex + 1].toDouble();
          result[dstIndex + 2] = rgb[srcIndex + 2].toDouble();
        }
      }
    }
    
    return result;
  }

  /// Check if a label is generic/useless for navigation (like "pattern", "texture", etc.)
  bool _isGenericLabel(String label) {
    const genericLabels = {
      'pattern', 'texture', 'design', 'art', 'material', 'fabric',
      'sky', 'cloud', 'horizon', 'floor', 'ground', 'wall', 'ceiling',
      'indoor', 'outdoor', 'room', 'building', 'architecture',
      'color', 'shape', 'line', 'circle', 'rectangle', 'square',
      'light', 'shadow', 'reflection', 'background', 'foreground',
      'nature', 'landscape', 'scene', 'view', 'space', 'area',
      'surface', 'wood', 'metal', 'plastic', 'glass', 'concrete',
      'tile', 'carpet', 'grass', 'water', 'sand', 'snow', 'ice',
    };
    return genericLabels.contains(label);
  }

  /// Fallback obstacle detection using image analysis
  /// Analyzes the center region of the camera frame for potential obstacles
  /// based on luminance variance and edge density
  List<DetectedObject> _detectObstaclesFallback(CameraImage image) {
    try {
      if (image.planes.isEmpty) return [];
      
      // Get Y plane (luminance) from YUV image
      final yPlane = image.planes.first.bytes;
      final width = image.width;
      final height = image.height;
      
      // Analyze center region (where obstacles directly ahead would be)
      final centerStartX = (width * 0.25).toInt();
      final centerEndX = (width * 0.75).toInt();
      final centerStartY = (height * 0.3).toInt();
      final centerEndY = (height * 0.7).toInt();
      
      // Also analyze left, right, and center thirds
      final leftThirdEnd = (width * 0.33).toInt();
      final rightThirdStart = (width * 0.67).toInt();
      
      // Calculate average luminance and variance for different regions
      final centerStats = _calculateRegionStats(
        yPlane, width, height,
        centerStartX, centerStartY, centerEndX, centerEndY,
      );
      
      final leftStats = _calculateRegionStats(
        yPlane, width, height,
        0, centerStartY, leftThirdEnd, centerEndY,
      );
      
      final rightStats = _calculateRegionStats(
        yPlane, width, height,
        rightThirdStart, centerStartY, width, centerEndY,
      );
      
      final results = <DetectedObject>[];
      
      // Detect obstacles based on luminance patterns
      // Lower variance often indicates a flat surface (wall) nearby
      // Very dark center often indicates something blocking the view
      
      // Check center for obstacles
      final centerObstacle = _analyzeRegionForObstacle(
        centerStats, 
        ObjectDirection.center,
        'obstacle',
      );
      if (centerObstacle != null) {
        results.add(centerObstacle);
      }
      
      // Check left region
      final leftObstacle = _analyzeRegionForObstacle(
        leftStats,
        ObjectDirection.left,
        'obstacle',
      );
      if (leftObstacle != null) {
        results.add(leftObstacle);
      }
      
      // Check right region
      final rightObstacle = _analyzeRegionForObstacle(
        rightStats,
        ObjectDirection.right,
        'obstacle',
      );
      if (rightObstacle != null) {
        results.add(rightObstacle);
      }
      
      if (results.isNotEmpty) {
        print('[ML DEBUG] Fallback detection found ${results.length} obstacle(s)');
      }
      
      return results;
    } catch (e) {
      print('[ML DEBUG] Fallback detection error: $e');
      return [];
    }
  }
  
  /// Calculate luminance statistics for a region
  Map<String, double> _calculateRegionStats(
    List<int> yPlane,
    int imageWidth,
    int imageHeight,
    int startX,
    int startY,
    int endX,
    int endY,
  ) {
    double sum = 0;
    double sumSquared = 0;
    int count = 0;
    int edgeCount = 0;
    
    // Sample every 4th pixel for performance
    for (int y = startY; y < endY; y += 4) {
      for (int x = startX; x < endX; x += 4) {
        final index = y * imageWidth + x;
        if (index >= 0 && index < yPlane.length) {
          final value = yPlane[index].toDouble();
          sum += value;
          sumSquared += value * value;
          count++;
          
          // Simple edge detection - check horizontal gradient
          if (x + 4 < endX) {
            final nextIndex = y * imageWidth + x + 4;
            if (nextIndex < yPlane.length) {
              final diff = (yPlane[nextIndex] - yPlane[index]).abs();
              if (diff > 30) edgeCount++;
            }
          }
        }
      }
    }
    
    if (count == 0) {
      return {'mean': 128, 'variance': 1000, 'edgeDensity': 0};
    }
    
    final mean = sum / count;
    final variance = (sumSquared / count) - (mean * mean);
    final edgeDensity = edgeCount / count;
    
    return {
      'mean': mean,
      'variance': variance,
      'edgeDensity': edgeDensity,
    };
  }
  
  /// Analyze region statistics to determine if there's an obstacle
  DetectedObject? _analyzeRegionForObstacle(
    Map<String, double> stats,
    ObjectDirection direction,
    String label,
  ) {
    final mean = stats['mean']!;
    final variance = stats['variance']!;
    final edgeDensity = stats['edgeDensity']!;
    
    // Heuristics for obstacle detection:
    // 1. Very low variance (< 500) suggests a flat, uniform surface (wall) close by
    // 2. Very dark (mean < 50) suggests something blocking light
    // 3. Very high edge density with low variance suggests textured wall nearby
    
    double distance = 10.0; // Default far away
    double confidence = 0.0;
    
    // Low variance indicates uniform surface (likely wall or large object)
    if (variance < 300) {
      // Very close - very uniform surface
      distance = 0.3;
      confidence = 0.8;
    } else if (variance < 800) {
      // Close - somewhat uniform
      distance = 0.7;
      confidence = 0.7;
    } else if (variance < 1500) {
      // Medium distance
      distance = 1.5;
      confidence = 0.6;
    } else if (variance < 3000) {
      // Farther
      distance = 2.5;
      confidence = 0.5;
    } else {
      // High variance usually means open space or complex scene
      return null;
    }
    
    // Adjust based on brightness - darker often means closer
    if (mean < 40) {
      distance *= 0.5; // Very dark - likely very close
      confidence += 0.1;
    } else if (mean < 80) {
      distance *= 0.7;
      confidence += 0.05;
    }
    
    // Edge density adjustment
    if (edgeDensity > 0.3 && variance < 1500) {
      // High edges with moderate variance = textured wall nearby
      distance *= 0.8;
      confidence += 0.05;
    }
    
    // Clamp values
    distance = distance.clamp(0.2, 5.0);
    confidence = confidence.clamp(0.4, 0.9);
    
    // Only report if we have reasonable confidence
    if (confidence < 0.5) return null;
    
    // Create bounding box based on direction
    BoundingBox boundingBox;
    switch (direction) {
      case ObjectDirection.left:
        boundingBox = const BoundingBox(left: 0.0, top: 0.3, right: 0.33, bottom: 0.7);
        break;
      case ObjectDirection.right:
        boundingBox = const BoundingBox(left: 0.67, top: 0.3, right: 1.0, bottom: 0.7);
        break;
      case ObjectDirection.center:
      default:
        boundingBox = const BoundingBox(left: 0.25, top: 0.3, right: 0.75, bottom: 0.7);
        break;
    }
    
    return DetectedObject(
      label: label,
      confidence: confidence,
      distance: distance,
      direction: direction,
      boundingBox: boundingBox,
    );
  }

  /// Convert our CameraImage to ML Kit's InputImage
  mlkit.InputImage? _convertToInputImage(CameraImage image) {
    try {
      // Get the format
      mlkit.InputImageFormat format;
      switch (image.format) {
        case ImageFormat.nv21:
          format = mlkit.InputImageFormat.nv21;
          break;
        case ImageFormat.yuv420:
          format = mlkit.InputImageFormat.yuv420;
          break;
        case ImageFormat.bgra8888:
          format = mlkit.InputImageFormat.bgra8888;
          break;
        default:
          format = mlkit.InputImageFormat.nv21;
      }

      // Get rotation
      mlkit.InputImageRotation rotation;
      switch (image.rotation) {
        case 0:
          rotation = mlkit.InputImageRotation.rotation0deg;
          break;
        case 90:
          rotation = mlkit.InputImageRotation.rotation90deg;
          break;
        case 180:
          rotation = mlkit.InputImageRotation.rotation180deg;
          break;
        case 270:
          rotation = mlkit.InputImageRotation.rotation270deg;
          break;
        default:
          rotation = mlkit.InputImageRotation.rotation0deg;
      }

      // Get bytes from first plane
      if (image.planes.isEmpty) {
        print('[ML DEBUG] No planes in camera image');
        return null;
      }

      // For YUV420/NV21, we need to concatenate all planes
      final allBytes = <int>[];
      for (final plane in image.planes) {
        allBytes.addAll(plane.bytes);
      }
      final bytes = Uint8List.fromList(allBytes);

      final metadata = mlkit.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return mlkit.InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      print('[ML DEBUG] Error converting to InputImage: $e');
      return null;
    }
  }

  /// Check if two bounding boxes overlap significantly
  bool _boxesOverlap(BoundingBox a, BoundingBox b, {double threshold = 0.3}) {
    // Calculate intersection
    final xOverlap = (a.right.clamp(0, 1) - a.left.clamp(0, 1)).clamp(0, 1) > 0 &&
                     (b.right.clamp(0, 1) - b.left.clamp(0, 1)).clamp(0, 1) > 0;
    final yOverlap = (a.bottom.clamp(0, 1) - a.top.clamp(0, 1)).clamp(0, 1) > 0 &&
                     (b.bottom.clamp(0, 1) - b.top.clamp(0, 1)).clamp(0, 1) > 0;
    
    if (!xOverlap || !yOverlap) return false;
    
    final intersectLeft = a.left > b.left ? a.left : b.left;
    final intersectTop = a.top > b.top ? a.top : b.top;
    final intersectRight = a.right < b.right ? a.right : b.right;
    final intersectBottom = a.bottom < b.bottom ? a.bottom : b.bottom;
    
    if (intersectRight <= intersectLeft || intersectBottom <= intersectTop) {
      return false;
    }
    
    final intersectArea = (intersectRight - intersectLeft) * (intersectBottom - intersectTop);
    final areaA = (a.right - a.left) * (a.bottom - a.top);
    final areaB = (b.right - b.left) * (b.bottom - b.top);
    final minArea = areaA < areaB ? areaA : areaB;
    
    // Return true if intersection is more than threshold of the smaller box
    return minArea > 0 && (intersectArea / minArea) > threshold;
  }

  ObjectDirection _determineDirection(BoundingBox box) {
    final centerX = box.centerX;
    
    if (centerX < 0.33) {
      return ObjectDirection.left;
    } else if (centerX > 0.66) {
      return ObjectDirection.right;
    } else {
      return ObjectDirection.center;
    }
  }

  /// Estimate distance from confidence level for Image Labeler results
  /// (which don't have real bounding boxes)
  double _estimateDistanceFromConfidence(double confidence, String label) {
    // Image Labeler confidence roughly correlates with object prominence:
    // - Very high confidence often means object dominates the frame (closer)
    // - Lower confidence might mean object is smaller/farther or partially visible
    
    // Base distance estimate from confidence
    double baseDistance;
    if (confidence > 0.85) {
      baseDistance = 2.5; // Very prominent, likely close
    } else if (confidence > 0.75) {
      baseDistance = 3.5; // Prominent
    } else if (confidence > 0.65) {
      baseDistance = 5.0; // Moderate
    } else if (confidence > 0.55) {
      baseDistance = 6.5; // Less prominent
    } else {
      baseDistance = 8.0; // Low confidence, likely far or small
    }
    
    // Adjust based on typical object size - larger objects seen at same confidence are farther
    final referenceHeight = _objectReferenceHeights[label.toLowerCase()];
    if (referenceHeight != null) {
      // Large objects (>1.5m) at high confidence are probably farther than small objects
      if (referenceHeight > 1.5) {
        baseDistance *= 1.3; // Increase distance estimate for large objects
      } else if (referenceHeight < 0.3) {
        baseDistance *= 0.7; // Decrease for small objects (they must be close to be detected)
      }
    }
    
    return baseDistance.clamp(1.0, 10.0);
  }

  double _estimateDistanceFromBox(
    String label, 
    BoundingBox box, 
    int imageWidth, 
    int imageHeight,
  ) {
    // Use reference object height for distance estimation
    final referenceHeight = _objectReferenceHeights[label.toLowerCase()] ?? 1.0;
    
    // Calculate apparent height in image (normalized)
    final apparentHeight = box.height;
    
    // Simple pinhole camera model for distance estimation
    // d = (H * f) / h
    // Where H = real height, f = focal length (normalized), h = apparent height
    // Adjusted focal length based on typical smartphone camera FOV (~70 degrees)
    // This gives more realistic distance estimates
    const focalLength = 1.4; // Adjusted for typical smartphone camera
    
    if (apparentHeight <= 0) return 10.0; // Far away default
    
    // Apply focal length adjustment
    final distance = (referenceHeight * focalLength) / apparentHeight;
    
    return distance.clamp(0.1, 10.0); // Clamp to reasonable range
  }

  @override
  double estimateDistance(DetectedObject object, int imageWidth, int imageHeight) {
    return _estimateDistanceFromBox(
      object.label, 
      object.boundingBox, 
      imageWidth, 
      imageHeight,
    );
  }

  @override
  Future<HandLandmarks?> detectHandLandmarks(CameraImage image) async {
    // Hand landmark detection not yet implemented with ML Kit
    // Would require google_mlkit_pose_detection or custom model
    return null;
  }

  @override
  Future<SignLanguageResult?> recognizeSign(HandLandmarks landmarks) async {
    // Sign language recognition not yet implemented
    // Would require custom model for ASL/BSL recognition
    return null;
  }

  @override
  Future<void> dispose() async {
    _mlKitObjectDetector?.close();
    _imageLabeler?.close();
    _tfliteInterpreter?.close();
    _isInitialized = false;
    print('[ML DEBUG] ML Service disposed');
  }
}
