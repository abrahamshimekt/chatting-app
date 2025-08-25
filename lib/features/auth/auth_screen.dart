import 'package:flutter/material.dart';
import '../../core/validators.dart';
import 'auth_service.dart';
import 'face_scanner_real.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _country = TextEditingController();
  final _region = TextEditingController();
  final _city = TextEditingController();
  final _subcity = TextEditingController();

  // Mode & state
  bool isLogin = true;
  String selectedGender = 'male';
  bool busy = false;
  bool _showPassword = false;

  // DOB state
  DateTime? _dob;

  // Verification state
  bool faceVerified = false;
  String? detectedGender; // 'male'/'female'

  final _auth = AuthService();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    _country.dispose();
    _region.dispose();
    _city.dispose();
    _subcity.dispose();
    super.dispose();
  }

  int _ageYears(DateTime dob, DateTime today) {
    int years = today.year - dob.year;
    final hadBirthdayThisYear =
        (today.month > dob.month) ||
        (today.month == dob.month && today.day >= dob.day);
    if (!hadBirthdayThisYear) years -= 1;
    return years;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 100, 1, 1);
    final last = now; // cannot be in the future
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _scanFace() async {
    if (_formKey.currentState == null) return;
    // Basic validation for signup fields before scanning
    if (!isLogin && !_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields first.')),
      );
      return;
    }

    setState(() {
      busy = true;
      faceVerified = false;
      detectedGender = null;
    });

    try {
      final scanner = RealFaceScanner(context: context);
      final result = await scanner.detectGender();
      setState(() {
        detectedGender = result;
        faceVerified = (result == selectedGender);
      });

      if (!mounted) return;
      if (faceVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Face scan verified as $result.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification failed. You selected "$selectedGender" but scan detected "$result".',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face scan error: $e')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final res = await _auth.signIn(_email.text.trim(), _pass.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.session != null ? 'Logged in' : 'Login returned no session')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _doSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth.')),
      );
      return;
    }

    final years = _ageYears(_dob!, DateTime.now());
    if (years < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be 18 or older to register.')),
      );
      return;
    }

    if (!faceVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete face verification first.')),
      );
      return;
    }

    setState(() => busy = true);
    try {
      final res = await _auth.signUp(
        _email.text.trim(),
        _pass.text.trim(),
        displayName: _name.text.trim(),
        gender: selectedGender,
        genderVerified: true,
        dateOfBirth: _dob!,
        country: _country.text.trim(),
        region: _region.text.trim(),
        city: _city.text.trim(),
        subcity: _subcity.text.trim().isEmpty ? null : _subcity.text.trim(),
      );

      if (!mounted) return;
      if (res.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created. Check your email to verify your account.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created and signed in')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Signup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ---------- UI helpers ----------

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helper,
    int? maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscure,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        helperText: helper,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Text(text, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              thickness: 1,
              endIndent: 0,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Widgets ----------

  Widget _responsiveHeader() {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;

        if (w < 380) {
          // Stack toggle under the title
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      isLogin ? Icons.lock_open_rounded : Icons.how_to_reg_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isLogin ? 'Sign in' : 'Create your account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
            ],
          );
        }

        // Wider: one row with safe flexing
        return Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                isLogin ? Icons.lock_open_rounded : Icons.how_to_reg_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isLogin ? 'Sign in' : 'Create your account',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }

  Widget _credentialsSection() {
    return Column(
      children: [
        _sectionTitle('Credentials'),
        _field(
          label: 'Email',
          controller: _email,
          validator: (v) => notEmpty(v, 'Email'),
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.mail_outline_rounded),
        ),
        const SizedBox(height: 12),
        _field(
          label: 'Password',
          controller: _pass,
          validator: (v) => notEmpty(v, 'Password'),
          obscure: !_showPassword,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _showPassword ? 'Hide' : 'Show',
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
          ),
        ),
      ],
    );
  }

  Widget _signupOnlySection() {
    if (isLogin) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        _sectionTitle('Personal info'),
        _field(
          label: 'Full name',
          controller: _name,
          validator: (v) => notEmpty(v, 'Name'),
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
        const SizedBox(height: 12),

        // Gender as chips
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              FilterChip(
                label: const Text('Male'),
                selected: selectedGender == 'male',
                onSelected: (_) {
                  setState(() {
                    selectedGender = 'male';
                    if (faceVerified && detectedGender != selectedGender) {
                      faceVerified = false;
                    }
                  });
                },
              ),
              FilterChip(
                label: const Text('Female'),
                selected: selectedGender == 'female',
                onSelected: (_) {
                  setState(() {
                    selectedGender = 'female';
                    if (faceVerified && detectedGender != selectedGender) {
                      faceVerified = false;
                    }
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // DOB
        TextFormField(
          readOnly: true,
          onTap: _pickDob,
          validator: (_) => _dob == null ? 'Select your date of birth' : null,
          decoration: InputDecoration(
            labelText: 'Date of birth',
            prefixIcon: const Icon(Icons.cake_outlined),
            suffixIcon: IconButton(
              tooltip: 'Pick date',
              onPressed: _pickDob,
              icon: const Icon(Icons.event_outlined),
            ),
            helperText: _dob == null
                ? 'You must be 18+ to register'
                : 'Selected: ${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
          ),
        ),

        const SizedBox(height: 16),
        _sectionTitle('Location'),
        LayoutBuilder(
          builder: (context, c) {
            final isNarrow = c.maxWidth < 480;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: isNarrow ? double.infinity : (c.maxWidth - 12) / 2,
                  child: _field(
                    label: 'Country',
                    controller: _country,
                    validator: (v) => notEmpty(v, 'Country'),
                    prefixIcon: const Icon(Icons.public_outlined),
                  ),
                ),
                SizedBox(
                  width: isNarrow ? double.infinity : (c.maxWidth - 12) / 2,
                  child: _field(
                    label: 'Region/State',
                    controller: _region,
                    validator: (v) => notEmpty(v, 'Region'),
                    prefixIcon: const Icon(Icons.map_outlined),
                  ),
                ),
                SizedBox(
                  width: isNarrow ? double.infinity : (c.maxWidth - 12) / 2,
                  child: _field(
                    label: 'City',
                    controller: _city,
                    validator: (v) => notEmpty(v, 'City'),
                    prefixIcon: const Icon(Icons.location_city_outlined),
                  ),
                ),
                SizedBox(
                  width: isNarrow ? double.infinity : (c.maxWidth - 12) / 2,
                  child: _field(
                    label: 'Subcity (optional)',
                    controller: _subcity,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 16),
        _sectionTitle('Face verification'),
        _faceVerificationCard(),
      ],
    );
  }

  Widget _faceVerificationCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive header row inside the card
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;

                final scanButton = OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40), // allow shrinking
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(faceVerified ? 'Re-scan' : 'Scan'),
                  onPressed: busy ? null : _scanFace,
                );

                final titleText = Text(
                  faceVerified ? 'Verified (${detectedGender!})' : 'Scan your face to verify gender',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                );

                if (w < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(faceVerified ? Icons.verified_rounded : Icons.camera_alt_outlined),
                          const SizedBox(width: 8),
                          Expanded(child: titleText),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: scanButton),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Icon(faceVerified ? Icons.verified_rounded : Icons.camera_alt_outlined),
                      const SizedBox(width: 8),
                      Expanded(child: titleText),
                      const SizedBox(width: 8),
                      Flexible(child: Align(alignment: Alignment.centerRight, child: scanButton)),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 6),
            Text(
              faceVerified
                  ? '✓ Your selection matches the detected gender.'
                  : detectedGender == null
                      ? 'We compare detected gender to your selection.'
                      : 'Mismatch: detected $detectedGender, selected $selectedGender.',
              style: TextStyle(color: faceVerified ? Colors.green : Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitEnabled = isLogin ? !busy : (!busy && faceVerified);

    // Optional: clamp extreme system text scaling to keep rows from overflowing.
    final media = MediaQuery.of(context);
    final clampedMedia = media.copyWith(
      textScaler: media.textScaler.clamp(maxScaleFactor: 1.2),
    );

    return MediaQuery(
      data: clampedMedia,
      child: Scaffold(
        // Soft gradient background for a premium feel
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF6F7F9), Color(0xFFECEFF3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Material(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shadowColor: Colors.black12,
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Main content
                      Form(
                        key: _formKey,
                        child: AbsorbPointer(
                          absorbing: busy,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _responsiveHeader(),
                                const SizedBox(height: 16),
                                _credentialsSection(),

                                // Sign-up specific (animated in/out)
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  child: isLogin
                                      ? const SizedBox.shrink()
                                      : Column(
                                          key: const ValueKey('signup'),
                                          children: [
                                            _signupOnlySection(),
                                          ],
                                        ),
                                ),

                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    icon: busy
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : Icon(isLogin ? Icons.login_rounded : Icons.person_add_alt_1_rounded),
                                    label: Text(isLogin ? 'Sign in' : 'Create account'),
                                    onPressed: submitEnabled
                                        ? () async {
                                            if (isLogin) {
                                              await _doLogin();
                                            } else {
                                              await _doSignUp();
                                            }
                                          }
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () {
                                          setState(() {
                                            isLogin = !isLogin;
                                            faceVerified = false;
                                            detectedGender = null;
                                          });
                                        },
                                  child: Text(isLogin
                                      ? 'Need an account? Sign up'
                                      : 'Already have an account? Sign in'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Busy overlay (subtle)
                      if (busy)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: 0.07,
                              duration: const Duration(milliseconds: 150),
                              child: Container(color: Colors.black),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
