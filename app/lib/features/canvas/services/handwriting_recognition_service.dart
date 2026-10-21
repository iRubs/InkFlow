import '../models/stroke.dart';

/// Punto de extensión para un motor local de escritura sin red ni telemetría.
abstract class HandwritingRecognitionService {
  bool get isSupported;
  Future<bool> isModelDownloaded(String languageCode);
  Future<bool> downloadModel(String languageCode);
  Future<String?> recognize(List<Stroke> strokes, {String languageCode = 'es'});
  void dispose();
}

/// La UI ofrece transcripción manual mientras falta un motor local.
class OfflineHandwritingService implements HandwritingRecognitionService {
  @override
  bool get isSupported => false;
  @override
  Future<bool> isModelDownloaded(String languageCode) async => false;
  @override
  Future<bool> downloadModel(String languageCode) async => false;
  @override
  Future<String?> recognize(
    List<Stroke> strokes, {
    String languageCode = 'es',
  }) async => null;
  @override
  void dispose() {}
}
