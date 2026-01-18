import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/app_mode/data/datasources/app_mode_local_datasource.dart';
import '../../features/app_mode/data/repositories/app_mode_repository_impl.dart';
import '../../features/app_mode/domain/repositories/app_mode_repository.dart';
import '../../features/app_mode/domain/usecases/get_app_mode.dart';
import '../../features/app_mode/domain/usecases/set_app_mode.dart';
import '../../features/app_mode/presentation/bloc/app_mode_bloc.dart';
import '../../features/blind_mode/data/repositories/object_detection_repository_impl.dart';
import '../../features/blind_mode/domain/repositories/object_detection_repository.dart';
import '../../features/blind_mode/domain/usecases/detect_objects.dart';
import '../../features/blind_mode/presentation/bloc/blind_mode_bloc.dart';
import '../../features/deaf_mode/data/repositories/speech_recognition_repository_impl.dart';
import '../../features/deaf_mode/data/repositories/sign_language_repository_impl.dart';
import '../../features/deaf_mode/domain/repositories/speech_recognition_repository.dart';
import '../../features/deaf_mode/domain/repositories/sign_language_repository.dart';
import '../../features/deaf_mode/domain/usecases/transcribe_speech.dart';
import '../../features/deaf_mode/domain/usecases/recognize_sign_language.dart';
import '../../features/deaf_mode/presentation/bloc/deaf_mode_bloc.dart';
import '../services/camera_service.dart';
import '../services/haptic_service.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/ml_service.dart';
import '../services/lidar_service.dart';
import '../services/permission_service.dart';
import '../services/gemini_service.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  
  // Core Services
  getIt.registerLazySingleton<CameraService>(() => CameraServiceImpl());
  getIt.registerLazySingleton<HapticService>(() => HapticServiceImpl());
  getIt.registerLazySingleton<TtsService>(() => TtsServiceImpl());
  getIt.registerLazySingleton<SttService>(() => SttServiceImpl());
  getIt.registerLazySingleton<MlService>(() => MlServiceImpl());
  getIt.registerLazySingleton<LidarService>(() => LidarServiceImpl());
  getIt.registerLazySingleton<PermissionService>(() => PermissionServiceImpl());
  getIt.registerLazySingleton<GeminiService>(() => GeminiServiceImpl());
  
  // Data Sources
  getIt.registerLazySingleton<AppModeLocalDataSource>(
    () => AppModeLocalDataSourceImpl(getIt()),
  );
  
  // Repositories
  getIt.registerLazySingleton<AppModeRepository>(
    () => AppModeRepositoryImpl(getIt()),
  );
  getIt.registerLazySingleton<ObjectDetectionRepository>(
    () => ObjectDetectionRepositoryImpl(
      cameraService: getIt(),
      mlService: getIt(),
      lidarService: getIt(),
    ),
  );
  getIt.registerLazySingleton<SpeechRecognitionRepository>(
    () => SpeechRecognitionRepositoryImpl(
      sttService: getIt(),
      geminiService: getIt(),
    ),
  );
  getIt.registerLazySingleton<SignLanguageRepository>(
    () => SignLanguageRepositoryImpl(
      cameraService: getIt(),
      mlService: getIt(),
    ),
  );
  
  // Use Cases
  getIt.registerLazySingleton(() => GetAppMode(getIt()));
  getIt.registerLazySingleton(() => SetAppMode(getIt()));
  getIt.registerLazySingleton(() => DetectObjects(getIt()));
  getIt.registerLazySingleton(() => TranscribeSpeech(getIt()));
  getIt.registerLazySingleton(() => RecognizeSignLanguage(getIt()));
  
  // Blocs
  getIt.registerFactory(() => AppModeBloc(
    getAppMode: getIt(),
    setAppMode: getIt(),
    hapticService: getIt(),
  ));
  getIt.registerFactory(() => BlindModeBloc(
    detectObjects: getIt(),
    hapticService: getIt(),
    ttsService: getIt(),
    permissionService: getIt(),
    lidarService: getIt(),
  ));
  getIt.registerFactory(() => DeafModeBloc(
    transcribeSpeech: getIt(),
    recognizeSignLanguage: getIt(),
    permissionService: getIt(),
    ttsService: getIt(),
  ));
}
