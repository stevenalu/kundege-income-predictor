import 'dart:convert';
import 'package:http/http.dart' as http;

// Talks to our FastAPI service that is hosted on Render.
class ApiService {
  static const String baseUrl = "https://kundege-income.onrender.com";

  // Sends the profile to /predict and returns the estimated income in RWF.
  static Future<double> predictIncome(Map<String, dynamic> profile) async {
    final url = Uri.parse("$baseUrl/predict");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(profile),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data["estimated_monthly_income_rwf"] as num).toDouble();
    }

    // The API returns a "detail" message when the input is wrong or out of range.
    String message = "Request failed (${response.statusCode}).";
    try {
      final body = jsonDecode(response.body);
      if (body["detail"] != null) message = body["detail"].toString();
    } catch (_) {}
    throw Exception(message);
  }

  // Uploads a new dataset (CSV bytes) to /retrain and returns a short summary.
  static Future<String> retrainModel(List<int> fileBytes, String fileName) async {
    final url = Uri.parse("$baseUrl/retrain");

    final request = http.MultipartRequest("POST", url)
      ..files.add(http.MultipartFile.fromBytes("file", fileBytes, filename: fileName));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return "${data["message"]}\n"
          "Rows used: ${data["rows_used"]}  •  "
          "R²: ${data["train_r2"]}  •  RMSE: ${data["train_rmse"]}";
    }

    String message = "Retrain failed (${response.statusCode}).";
    try {
      final body = jsonDecode(response.body);
      if (body["detail"] != null) message = body["detail"].toString();
    } catch (_) {}
    throw Exception(message);
  }
}
