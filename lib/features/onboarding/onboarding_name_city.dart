import 'package:flutter/material.dart';
import 'package:roomee/features/onboarding/onboarding_questions.dart';
import 'package:roomee/theme/app_theme.dart';

class OnboardingNameCityScreen extends StatefulWidget {
  const OnboardingNameCityScreen({
    super.key,
    this.initialName,
    this.initialCity,
  });

  final String? initialName;
  final String? initialCity;

  @override
  State<OnboardingNameCityScreen> createState() => _OnboardingNameCityScreenState();
}

class _OnboardingNameCityScreenState extends State<OnboardingNameCityScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _cityController = TextEditingController(text: widget.initialCity ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();

    if (name.isEmpty || city.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both your name and city.';
      });
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingQuestionsScreen(name: name, city: city),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
          fontSize: 36,
          height: 1.1,
          fontWeight: FontWeight.w600,
        );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Roomee', style: titleStyle),
              const SizedBox(height: 12),
              Text(
                'Start with the basics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'We only use this to personalize your matches.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cityController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'City',
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.redAccent,
                      ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryText,
                    foregroundColor: AppColors.pureWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
