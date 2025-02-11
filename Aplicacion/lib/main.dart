import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

Future<BotResponse> sendMessageToRasa(String message) async {
  final response = await http.post(
    Uri.parse('http://172.26.44.106:5005/webhooks/rest/webhook'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'sender': 'user',
      'message': message,
    }),
  );

  if (response.statusCode == 200) {
    List<dynamic> responseData = jsonDecode(response.body);
    return BotResponse.fromJson(responseData[0]);
  } else {
    throw Exception('Failed to get response from server.');
  }
}

class BotResponse {
  final String text;

  const BotResponse({required this.text});

  factory BotResponse.fromJson(Map<String, dynamic> json) {
    return BotResponse(
      text: json['text'],
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() {
    return _MyAppState();
  }
}

class _MyAppState extends State<MyApp> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];

  late stt.SpeechToText _speech;
  bool _isListening = false;

  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    flutterTts.setLanguage("es-ES");

    // Verificar los idiomas disponibles (opcional, para debugging)
    _speech.initialize().then((_) {
      print("Locales disponibles: ${_speech.locales()}");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat con Rasa',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Chat con Rasa'),
        ),
        body: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Align(
                        alignment: _messages[index].isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _messages[index].isUser
                                ? const Color.fromARGB(255, 124, 211, 145)
                                : const Color.fromARGB(255, 206, 206, 206),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_messages[index].text),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          IconButton(
                            onPressed:
                                _listen, // Inicia la escucha al tocar el icono
                            icon: Icon(
                              _isListening ? Icons.mic_off : Icons.mic,
                              size: 35.0,
                              color: _isListening
                                  ? Colors.red
                                  : const Color.fromARGB(255, 124, 211, 145),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: const InputDecoration(
                                hintText: 'Pregunte a nuestro asistente...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          print("Status: $val");
          if (val == "notListening") {
            setState(() {
              _isListening = false;
            });
            // Si hay texto en el controlador, enviamos el mensaje
            if (_controller.text.isNotEmpty) {
              _sendMessage();
            }
          }
        },
        onError: (val) => print("Error en Speech-to-Text: $val"),
      );

      if (available) {
        setState(() {
          _isListening = true;
          // Limpiar el texto anterior al comenzar a escuchar
          _controller.clear();
        });

        // Configuración específica para español
        _speech.listen(
          onResult: (val) {
            setState(() {
              // Actualiza el texto en tiempo real mientras habla
              _controller.text = val.recognizedWords;
            });
          },
          localeId:
              'es-ES', // Configurar específicamente para español de España
          listenFor: Duration(seconds: 30), // Tiempo máximo de escucha
          pauseFor: Duration(seconds: 2), // Pausa después de dejar de hablar
          partialResults: true, // Mostrar resultados parciales
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        );
      }
    } else {
      setState(() {
        _isListening = false;
      });
      _speech.stop();
      // Si hay texto en el controlador, enviamos el mensaje
      if (_controller.text.isNotEmpty) {
        _sendMessage();
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final String userMessage = _controller.text;
    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true));
    });
    _controller.clear();

    try {
      final botResponse = await sendMessageToRasa(userMessage);
      setState(() {
        _messages.add(ChatMessage(text: botResponse.text, isUser: false));
      });
      _speak(botResponse.text); // Llamamos a la función para leer el texto
    } catch (error) {
      setState(() {
        _messages.add(ChatMessage(text: "Error: $error", isUser: false));
      });
    }
  }

  Future<void> _speak(String text) async {
    await flutterTts.setLanguage("es-ES"); // Configurar idioma en español
    await flutterTts.setPitch(1.0); // Ajustar tono de voz
    await flutterTts.speak(text);
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  const ChatMessage({required this.text, required this.isUser});
}
