import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(CVAssistantApp());
}

class CVAssistantApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PDFAssistant(),
    );
  }
}

class PDFAssistant extends StatefulWidget {
  @override
  _PDFAssistantState createState() => _PDFAssistantState();
}

class _PDFAssistantState extends State<PDFAssistant> {
  final TextEditingController _questionController = TextEditingController();
  List<String> _filteredCVNames = [];
  List<String> _cvFilePaths = [];
  String _openAiApiKey = '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'; // Replace with your OpenAI API key
  bool _isLoading = false;

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _cvFilePaths = result.paths.where((path) => path != null).cast<String>().toList();
      });
    }
  }

  Future<void> _askQuestion() async {
    final String question = _questionController.text;
    if (_cvFilePaths.isEmpty || question.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true; // Start loading
    });

    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_openAiApiKey",
      },
      body: json.encode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {
            "role": "system",
            "content": "You are a helpful assistant who can read and interpret PDF documents."
          },
          {
            "role": "user",
            "content": "The following is a list of CVs available: ${_cvFilePaths.join(', ')}. Please list the CV names and their corresponding paths in the format 'CV Name - path/to/cv.pdf': $question"
          }
        ],
        "max_tokens": 200,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      String answer = jsonResponse['choices'][0]['message']['content'];

      // Parse the response to create a list of CVs with paths
      _filteredCVNames.clear();
      _cvFilePaths.clear();

      // Split response into lines (assuming each line is a CV and path)
      List<String> lines = answer.split('\n');
      for (String line in lines) {
        // Expecting format "CV Name - path/to/cv.pdf"
        var parts = line.split(' - ');
        if (parts.length == 2) {
          _filteredCVNames.add(parts[0].trim());
          _cvFilePaths.add(parts[1].trim());
        }
      }

      setState(() {});
    } else {
      setState(() {
        _filteredCVNames = ["Error: ${response.reasonPhrase}"];
        _cvFilePaths.clear(); // Clear file paths on error
      });
    }

    setState(() {
      _isLoading = false; // Stop loading
    });
  }

  Future<void> _openCV(String cvPath) async {
    final Uri uri = Uri.file(cvPath); // Create a Uri from the file path
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri); // Use launchUrl instead of launch
    } else {
      throw 'Could not launch $cvPath';
    }
  }

  // Function to reset the app state
  void _resetApp() {
    setState(() {
      _questionController.clear(); // Clear the text field
      _filteredCVNames.clear(); // Clear filtered CVs
      _cvFilePaths.clear(); // Clear file paths
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff272727),
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png'),
        centerTitle: true,
        toolbarHeight: 200,
        backgroundColor: Color(0xff272727),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _pickFiles,
              child: Text('Choose CVs'),
            ),
            TextField(
              controller: _questionController,
              decoration: InputDecoration(labelText: 'Ask a question about CVs'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _askQuestion,
              child: _isLoading ? CircularProgressIndicator() : Text('Ask AI'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredCVNames.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_filteredCVNames[index]),
                    onTap: () => _openCV(_cvFilePaths[index]), // Open the CV file
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Floating action button with delete icon to reset the app
      floatingActionButton: FloatingActionButton(
        onPressed: _resetApp, // Call the reset function
        child: Icon(Icons.delete),
        backgroundColor: Colors.red,
      ),
    );
  }
}
