import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';

void main() => runApp(const KundegeApp());

class KundegeApp extends StatelessWidget {
  const KundegeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Ku ndege Income Estimator",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C66)),
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  // the choices below must match the values the API accepts
  final educationOptions = ["Primary or Less", "Secondary", "TVET", "University"];
  final genderOptions = ["Male", "Female"];
  final locationOptions = ["Urban", "Rural"];
  final formalityOptions = ["Formal", "Informal"];
  final regionOptions = ["Kigali", "Eastern", "Western", "Northern", "Southern"];
  final sectorOptions = ["Agriculture", "Construction", "Education", "Healthcare", "ICT", "Retail"];
  final digitalOptions = ["Basic", "Intermediate", "Advanced"];

  // current selections (start on the first option so nothing is ever empty)
  late String education = educationOptions.first;
  late String gender = genderOptions.first;
  late String location = locationOptions.first;
  late String formality = formalityOptions.first;
  late String region = regionOptions.first;
  late String sector = sectorOptions.first;
  late String digital = digitalOptions.first;

  final ageController = TextEditingController(text: "22");
  final skillController = TextEditingController(text: "1");

  bool loading = false;
  String? result;   // formatted income to show
  String? error;    // error text to show in red

  bool retrainLoading = false;
  String? retrainStatus;   // retrain summary or error message
  bool retrainFailed = false;

  @override
  void dispose() {
    ageController.dispose();
    skillController.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    // basic range checks before we bother the server
    final age = int.tryParse(ageController.text.trim());
    final skills = int.tryParse(skillController.text.trim());

    if (age == null || age < 16 || age > 25) {
      setState(() { error = "Age must be a number between 16 and 25."; result = null; });
      return;
    }
    if (skills == null || skills < 0 || skills > 10) {
      setState(() { error = "Skill count must be a number between 0 and 10."; result = null; });
      return;
    }

    setState(() { loading = true; error = null; result = null; });

    try {
      final income = await ApiService.predictIncome({
        "age": age,
        "education_level": education,
        "gender": gender,
        "location_type": location,
        "formal_informal": formality,
        "region": region,
        "sector": sector,
        "digital_skills": digital,
        "skill_count": skills,
      });
      setState(() => result = _formatRwf(income));
    } catch (e) {
      setState(() => error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      setState(() => loading = false);
    }
  }

  // Lets the user pick a CSV and sends it to the API to retrain the model.
  Future<void> _retrain() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["csv"],
      withData: true,
    );
    if (picked == null) return; // user closed the picker

    final file = picked.files.single;
    setState(() { retrainLoading = true; retrainStatus = null; retrainFailed = false; });

    try {
      final summary = await ApiService.retrainModel(file.bytes!, file.name);
      setState(() { retrainStatus = summary; retrainFailed = false; });
    } catch (e) {
      setState(() {
        retrainStatus = e.toString().replaceFirst("Exception: ", "");
        retrainFailed = true;
      });
    } finally {
      setState(() => retrainLoading = false);
    }
  }

  // turns 168194.0 into "RWF 168,194"
  String _formatRwf(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(",");
      buffer.write(digits[i]);
    }
    return "RWF ${buffer.toString()}";
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        title: const Text("Ku ndege Income Estimator"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Estimate a young worker's monthly income",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              "Fill in the profile and tap Predict.",
              style: TextStyle(color: colors.outline),
            ),
            const SizedBox(height: 16),

            // ---- the input card ----
            Card(
              elevation: 0,
              color: colors.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _numberField("Age (16 - 25)", ageController),
                    _dropdown("Education level", education, educationOptions, (v) => setState(() => education = v!)),
                    _dropdown("Gender", gender, genderOptions, (v) => setState(() => gender = v!)),
                    _dropdown("Location", location, locationOptions, (v) => setState(() => location = v!)),
                    _dropdown("Employment type", formality, formalityOptions, (v) => setState(() => formality = v!)),
                    _dropdown("Region", region, regionOptions, (v) => setState(() => region = v!)),
                    _dropdown("Work sector", sector, sectorOptions, (v) => setState(() => sector = v!)),
                    _dropdown("Digital skills", digital, digitalOptions, (v) => setState(() => digital = v!)),
                    _numberField("Number of practical skills (0 - 10)", skillController),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- predict button ----
            FilledButton.icon(
              onPressed: loading ? null : _predict,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.trending_up),
              label: Text(loading ? "Predicting..." : "Predict"),
            ),
            const SizedBox(height: 16),

            // ---- result / error area ----
            _resultBox(colors),
            const SizedBox(height: 24),

            // ---- retrain section (uploads a new dataset to the API) ----
            Divider(color: colors.outlineVariant),
            const SizedBox(height: 8),
            Text("Update the model", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: retrainLoading ? null : _retrain,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: retrainLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(retrainLoading ? "Retraining..." : "Retrain with a CSV"),
            ),
            if (retrainStatus != null) ...[
              const SizedBox(height: 10),
              Text(
                retrainStatus!,
                style: TextStyle(
                  color: retrainFailed ? colors.error : colors.primary,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _numberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      ),
    );
  }

  Widget _resultBox(ColorScheme colors) {
    // nothing to show yet
    if (result == null && error == null) {
      return const SizedBox.shrink();
    }

    final isError = error != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.payments_outlined,
            size: 34,
            color: isError ? colors.onErrorContainer : colors.onPrimaryContainer,
          ),
          const SizedBox(height: 8),
          Text(
            isError ? "Could not predict" : "Estimated monthly income",
            style: TextStyle(color: isError ? colors.onErrorContainer : colors.onPrimaryContainer),
          ),
          const SizedBox(height: 6),
          Text(
            isError ? error! : result!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isError ? 15 : 26,
              fontWeight: FontWeight.bold,
              color: isError ? colors.onErrorContainer : colors.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
