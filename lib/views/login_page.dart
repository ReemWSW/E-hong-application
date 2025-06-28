// lib/views/login_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final employeeNoController = TextEditingController();
  final passwordController = TextEditingController();
  final companyController = TextEditingController();
  final AuthController authController = Get.find();

  String? employeeNoError;
  String? passwordError;
  String? companyError;
  bool _obscureText = true;
  bool _isRegisterMode = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationsInitialized = true;
    _animationController.forward();
  }

  @override
  void dispose() {
    if (_animationsInitialized) {
      _animationController.dispose();
    }
    employeeNoController.dispose();
    passwordController.dispose();
    companyController.dispose();
    super.dispose();
  }

  bool validate() {
    setState(() {
      employeeNoError = null;
      passwordError = null;
      companyError = null;
    });

    final employeeNo = employeeNoController.text.trim();
    final password = passwordController.text.trim();
    final company = companyController.text.trim();

    bool hasError = false;

    if (employeeNo.isEmpty) {
      employeeNoError = "กรุณากรอกหมายเลขพนักงาน";
      hasError = true;
    }

    // ตรวจสอบ company เฉพาะตอนสมัคร
    if (_isRegisterMode && company.isEmpty) {
      companyError = "กรุณากรอกชื่อบริษัท";
      hasError = true;
    }

    if (password.length < 6) {
      passwordError = "รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร";
      hasError = true;
    }

    return !hasError;
  }

  void validateAndLogin() {
    if (validate()) {
      authController.login(
        employeeNo: employeeNoController.text.trim(),
        password: passwordController.text.trim(),
      );
    }
  }

  void validateAndRegister() {
    if (validate()) {
      authController.register(
        employeeNo: employeeNoController.text.trim(),
        password: passwordController.text.trim(),
        company: companyController.text.trim(),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? errorText,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          prefixIcon: Icon(icon, color: Colors.blue[600]),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[400]!, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[400]!, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey[600]),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback? onPressed,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: color.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.indigo[50]!,
              Colors.purple[50]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _animationsInitialized ? _fadeAnimation : AlwaysStoppedAnimation(1.0),
                child: SlideTransition(
                  position: _animationsInitialized ? _slideAnimation : AlwaysStoppedAnimation(Offset.zero),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 400),
                    child: Card(
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Section
                            Column(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 80,
                                  color: Colors.blue[600],
                                ),
                                SizedBox(height: 24),
                                Text(
                                  _isRegisterMode ? "ลงทะเบียนพนักงาน" : "ระบบลงเวลาทำงาน",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _isRegisterMode 
                                    ? "สร้างบัญชีพนักงานใหม่" 
                                    : "เข้าสู่ระบบเพื่อลงเวลาทำงาน",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            
                            SizedBox(height: 32),
                            
                            // Form Section
                            _buildTextField(
                              controller: employeeNoController,
                              label: "หมายเลขพนักงาน",
                              icon: Icons.badge,
                              errorText: employeeNoError,
                            ),
                            
                            // Company field - แสดงเฉพาะตอนสมัคร
                            if (_isRegisterMode)
                              _buildTextField(
                                controller: companyController,
                                label: "ชื่อบริษัท",
                                icon: Icons.business,
                                errorText: companyError,
                              ),
                            
                            _buildTextField(
                              controller: passwordController,
                              label: "รหัสผ่าน",
                              icon: Icons.lock_outline,
                              errorText: passwordError,
                              obscureText: _obscureText,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                              ),
                            ),
                            
                            SizedBox(height: 8),
                            
                            // Primary Action Button
                            Obx(() => _buildPrimaryButton(
                              text: authController.isLoading.value 
                                  ? "กำลังดำเนินการ..." 
                                  : _isRegisterMode ? "ลงทะเบียน" : "เข้าสู่ระบบ",
                              onPressed: authController.isLoading.value 
                                  ? null 
                                  : _isRegisterMode ? validateAndRegister : validateAndLogin,
                              color: _isRegisterMode ? Colors.green[600]! : Colors.blue[600]!,
                              icon: authController.isLoading.value
                                  ? Icons.hourglass_empty
                                  : _isRegisterMode ? Icons.person_add : Icons.login,
                            )),
                            
                            if (!_isRegisterMode) ...[
                              SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "เข้าสู่ระบบจะบันทึกเวลาและตำแหน่งอัตโนมัติ",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            SizedBox(height: 16),
                            
                            // Divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey[300])),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    "หรือ",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.grey[300])),
                              ],
                            ),
                            
                            SizedBox(height: 16),
                            
                            // Switch Mode Button
                                                          TextButton(
                              onPressed: () {
                                setState(() {
                                  _isRegisterMode = !_isRegisterMode;
                                  employeeNoError = null;
                                  passwordError = null;
                                  companyError = null;
                                  // ล้างค่า company เมื่อเปลี่ยนไป login mode
                                  if (!_isRegisterMode) {
                                    companyController.clear();
                                  }
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text: _isRegisterMode 
                                        ? "มีบัญชีอยู่แล้ว? " 
                                        : "ยังไม่มีบัญชี? ",
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    TextSpan(
                                      text: _isRegisterMode ? "เข้าสู่ระบบ" : "ลงทะเบียน",
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 16),
                            
                            // Footer
                            Text(
                              "โดยการใช้งานแอปนี้ คุณยอมรับ\nข้อกำหนดการใช้งานและนโยบายความเป็นส่วนตัว",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
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