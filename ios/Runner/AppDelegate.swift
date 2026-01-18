import UIKit
import Flutter
import AVFoundation
import ARKit
import CoreHaptics

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    private var hapticsChannel: FlutterMethodChannel?
    private var lidarChannel: FlutterMethodChannel?
    
    private var hapticsEngine: CHHapticEngine?
    private var arSession: ARSession?
    private var depthStreamHandler: DepthStreamHandler?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller = window?.rootViewController as! FlutterViewController
        
        // Setup Core Haptics channel
        hapticsChannel = FlutterMethodChannel(
            name: "com.therightdirection/haptics",
            binaryMessenger: controller.binaryMessenger
        )
        hapticsChannel?.setMethodCallHandler(handleHapticsMethodCall)
        
        // Setup LiDAR channel
        lidarChannel = FlutterMethodChannel(
            name: "com.therightdirection/lidar",
            binaryMessenger: controller.binaryMessenger
        )
        lidarChannel?.setMethodCallHandler(handleLidarMethodCall)
        
        // Setup depth stream event channel
        let depthEventChannel = FlutterEventChannel(
            name: "com.therightdirection/lidar/depth_stream",
            binaryMessenger: controller.binaryMessenger
        )
        depthStreamHandler = DepthStreamHandler()
        depthEventChannel.setStreamHandler(depthStreamHandler)
        
        GeneratedPluginRegistrant.register(with: self)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Core Haptics Methods
    
    private func handleHapticsMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initializeCoreHaptics":
            initializeCoreHaptics(result: result)
        case "disposeCoreHaptics":
            disposeCoreHaptics(result: result)
        case "playPattern":
            if let args = call.arguments as? [String: Any],
               let patternData = args["pattern"] as? [[String: Any]] {
                playHapticPattern(patternData, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid pattern data", details: nil))
            }
        case "playContinuousHaptic":
            if let args = call.arguments as? [String: Any],
               let intensity = args["intensity"] as? Double,
               let sharpness = args["sharpness"] as? Double,
               let duration = args["duration"] as? Double {
                playContinuousHaptic(intensity: Float(intensity), sharpness: Float(sharpness), duration: duration, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing haptic parameters", details: nil))
            }
        case "stopHaptic":
            stopHaptic(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeCoreHaptics(result: @escaping FlutterResult) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            result(FlutterError(code: "NOT_SUPPORTED", message: "Device does not support haptics", details: nil))
            return
        }
        
        do {
            hapticsEngine = try CHHapticEngine()
            
            hapticsEngine?.stoppedHandler = { [weak self] reason in
                print("Core Haptics engine stopped: \(reason)")
                self?.restartHapticsEngine()
            }
            
            hapticsEngine?.resetHandler = { [weak self] in
                do {
                    try self?.hapticsEngine?.start()
                } catch {
                    print("Failed to restart haptics engine: \(error)")
                }
            }
            
            try hapticsEngine?.start()
            result(true)
        } catch {
            result(FlutterError(code: "INIT_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func restartHapticsEngine() {
        do {
            try hapticsEngine?.start()
        } catch {
            print("Failed to restart haptics engine: \(error)")
        }
    }
    
    private func disposeCoreHaptics(result: @escaping FlutterResult) {
        hapticsEngine?.stop()
        hapticsEngine = nil
        result(true)
    }
    
    private func playHapticPattern(_ patternData: [[String: Any]], result: @escaping FlutterResult) {
        guard let engine = hapticsEngine else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Haptics engine not initialized", details: nil))
            return
        }
        
        do {
            var events = [CHHapticEvent]()
            
            for item in patternData {
                guard let type = item["type"] as? String,
                      let time = item["time"] as? Double else {
                    continue
                }
                
                let relativeTime = TimeInterval(time)
                
                switch type {
                case "transient":
                    let intensity = Float(item["intensity"] as? Double ?? 1.0)
                    let sharpness = Float(item["sharpness"] as? Double ?? 0.5)
                    
                    let event = CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                        ],
                        relativeTime: relativeTime
                    )
                    events.append(event)
                    
                case "continuous":
                    let intensity = Float(item["intensity"] as? Double ?? 1.0)
                    let sharpness = Float(item["sharpness"] as? Double ?? 0.5)
                    let duration = item["duration"] as? Double ?? 0.3
                    
                    let event = CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                        ],
                        relativeTime: relativeTime,
                        duration: duration
                    )
                    events.append(event)
                    
                default:
                    break
                }
            }
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            
            result(true)
        } catch {
            result(FlutterError(code: "PLAY_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func playContinuousHaptic(intensity: Float, sharpness: Float, duration: Double, result: @escaping FlutterResult) {
        guard let engine = hapticsEngine else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Haptics engine not initialized", details: nil))
            return
        }
        
        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0,
                duration: duration
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            
            result(true)
        } catch {
            result(FlutterError(code: "PLAY_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func stopHaptic(result: @escaping FlutterResult) {
        hapticsEngine?.stop()
        result(true)
    }
    
    // MARK: - LiDAR Methods
    
    private func handleLidarMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isLidarAvailable":
            result(ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh))
        case "initializeLidar":
            initializeLidar(result: result)
        case "startScanning":
            startLidarScanning(result: result)
        case "stopScanning":
            stopLidarScanning(result: result)
        case "getDepthAtPoint":
            if let args = call.arguments as? [String: Any],
               let x = args["x"] as? Double,
               let y = args["y"] as? Double {
                getDepthAtPoint(x: Float(x), y: Float(y), result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing x,y coordinates", details: nil))
            }
        case "getClosestDistance":
            getClosestDistance(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeLidar(result: @escaping FlutterResult) {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            result(FlutterError(code: "NOT_SUPPORTED", message: "LiDAR not available on this device", details: nil))
            return
        }
        
        arSession = ARSession()
        arSession?.delegate = depthStreamHandler
        result(true)
    }
    
    private func startLidarScanning(result: @escaping FlutterResult) {
        guard let session = arSession else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "LiDAR not initialized", details: nil))
            return
        }
        
        let configuration = ARWorldTrackingConfiguration()
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        session.run(configuration)
        result(true)
    }
    
    private func stopLidarScanning(result: @escaping FlutterResult) {
        arSession?.pause()
        result(true)
    }
    
    private func getDepthAtPoint(x: Float, y: Float, result: @escaping FlutterResult) {
        guard let frame = arSession?.currentFrame,
              let sceneDepth = frame.sceneDepth else {
            result(nil)
            return
        }
        
        let depthMap = sceneDepth.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        let pixelX = Int(x * Float(width))
        let pixelY = Int(y * Float(height))
        
        guard pixelX >= 0 && pixelX < width && pixelY >= 0 && pixelY < height else {
            result(nil)
            return
        }
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        let pointer = baseAddress.advanced(by: pixelY * bytesPerRow + pixelX * MemoryLayout<Float32>.size)
        let depth = pointer.assumingMemoryBound(to: Float32.self).pointee
        
        result(Double(depth))
    }
    
    private func getClosestDistance(result: @escaping FlutterResult) {
        guard let frame = arSession?.currentFrame,
              let sceneDepth = frame.sceneDepth else {
            result(nil)
            return
        }
        
        let depthMap = sceneDepth.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        var minDistance: Float = Float.greatestFiniteMagnitude
        var minX: Int = 0
        var minY: Int = 0
        
        // Sample center region for closest object
        let sampleWidth = width / 2
        let sampleHeight = height / 2
        let startX = (width - sampleWidth) / 2
        let startY = (height - sampleHeight) / 2
        
        for y in stride(from: startY, to: startY + sampleHeight, by: 4) {
            for x in stride(from: startX, to: startX + sampleWidth, by: 4) {
                let pointer = baseAddress.advanced(by: y * bytesPerRow + x * MemoryLayout<Float32>.size)
                let depth = pointer.assumingMemoryBound(to: Float32.self).pointee
                
                if depth > 0 && depth < minDistance {
                    minDistance = depth
                    minX = x
                    minY = y
                }
            }
        }
        
        if minDistance < Float.greatestFiniteMagnitude {
            result([
                "distance": Double(minDistance),
                "x": Double(minX) / Double(width),
                "y": Double(minY) / Double(height)
            ])
        } else {
            result(nil)
        }
    }
}

