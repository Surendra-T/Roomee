import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:roomee/theme/app_theme.dart';

enum OnboardingQuestionType { slider, choice, text }

class OnboardingQuestion {
  final String id;
  final String label;
  final OnboardingQuestionType type;
  final double min;
  final double max;
  final int divisions;
  final String minLabel;
  final String maxLabel;
  final List<String> options;
  final String hint;

  const OnboardingQuestion.slider({
    required this.id,
    required this.label,
    required this.minLabel,
    required this.maxLabel,
    this.min = 0.0,
    this.max = 10.0,
    this.divisions = 10,
  }) : type = OnboardingQuestionType.slider,
       options = const [],
       hint = '';

  const OnboardingQuestion.choice({
    required this.id,
    required this.label,
    required this.options,
  }) : type = OnboardingQuestionType.choice,
       min = 0.0,
       max = 0.0,
       divisions = 0,
       minLabel = '',
       maxLabel = '',
       hint = '';

  const OnboardingQuestion.text({
    required this.id,
    required this.label,
    required this.hint,
  }) : type = OnboardingQuestionType.text,
       min = 0.0,
       max = 0.0,
       divisions = 0,
       minLabel = '',
       maxLabel = '',
       options = const [];
}

class OnboardingQuestionsScreen extends StatefulWidget {
  const OnboardingQuestionsScreen({
    super.key,
    required this.name,
    required this.city,
  });

  final String name;
  final String city;

  @override
  State<OnboardingQuestionsScreen> createState() =>
      _OnboardingQuestionsScreenState();
}

class _OnboardingQuestionsScreenState extends State<OnboardingQuestionsScreen> {
  static const _questions = <OnboardingQuestion>[
    // Sliders
    OnboardingQuestion.slider(
      id: 'cleanliness',
      label: 'Cleanliness',
      minLabel: 'Relaxed',
      maxLabel: 'Spotless',
    ),
    OnboardingQuestion.slider(
      id: 'noise',
      label: 'Noise tolerance',
      minLabel: 'Quiet',
      maxLabel: 'Lively',
    ),
    OnboardingQuestion.slider(
      id: 'sleep',
      label: 'Sleep schedule',
      minLabel: 'Early bird',
      maxLabel: 'Night owl',
    ),
    OnboardingQuestion.slider(
      id: 'chores',
      label: 'Chore split',
      minLabel: 'Flexible',
      maxLabel: 'Strict',
    ),
    OnboardingQuestion.slider(
      id: 'temp',
      label: 'AC / Temperature',
      minLabel: 'Cold (Igloo)',
      maxLabel: 'Warm (Sauna)',
    ),

    // Choices
    OnboardingQuestion.choice(
      id: 'guests',
      label: 'Guests',
      options: ['Rarely', 'Sometimes', 'Often'],
    ),
    OnboardingQuestion.choice(
      id: 'sharing',
      label: 'Sharing',
      options: ['Keep separate', 'Some sharing', 'Open share'],
    ),
    OnboardingQuestion.choice(
      id: 'pets',
      label: 'Pets',
      options: ['No pets', 'Cats OK', 'Dogs OK', 'Any OK'],
    ),
    OnboardingQuestion.choice(
      id: 'wfh',
      label: 'Work from home',
      options: ['Never', 'Hybrid', 'Always'],
    ),

    // Text
    OnboardingQuestion.text(
      id: 'dealbreaker',
      label: 'Deal-breaker',
      hint: 'Optional (e.g. smoking, loud music)',
    ),
    OnboardingQuestion.text(
      id: 'notes',
      label: 'Additional Notes',
      hint: 'Anything else a roommate should know?',
    ),
  ];

  final Map<String, double> _sliderValues = {
    'cleanliness': 5,
    'noise': 5,
    'sleep': 5,
    'chores': 5,
    'temp': 5,
  };

  final Map<String, String> _choiceValues = {
    'guests': 'Rarely',
    'sharing': 'Keep separate',
    'pets': 'No pets',
    'wfh': 'Hybrid',
  };

  final TextEditingController _dealbreakerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _dealbreakerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Please sign in again.';
        _isSaving = false;
      });
      return;
    }

    try {
      final answers = <String, dynamic>{
        ..._sliderValues,
        ..._choiceValues,
        'dealbreaker': _dealbreakerController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'name': widget.name,
        'city': widget.city,
        'answers': answers,
        'onboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(widget.name);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseException catch (error) {
      setState(() {
        _errorMessage = error.message ?? 'Failed to save your answers.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
              Text('Compatibility check', style: titleStyle),
              const SizedBox(height: 8),
              Text(
                'Answer a few quick questions to find better matches.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              for (final question in _questions) ...[
                _QuestionLabel(text: question.label),
                const SizedBox(height: 12),
                if (question.type == OnboardingQuestionType.slider)
                  _SliderQuestion(
                    question: question,
                    value: _sliderValues[question.id] ?? 5,
                    onChanged: (value) {
                      setState(() {
                        _sliderValues[question.id] = value;
                      });
                    },
                  ),
                if (question.type == OnboardingQuestionType.choice)
                  _ChoiceQuestion(
                    question: question,
                    value: _choiceValues[question.id] ?? question.options.first,
                    onChanged: (value) {
                      setState(() {
                        _choiceValues[question.id] = value;
                      });
                    },
                  ),
                if (question.type == OnboardingQuestionType.text)
                  TextField(
                    controller: question.id == 'dealbreaker'
                        ? _dealbreakerController
                        : _notesController,
                    decoration: InputDecoration(hintText: question.hint),
                  ),
                const SizedBox(height: 24),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryText,
                    foregroundColor: AppColors.pureWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.pureWhite,
                          ),
                        )
                      : const Text('Save and continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionLabel extends StatelessWidget {
  const _QuestionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: AppColors.primaryText,
      ),
    );
  }
}

class _SliderQuestion extends StatelessWidget {
  const _SliderQuestion({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final OnboardingQuestion question;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            activeTrackColor: AppColors.primaryAction,
            inactiveTrackColor: AppColors.subtleBorder,
            thumbColor: AppColors.primaryAction,
            overlayColor: AppColors.primaryAction.withOpacity(0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            min: question.min,
            max: question.max,
            divisions: question.divisions,
            value: value,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SliderLabel(text: question.minLabel),
            _SliderLabel(text: question.maxLabel),
          ],
        ),
      ],
    );
  }
}

class _SliderLabel extends StatelessWidget {
  const _SliderLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 11,
        letterSpacing: 1.8,
        color: AppColors.secondaryText,
      ),
    );
  }
}

class _ChoiceQuestion extends StatelessWidget {
  const _ChoiceQuestion({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final OnboardingQuestion question;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final option in question.options)
          _ChoicePill(
            label: option,
            selected: value == option,
            onTap: () => onChanged(option),
          ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryAction : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryAction : AppColors.subtleBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.pureWhite
                      : AppColors.subtleBorder,
                ),
                color: selected ? AppColors.pureWhite : Colors.transparent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: selected ? AppColors.pureWhite : AppColors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
