// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// tts_helper_web.dart
import 'dart:html' as html;

void speakInspectionVerdict(String text) {
  try {
    final synth = html.window.speechSynthesis;
    if (synth != null) {
      synth.cancel();
      final utterance = html.SpeechSynthesisUtterance(text);
      utterance.rate = 0.95;
      utterance.pitch = 1.0;
      utterance.lang = 'en-US';
      synth.speak(utterance);
    }
  } catch (_) {}
}

bool get isSpeechSupported {
  try {
    return html.window.speechSynthesis != null;
  } catch (_) {
    return false;
  }
}
