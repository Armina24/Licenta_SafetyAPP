import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';

class AccountInfoScreen extends StatefulWidget {
  final String? userEmail;

  const AccountInfoScreen({super.key, this.userEmail});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _dateOfBirthController;
  late TextEditingController _addressController;
  
  String? _selectedGender;
  bool _isLoading = false;
  bool _isSaving = false;
  
  final List<String> _genders = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController(text: widget.userEmail ?? '');
    _phoneController = TextEditingController();
    _dateOfBirthController = TextEditingController();
    _addressController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _fullNameController.text = prefs.getString('fullName') ?? '';
      _phoneController.text = prefs.getString('phone') ?? '';
      _dateOfBirthController.text = prefs.getString('dateOfBirth') ?? '';
      _selectedGender = prefs.getString('gender');
      _addressController.text = prefs.getString('homeAddress') ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    if (_fullNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      await prefs.setString('fullName', _fullNameController.text);
      await prefs.setString('phone', _phoneController.text);
      await prefs.setString('dateOfBirth', _dateOfBirthController.text);
      if (_selectedGender != null) {
        await prefs.setString('gender', _selectedGender!);
      }
      await prefs.setString('homeAddress', _addressController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.transparent : const Color(0xFFFFF8F2);
    final textColor =
        isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F);
    final secondaryTextColor =
        isDarkMode ? AppTheme.textSecondary : const Color(0xFF707070);
    final fieldBgColor = isDarkMode
        ? AppTheme.glassDarkMedium
        : Colors.white;
    final fieldBorderColor = isDarkMode
        ? AppTheme.glassBorder
        : const Color(0xFFE0E0E0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Account Information',
          style: TextStyle(color: textColor),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Full Name
                  _buildTextField(
                    controller: _fullNameController,
                    label: 'Full Name',
                    icon: Icons.person_outlined,
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    fieldBgColor: fieldBgColor,
                    fieldBorderColor: fieldBorderColor,
                    secondaryTextColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 16),

                  // Email (Read-only)
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    fieldBgColor: fieldBgColor,
                    fieldBorderColor: fieldBorderColor,
                    secondaryTextColor: secondaryTextColor,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),

                  // Phone Number
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    fieldBgColor: fieldBgColor,
                    fieldBorderColor: fieldBorderColor,
                    secondaryTextColor: secondaryTextColor,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth
                  _buildTextField(
                    controller: _dateOfBirthController,
                    label: 'Date of Birth (DD/MM/YYYY)',
                    icon: Icons.calendar_today_outlined,
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    fieldBgColor: fieldBgColor,
                    fieldBorderColor: fieldBorderColor,
                    secondaryTextColor: secondaryTextColor,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        _dateOfBirthController.text =
                            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Gender Dropdown
                  Text(
                    'Gender',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: fieldBorderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButton<String>(
                      value: _selectedGender,
                      hint: Text(
                        'Select your gender',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _genders
                          .map((gender) => DropdownMenuItem(
                                value: gender,
                                child: Text(gender),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedGender = value);
                      },
                      dropdownColor: fieldBgColor,
                      style: TextStyle(color: textColor),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Home Address
                  _buildTextField(
                    controller: _addressController,
                    label: 'Home Address',
                    icon: Icons.location_on_outlined,
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    fieldBgColor: fieldBgColor,
                    fieldBorderColor: fieldBorderColor,
                    secondaryTextColor: secondaryTextColor,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C42),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey.withValues(alpha: 0.5),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDarkMode,
    required Color textColor,
    required Color fieldBgColor,
    required Color fieldBorderColor,
    required Color secondaryTextColor,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: secondaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onTap: onTap,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(color: secondaryTextColor),
            prefixIcon: Icon(icon, color: secondaryTextColor),
            filled: true,
            fillColor: fieldBgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: fieldBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: fieldBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFFF8C42),
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: fieldBorderColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