// MARK: - Depth Stream Handler

class DepthStreamHandler: NSObject, FlutterStreamHandler, ARSessionDelegate {
    
    private var eventSink: FlutterEventSink?
    private var lastUpdate: Date = Date()
    private let updateInterval: TimeInterval = 0.1 // 10 FPS max
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let sink = eventSink,
              Date().timeIntervalSince(lastUpdate) >= updateInterval else {
            return
        }
        
        lastUpdate = Date()
        
        guard let sceneDepth = frame.sceneDepth else {
            return
        }
        
        let depthMap = sceneDepth.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        // Sample key points for depth data
        var depthPoints: [[String: Any]] = []
        
        // 9-point grid sampling
        for gridY in 0..<3 {
            for gridX in 0..<3 {
                let x = width / 4 + (width / 4) * gridX
                let y = height / 4 + (height / 4) * gridY
                
                let pointer = baseAddress.advanced(by: y * bytesPerRow + x * MemoryLayout<Float32>.size)
                let depth = pointer.assumingMemoryBound(to: Float32.self).pointee
                
                if depth > 0 {
                    depthPoints.append([
                        "x": Double(x) / Double(width),
                        "y": Double(y) / Double(height),
                        "distance": Double(depth)
                    ])
                }
            }
        }
        
        sink([
            "timestamp": Date().timeIntervalSince1970 * 1000,
            "width": width,
            "height": height,
            "points": depthPoints
        ])
    }
}
