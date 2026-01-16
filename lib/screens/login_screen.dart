import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Track which field is currently focused for the number pad
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isPhoneFieldFocused = true;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onPhoneFocusChange);
    _passwordFocusNode.addListener(_onPasswordFocusChange);
  }

  void _onPhoneFocusChange() {
    if (_phoneFocusNode.hasFocus) {
      setState(() {
        _isPhoneFieldFocused = true;
      });
    }
  }

  void _onPasswordFocusChange() {
    if (_passwordFocusNode.hasFocus) {
      setState(() {
        _isPhoneFieldFocused = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    final controller = _isPhoneFieldFocused ? _phoneController : _passwordController;
    final currentText = controller.text;
    final selection = controller.selection;

    String newText;
    int newCursorPosition;

    if (selection.isValid && selection.start != selection.end) {
      // Replace selected text
      newText = currentText.replaceRange(selection.start, selection.end, number);
      newCursorPosition = selection.start + 1;
    } else if (selection.isValid) {
      // Insert at cursor position
      newText = currentText.substring(0, selection.start) + number + currentText.substring(selection.start);
      newCursorPosition = selection.start + 1;
    } else {
      // Append to end
      newText = currentText + number;
      newCursorPosition = newText.length;
    }

    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newCursorPosition);
  }

  void _onBackspacePressed() {
    final controller = _isPhoneFieldFocused ? _phoneController : _passwordController;
    final currentText = controller.text;
    final selection = controller.selection;

    if (currentText.isEmpty) return;

    String newText;
    int newCursorPosition;

    if (selection.isValid && selection.start != selection.end) {
      // Delete selected text
      newText = currentText.replaceRange(selection.start, selection.end, '');
      newCursorPosition = selection.start;
    } else if (selection.isValid && selection.start > 0) {
      // Delete character before cursor
      newText = currentText.substring(0, selection.start - 1) + currentText.substring(selection.start);
      newCursorPosition = selection.start - 1;
    } else if (currentText.isNotEmpty) {
      // Delete last character
      newText = currentText.substring(0, currentText.length - 1);
      newCursorPosition = newText.length;
    } else {
      return;
    }

    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newCursorPosition);
  }

  void _onClearPressed() {
    final controller = _isPhoneFieldFocused ? _phoneController : _passwordController;
    controller.clear();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final identifier = _phoneController.text.trim();
      final password = _passwordController.text;

      try {
        await _authService.login(identifier, password);

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthChecker()),
        );
      } on AuthException catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildNumberPadButton(String label, {VoidCallback? onPressed, Color? backgroundColor, Color? textColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: backgroundColor ?? Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed ?? () => _onNumberPressed(label),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Row(
          children: [
            _buildNumberPadButton('1'),
            _buildNumberPadButton('2'),
            _buildNumberPadButton('3'),
          ],
        ),
        Row(
          children: [
            _buildNumberPadButton('4'),
            _buildNumberPadButton('5'),
            _buildNumberPadButton('6'),
          ],
        ),
        Row(
          children: [
            _buildNumberPadButton('7'),
            _buildNumberPadButton('8'),
            _buildNumberPadButton('9'),
          ],
        ),
        Row(
          children: [
            _buildNumberPadButton(
              'C',
              onPressed: _onClearPressed,
              backgroundColor: Colors.orange.shade100,
              textColor: Colors.orange.shade700,
            ),
            _buildNumberPadButton('0'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Material(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _onBackspacePressed,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.backspace_outlined,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // App Icon
                Image.asset(
                  'images/icon.png',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 16),

                // SIRA PRO Title
                const Text(
                  'SIRA PRO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),

                // French Abbreviation
                const Text(
                  'Système Intelligent de Routing & d\'Analyse',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 32),

                // Phone Number Field
                TextFormField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '0123456789',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _isPhoneFieldFocused ? Theme.of(context).primaryColor : Colors.grey,
                        width: _isPhoneFieldFocused ? 2 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    filled: _isPhoneFieldFocused,
                    fillColor: _isPhoneFieldFocused ? Theme.of(context).primaryColor.withValues(alpha: 0.05) : null,
                  ),
                  onTap: () {
                    setState(() {
                      _isPhoneFieldFocused = true;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.length < 10) {
                      return 'Phone number must be 10 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field (digits only)
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your PIN',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: !_isPhoneFieldFocused ? Theme.of(context).primaryColor : Colors.grey,
                        width: !_isPhoneFieldFocused ? 2 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    filled: !_isPhoneFieldFocused,
                    fillColor: !_isPhoneFieldFocused ? Theme.of(context).primaryColor.withValues(alpha: 0.05) : null,
                  ),
                  onTap: () {
                    setState(() {
                      _isPhoneFieldFocused = false;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 4) {
                      return 'Password must be at least 4 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 24),

                // On-screen Number Pad
                _buildNumberPad(),

                const SizedBox(height: 16),

                // Forgot Password Link
                TextButton(
                  onPressed: () {
                    // TODO: Implement forgot password
                  },
                  child: const Text('Forgot Password?'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
