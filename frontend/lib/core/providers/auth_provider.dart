import 'package:flutter/material.dart';

enum UserRoleType { farmer, fieldAgent, buyer }

class AuthProvider extends ChangeNotifier {
  UserRoleType _currentRole = UserRoleType.farmer;
  String _selectedLanguage = 'hi'; // Default Hindi/Marathi/English
  String _userName = 'Ramesh Patil';
  String _userPhone = '9876543210';
  String _userVillage = 'Dindori, Nashik';
  String _userState = 'Maharashtra';
  String _activeCrop = 'Cotton (Bt-II)';
  double _farmAcres = 12.5;
  bool _isLoggedIn = true;
  bool _isDarkMode = false;

  UserRoleType get currentRole => _currentRole;
  String get selectedLanguage => _selectedLanguage;
  String get userName => _userName;
  String get userPhone => _userPhone;
  String get userVillage => _userVillage;
  String get userState => _userState;
  String get activeCrop => _activeCrop;
  double get farmAcres => _farmAcres;
  bool get isLoggedIn => _isLoggedIn;
  bool get isDarkMode => _isDarkMode;

  String get roleName {
    switch (_currentRole) {
      case UserRoleType.farmer:
        return 'Farmer / Grower';
      case UserRoleType.fieldAgent:
        return 'Field Agent / Agronomist';
      case UserRoleType.buyer:
        return 'Buyer / Input Partner';
    }
  }

  void loginFarmer({
    required String name,
    required String phone,
    required String village,
    required String state,
    required String crop,
    required double acres,
  }) {
    _userName = name;
    _userPhone = phone;
    _userVillage = village;
    _userState = state;
    _activeCrop = crop;
    _farmAcres = acres;
    _currentRole = UserRoleType.farmer;
    _isLoggedIn = true;
    notifyListeners();
  }

  void signUpFarmer({
    required String name,
    required String phone,
    required String village,
    required String state,
    required String crop,
    required double acres,
  }) {
    loginFarmer(
      name: name,
      phone: phone,
      village: village,
      state: state,
      crop: crop,
      acres: acres,
    );
  }

  void switchRole(UserRoleType role) {
    _currentRole = role;
    if (role == UserRoleType.farmer) {
      _userName = 'Ramesh Patil';
      _userPhone = '9876543210';
      _userVillage = 'Dindori, Nashik';
      _userState = 'Maharashtra';
      _activeCrop = 'Cotton (Bt-II)';
    } else if (role == UserRoleType.fieldAgent) {
      _userName = 'Dr. Anita Deshmukh';
      _userPhone = '9822334455';
      _userVillage = 'Nashik Agronomy Center';
      _userState = 'Maharashtra';
    } else {
      _userName = 'ITC Procurement Team';
      _userPhone = '9811223344';
      _userVillage = 'Mumbai Agri-Exchange';
      _userState = 'Maharashtra';
    }
    notifyListeners();
  }

  void setLanguage(String lang) {
    _selectedLanguage = lang;
    notifyListeners();
  }

  void updateFarmerProfile({
    String? name,
    String? phone,
    String? village,
    String? state,
    String? crop,
  }) {
    if (name != null && name.isNotEmpty) _userName = name;
    if (phone != null && phone.isNotEmpty) _userPhone = phone;
    if (village != null && village.isNotEmpty) _userVillage = village;
    if (state != null && state.isNotEmpty) _userState = state;
    if (crop != null && crop.isNotEmpty) _activeCrop = crop;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}
