import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ViewModels/onboarding_vm.dart';

class OnboardingScreen extends StatefulWidget {
  final String userId;

  const OnboardingScreen({super.key, required this.userId});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _rocketController;
  late AnimationController _launchController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _rocketController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _launchController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _rocketController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _rocketController.dispose();
    _launchController.dispose();
    super.dispose();
  }

  void _animateToNext() {
    _fadeController.reverse().then((_) {
      if (mounted) {
        context.read<OnboardingViewModel>().nextStep();
        _fadeController.forward();
        _rocketController.reset();
        _rocketController.forward();
      }
    });
  }

  void _animateToBack() {
    _fadeController.reverse().then((_) {
      if (mounted) {
        context.read<OnboardingViewModel>().previousStep();
        _fadeController.forward();
        _rocketController.reset();
        _rocketController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<OnboardingViewModel>(
        builder: (context, vm, child) {
          return SafeArea(
            child: Column(
              children: [
                _buildSimpleProgressBar(vm),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildCurrentStep(vm),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSimpleProgressBar(OnboardingViewModel vm) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${vm.currentStep + 1}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${vm.currentStep + 1} of ${vm.totalSteps}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (vm.currentStep + 1) / vm.totalSteps,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCurrentStep(OnboardingViewModel vm) {
    switch (vm.currentStep) {
      case 0:
        return _buildPrimaryInterestsStep(vm);
      case 1:
        return _buildSpecificInterestsStep(vm);
      case 2:
        return _buildPrimaryGoalStep(vm);
      case 3:
        return _buildMostUsedAppStep(vm);
      case 4:
        return _buildScreenTimeStep(vm);
      case 5:
        return _buildAgeRangeStep(vm);
      case 6:
        return _buildFinalStep(vm);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildScreenTimeStep(OnboardingViewModel vm) {
    return _buildStepTemplate(
      title: 'Daily Screen Time',
      subtitle: 'How much time do you spend on your phone daily?',
      options: vm.screenTimeOptions,
      selectedValue: vm.selectedScreenTime,
      onSelect: vm.selectScreenTime,
      vm: vm,
    );
  }

  Widget _buildMostUsedAppStep(OnboardingViewModel vm) {
    return _buildStepTemplate(
      title: 'Most Used Apps',
      subtitle: 'What type of apps do you spend most time on?',
      options: vm.appOptions,
      selectedValue: vm.selectedMostUsedApp,
      onSelect: vm.selectMostUsedApp,
      vm: vm,
    );
  }

  Widget _buildPrimaryInterestsStep(OnboardingViewModel vm) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Your Interests',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Select up to 5 topics that interest you most',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: vm.primaryInterestOptions.map((interest) {
                  final isSelected = vm.selectedPrimaryInterests.contains(interest);
                  final canSelect = vm.selectedPrimaryInterests.length < 5 || isSelected;

                  return _buildSimpleChip(
                    label: interest,
                    isSelected: isSelected,
                    onTap: canSelect ? () => vm.togglePrimaryInterest(interest) : null,
                  );
                }).toList(),
              ),
            ),
          ),
          _buildActionButtons(vm),
        ],
      ),
    );
  }

  Widget _buildSpecificInterestsStep(OnboardingViewModel vm) {
    final availableSubInterests = vm.getAvailableSubInterests();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Specific Areas',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose up to 7 specific areas you\'d like to focus on',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: availableSubInterests.map((subInterest) {
                  final isSelected = vm.selectedSubInterests.contains(subInterest);
                  final canSelect = vm.selectedSubInterests.length < 7 || isSelected;

                  return _buildSimpleChip(
                    label: subInterest,
                    isSelected: isSelected,
                    onTap: canSelect ? () => vm.toggleSubInterest(subInterest) : null,
                  );
                }).toList(),
              ),
            ),
          ),
          _buildActionButtons(vm),
        ],
      ),
    );
  }

  Widget _buildAgeRangeStep(OnboardingViewModel vm) {
    return _buildStepTemplate(
      title: 'How old are you?',
      subtitle: 'This helps us personalize your experience',
      options: vm.ageRangeOptions,
      selectedValue: vm.selectedAgeRange,
      onSelect: vm.selectAgeRange,
      vm: vm,
    );
  }

  Widget _buildPrimaryGoalStep(OnboardingViewModel vm) {
    return _buildStepTemplate(
      title: 'Goal',
      subtitle: 'What\'s your main focus right now?',
      options: vm.primaryGoalOptions,
      selectedValue: vm.selectedPrimaryGoal,
      onSelect: vm.selectPrimaryGoal,
      vm: vm,
    );
  }

  Widget _buildFinalStep(OnboardingViewModel vm) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Chill out!, Almost Done!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Just couple more quick questions',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            _buildQuestionSection(
              title: 'How do you prefer to be motivated?',
              options: vm.motivationStyleOptions,
              selectedValue: vm.selectedMotivationStyle,
              onSelect: vm.selectMotivationStyle,
            ),

            const SizedBox(height: 32),

            _buildQuestionSection(
              title: 'When would you like to receive productivity nudges?',
              options: vm.notificationTimeOptions,
              selectedValue: vm.selectedNotificationTime,
              onSelect: vm.selectNotificationTime,
            ),

            const SizedBox(height: 32),
            _buildActionButtons(vm, isLastStep: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTemplate({
    required String title,
    required String subtitle,
    required List<String> options,
    required String? selectedValue,
    required Function(String) onSelect,
    required OnboardingViewModel vm,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: options.map((option) {
                  bool isSelected = option == selectedValue;
                  return _buildSimpleOption(
                    title: option,
                    isSelected: isSelected,
                    onTap: () => onSelect(option),
                  );
                }).toList(),
              ),
            ),
          ),
          _buildActionButtons(vm),
        ],
      ),
    );
  }

  Widget _buildQuestionSection({
    required String title,
    required List<String> options,
    required String? selectedValue,
    required Function(String) onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...options.map((option) => _buildSimpleOption(
            title: option,
            isSelected: option == selectedValue,
            onTap: () => onSelect(option),
          )),
        ],
      ),
    );
  }

  Widget _buildSimpleOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? Colors.purple[50] : Colors.transparent,
              border: Border.all(
                color: isSelected ? Colors.purple : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.purple : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? Colors.purple : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleChip({
    required String label,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isSelected
                ? Colors.purple
                : onTap == null
                ? Colors.grey[100]
                : Colors.white,
            border: Border.all(
              color: isSelected
                  ? Colors.purple
                  : onTap == null
                  ? Colors.grey[300]!
                  : Colors.grey[400]!,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : onTap == null
                  ? Colors.grey[500]
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(OnboardingViewModel vm, {bool isLastStep = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          if (vm.currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _animateToBack,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: vm.currentStep > 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: vm.canProceedFromCurrentStep()
                  ? (isLastStep ? () => _handleFinish(vm) : _animateToNext)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Text(
                isLastStep ? 'Complete Setup' : 'Continue',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleFinish(OnboardingViewModel vm) async {
    bool saveSuccess = await vm.saveOnboardingData(widget.userId);
    
    if (!saveSuccess) {
      // Show error if save failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'Failed to save preferences'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (mounted) {
      // Show completion screen
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.purple[100],
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 50,
                              color: Colors.purple,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'All Set! 🎉',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your personalized notifications are ready.\nLet\'s start your focus journey!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                           Navigator.of(context).pop(); // Go back to main app
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Let\'s Go!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
    }
  }
}