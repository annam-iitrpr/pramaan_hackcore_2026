import 'package:flutter/material.dart';
import '../../models/farm_model.dart';
import '../../models/weather_model.dart';
import '../../models/product_model.dart';
import '../services/api_service.dart';

class FarmProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<Farm> _farms = [];
  Farm? _selectedFarm;
  WeatherAdvisory? _weatherAdvisory;
  List<ProductInput> _products = [];
  List<PunjabDistrict> _punjabDistricts = [];
  PunjabDistrict? _selectedDistrict;
  bool _isLoading = false;
  bool _isWeatherLoading = false;

  List<Farm> get farms => _farms;
  Farm? get selectedFarm => _selectedFarm ?? (_farms.isNotEmpty ? _farms.first : null);
  WeatherAdvisory? get weatherAdvisory => _weatherAdvisory;
  List<ProductInput> get products => _products;
  List<PunjabDistrict> get punjabDistricts => _punjabDistricts;
  PunjabDistrict? get selectedDistrict => _selectedDistrict ?? (_punjabDistricts.isNotEmpty ? _punjabDistricts.first : null);
  bool get isLoading => _isLoading;
  bool get isWeatherLoading => _isWeatherLoading;

  FarmProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    
    // Fetch Punjab districts catalog
    _punjabDistricts = await _api.fetchPunjabDistricts();
    if (_punjabDistricts.isNotEmpty) {
      _selectedDistrict = _punjabDistricts.first;
    }

    _farms = await _api.fetchFarms();
    if (_farms.isNotEmpty) {
      // Prioritize Punjab farm if available
      final punjabFarm = _farms.firstWhere(
        (f) => f.state.toLowerCase() == 'punjab',
        orElse: () => _farms.first,
      );
      _selectedFarm = punjabFarm;
      _weatherAdvisory = await _api.fetchWeatherAdvisory(
        _selectedFarm!.latitude,
        _selectedFarm!.longitude,
        district: _selectedDistrict?.name ?? 'Ludhiana',
        crop: _selectedFarm!.activeCrop,
      );
    } else {
      _weatherAdvisory = await _api.fetchDistrictWeather('Ludhiana');
    }

    _products = await _api.fetchProducts();
    _isLoading = false;
    notifyListeners();
  }

  void selectFarm(Farm farm) async {
    _selectedFarm = farm;
    _isWeatherLoading = true;
    notifyListeners();

    // Match district if in Punjab
    if (farm.state.toLowerCase() == 'punjab' && _punjabDistricts.isNotEmpty) {
      for (final d in _punjabDistricts) {
        if (farm.village.toLowerCase().contains(d.name.toLowerCase()) ||
            farm.name.toLowerCase().contains(d.name.toLowerCase())) {
          _selectedDistrict = d;
          break;
        }
      }
    }

    _weatherAdvisory = await _api.fetchWeatherAdvisory(
      farm.latitude,
      farm.longitude,
      district: _selectedDistrict?.name ?? (farm.state.toLowerCase() == 'punjab' ? 'Ludhiana' : null),
      crop: farm.activeCrop,
    );
    _isWeatherLoading = false;
    notifyListeners();
  }

  Future<void> selectPunjabDistrict(PunjabDistrict district) async {
    _selectedDistrict = district;
    _isWeatherLoading = true;
    notifyListeners();

    _weatherAdvisory = await _api.fetchWeatherAdvisory(
      district.latitude,
      district.longitude,
      district: district.name,
      crop: _selectedFarm?.activeCrop ?? (district.primaryCrops.isNotEmpty ? district.primaryCrops.first : 'Wheat (Kanak)'),
    );
    _isWeatherLoading = false;
    notifyListeners();
  }

  Future<void> refreshWeather() async {
    _isWeatherLoading = true;
    notifyListeners();

    final lat = _selectedDistrict?.latitude ?? _selectedFarm?.latitude ?? 30.9010;
    final lon = _selectedDistrict?.longitude ?? _selectedFarm?.longitude ?? 75.8573;
    final dist = _selectedDistrict?.name ?? 'Ludhiana';
    final crop = _selectedFarm?.activeCrop ?? 'Wheat (PBW 826)';

    _weatherAdvisory = await _api.fetchWeatherAdvisory(lat, lon, district: dist, crop: crop);
    _isWeatherLoading = false;
    notifyListeners();
  }
}
