import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ElevenLabsClient {
  final String apiKey;
  final String baseUrl = 'https://api.elevenlabs.io';

  ElevenLabsClient({required this.apiKey});

  Future<http.Response> textToSpeech({
    required String text,
    required String voiceId,
    String modelId = 'eleven_monolingual_v1',
    Map<String, dynamic>? voiceSettings,
  }) async {
    final url = Uri.parse('$baseUrl/v1/text-to-speech/$voiceId');
    final response = await http.post(
      url,
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: jsonEncode({
        'text': text,
        'model_id': modelId,
        if (voiceSettings != null) 'voice_settings': voiceSettings,
      }),
    );
    return response;
  }

  Future<http.Response> getVoices() async {
    final url = Uri.parse('$baseUrl/v1/voices');
    final response = await http.get(
      url,
      headers: {'xi-api-key': apiKey, 'Accept': 'application/json'},
    );
    return response;
  }
}

Future<ElevenLabsClient> getElevenLabsConfig() async {
  final String? apiKey = dotenv.env['ELEVEN_LABS_API_KEY'];

  if (apiKey == null || apiKey.isEmpty) {
    throw Exception('Eleven Labs API key not found or empty in .env');
  }

  return ElevenLabsClient(apiKey: apiKey);
}
