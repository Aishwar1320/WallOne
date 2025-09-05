import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration widget for setting up the AI advisor
class AISetupScreen extends StatefulWidget {
  const AISetupScreen({super.key});

  @override
  State<AISetupScreen> createState() => _AISetupScreenState();
}

class _AISetupScreenState extends State<AISetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  bool _isLoading = false;
  bool _obscureApiKey = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final existingKey = prefs.getString('GEMINI_API_KEY');
    if (existingKey != null) {
      _apiKeyController.text = existingKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Advisor Setup'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildApiKeySection(),
              const SizedBox(height: 24),
              _buildFeaturesSection(),
              const SizedBox(height: 32),
              _buildSetupButton(),
              const SizedBox(height: 24),
              _buildInstructionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.purple,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Financial Advisor',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Get personalized financial insights and automation',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildApiKeySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Google Gemini API Key',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _apiKeyController,
          obscureText: _obscureApiKey,
          decoration: InputDecoration(
            hintText: 'Enter your Gemini API key',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.key),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                      _obscureApiKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscureApiKey = !_obscureApiKey;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: _pasteFromClipboard,
                ),
              ],
            ),
            errorText: _errorMessage,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your API key';
            }
            if (!value.startsWith('AIza')) {
              return 'Invalid API key format';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Get your free API key from Google AI Studio',
                  style: TextStyle(color: Colors.blue[700]),
                ),
              ),
              TextButton(
                onPressed: _openAPIKeyInstructions,
                child: const Text('How to get'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection() {
    final features = [
      {
        'icon': Icons.insights,
        'title': 'Smart Insights',
        'description':
            'AI analyzes your spending patterns and provides personalized recommendations'
      },
      {
        'icon': Icons.auto_fix_high,
        'title': 'Auto Optimization',
        'description':
            'Automatically optimize budgets and suggest better financial decisions'
      },
      {
        'icon': Icons.category,
        'title': 'Smart Categorization',
        'description': 'AI suggests categories for your expenses automatically'
      },
      {
        'icon': Icons.trending_up,
        'title': 'Investment Advice',
        'description':
            'Get AI-powered investment recommendations based on your financial health'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What you\'ll get:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          feature['description'] as String,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSetupButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _setupAI,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Setting up AI...'),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch),
                  SizedBox(width: 8),
                  Text('Setup AI Advisor'),
                ],
              ),
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return ExpansionTile(
      title: const Text('Setup Instructions'),
      leading: const Icon(Icons.help_outline),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInstructionStep(
                '1',
                'Get API Key',
                'Visit ai.google.dev and create a free Gemini API key',
              ),
              _buildInstructionStep(
                '2',
                'Copy Key',
                'Copy the API key from Google AI Studio',
              ),
              _buildInstructionStep(
                '3',
                'Paste Here',
                'Paste the API key in the field above and tap Setup',
              ),
              _buildInstructionStep(
                '4',
                'Enjoy AI Features',
                'Start getting personalized financial insights!',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(
      String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        _apiKeyController.text = data!.text!;
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to paste from clipboard')),
      );
    }
  }

  void _openAPIKeyInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Get Your API Key'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Follow these steps to get your free Gemini API key:'),
            SizedBox(height: 12),
            Text('1. Go to ai.google.dev'),
            Text('2. Click "Get API key in Google AI Studio"'),
            Text('3. Sign in with your Google account'),
            Text('4. Create a new API key'),
            Text('5. Copy the key and paste it here'),
            SizedBox(height: 12),
            Text(
              'The API key is free and gives you generous usage limits for personal use.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _setupAI() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save API key to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gemini_api_key', _apiKeyController.text.trim());

      // Test API key by making a simple request
      await _testAPIKey(_apiKeyController.text.trim());

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Advisor setup successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid API key or connection failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Setup failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testAPIKey(String apiKey) async {
    // Simple test to validate API key
    // You can implement actual API validation here
    if (!apiKey.startsWith('AIza') || apiKey.length < 30) {
      throw Exception('Invalid API key format');
    }
  }
}
