import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/providers/auth_provider.dart';
import '../core/localization/app_translations.dart';
import '../widgets/custom_bottom_nav.dart';

class AgriStoreScreen extends StatefulWidget {
  final String? initialSearch;
  final String? initialCategory;
  final String? initialCrop;

  const AgriStoreScreen({
    super.key,
    this.initialSearch,
    this.initialCategory,
    this.initialCrop,
  });

  @override
  State<AgriStoreScreen> createState() => _AgriStoreScreenState();
}

class _AgriStoreScreenState extends State<AgriStoreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "All";
  String _selectedCrop = "All";
  String _searchQuery = "";
  bool _initializedArgs = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchController.text = widget.initialSearch!;
      _searchQuery = widget.initialSearch!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialCrop != null) {
      _selectedCrop = widget.initialCrop!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      _initializedArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        if (args['search'] != null && _searchQuery.isEmpty) {
          final s = args['search'].toString();
          _searchController.text = s;
          setState(() {
            _searchQuery = s;
          });
        }
        if (args['category'] != null) {
          setState(() {
            _selectedCategory = args['category'].toString();
          });
        }
        if (args['crop'] != null) {
          setState(() {
            _selectedCrop = args['crop'].toString();
          });
        }
      } else if (args is String && _searchQuery.isEmpty) {
        _searchController.text = args;
        setState(() {
          _searchQuery = args;
        });
      }
    }
  }

  final List<Map<String, dynamic>> _catalogProducts = [
    {
      "id": "PROD-001",
      "name": "Tilt 25% EC (Propiconazole)",
      "brand": "Syngenta India Ltd.",
      "category": "Fungicide",
      "category_key": "cat_fungicide",
      "crop": "Wheat",
      "crop_key": "Wheat",
      "rating": 4.9,
      "price": 540,
      "unit": "250 ml Bottle (1.25 Acre Pack)",
      "image_url": "https://images.unsplash.com/photo-1592841200221-a6898f307baa?w=400&auto=format&fit=crop&q=60",
      "dosage": "200 ml / Acre in 200L clean water",
      "target_pest": "Yellow Rust / Stripe Rust & Karnal Bunt",
      "dealer_name": "Kisan Agri Seva Kendra & Fertilizer Depot",
      "dealer_phone": "9823012345",
      "dealer_address": "Main Market Yard, Dindori Road, Nashik",
      "distance_km": "2.4 km away",
      "in_stock": true,
      "qr_verified": true,
    },
    {
      "id": "PROD-002",
      "name": "Bio-Neem Power 10,000 PPM",
      "brand": "Pramaan Eco Bio-Agri",
      "category": "Organic",
      "category_key": "cat_organic",
      "crop": "Cotton",
      "crop_key": "Cotton",
      "rating": 4.8,
      "price": 380,
      "unit": "500 ml Bottle (1.25 Acre Pack)",
      "image_url": "https://images.unsplash.com/photo-1530836369250-ef72a3f5cda8?w=400&auto=format&fit=crop&q=60",
      "dosage": "400 ml / Acre in 200L clean water",
      "target_pest": "Whitefly, Aphids & Sucking Pests",
      "dealer_name": "Maharashtra Shetkari Vikas Kendra",
      "dealer_phone": "9890123456",
      "dealer_address": "Near APMC Market, Niphad, Nashik",
      "distance_km": "4.1 km away",
      "in_stock": true,
      "qr_verified": true,
    },
    {
      "id": "PROD-003",
      "name": "PBW 826 Certified Wheat Seeds",
      "brand": "Punjab Agricultural University (PAU)",
      "category": "Seeds",
      "category_key": "cat_seeds",
      "crop": "Wheat",
      "crop_key": "Wheat",
      "rating": 5.0,
      "price": 1450,
      "unit": "40 kg Bag (1 Acre Sowing)",
      "image_url": "https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=400&auto=format&fit=crop&q=60",
      "dosage": "40 kg / Acre seed rate",
      "target_pest": "High yield & Stripe Rust resistant",
      "dealer_name": "IFFCO Kisan Seva Kendra & Seed Bank",
      "dealer_phone": "9814012345",
      "dealer_address": "GT Road, Grain Market, Ludhiana / Bathinda",
      "distance_km": "3.5 km away",
      "in_stock": true,
      "qr_verified": true,
    },
    {
      "id": "PROD-004",
      "name": "Validamycin 3% L (Sheath Blight Cure)",
      "brand": "Sumitomo Chemical India",
      "category": "Fungicide",
      "category_key": "cat_fungicide",
      "crop": "Rice",
      "crop_key": "Rice",
      "rating": 4.8,
      "price": 490,
      "unit": "500 ml Bottle (1 Acre Pack)",
      "image_url": "https://images.unsplash.com/photo-1536657464919-892534f60d6e?w=400&auto=format&fit=crop&q=60",
      "dosage": "500 ml / Acre in 200L clean water",
      "target_pest": "Rice Sheath Blight & Stem Rot",
      "dealer_name": "Paddy Krishi Clinic & Input Center",
      "dealer_phone": "9876543211",
      "dealer_address": "Mandi Gate, Sangrur / Karnal",
      "distance_km": "5.0 km away",
      "in_stock": true,
      "qr_verified": true,
    },
    {
      "id": "PROD-005",
      "name": "Zinc Sulphate Heptahydrate (21% Zn)",
      "brand": "IFFCO Kisan Nutrients",
      "category": "Fertilizer",
      "category_key": "cat_fertilizer",
      "crop": "Wheat",
      "crop_key": "Wheat",
      "rating": 4.7,
      "price": 420,
      "unit": "10 kg Bag (1 Acre Application)",
      "image_url": "https://images.unsplash.com/photo-1585314062340-f1a5a7c9328d?w=400&auto=format&fit=crop&q=60",
      "dosage": "10 kg / Acre basal or 1 kg foliar spray",
      "target_pest": "Cures Khaira disease & Zinc deficiency",
      "dealer_name": "IFFCO Cooperative Society Store",
      "dealer_phone": "9822098765",
      "dealer_address": "Taluka Sangh, Chandwad, Nashik",
      "distance_km": "1.8 km away",
      "in_stock": true,
      "qr_verified": true,
    },
    {
      "id": "PROD-006",
      "name": "Pegasus (Diafenthiuron 50% WP)",
      "brand": "Syngenta India Ltd.",
      "category": "Insecticide",
      "category_key": "cat_insecticide",
      "crop": "Chilli",
      "crop_key": "Chilli",
      "rating": 4.9,
      "price": 720,
      "unit": "250 g Pack (1 Acre Spray)",
      "image_url": "https://images.unsplash.com/photo-1588252303782-cb80119abd6d?w=400&auto=format&fit=crop&q=60",
      "dosage": "250 g in 200L water per Acre",
      "target_pest": "Chilli Murda (Leaf Curl), Mites & Thrips",
      "dealer_name": "Shree Ganesh Krishi Seva Kendra",
      "dealer_phone": "9823456789",
      "dealer_address": "Panchavati Market Yard, Nashik",
      "distance_km": "3.0 km away",
      "in_stock": true,
      "qr_verified": true,
    },
    {
      "id": "PROD-007",
      "name": "Trichoderma Viride Bio-Fungicide",
      "brand": "National Bio-Fertilizers & Bio-Pesticides",
      "category": "Organic",
      "category_key": "cat_organic",
      "crop": "Tomato",
      "crop_key": "Tomato",
      "rating": 4.9,
      "price": 260,
      "unit": "1 kg Pack (Seed & Soil Treatment)",
      "image_url": "https://images.unsplash.com/photo-1592841200221-a6898f307baa?w=400&auto=format&fit=crop&q=60",
      "dosage": "1 kg / Acre with FYM or 5 g / kg seed",
      "target_pest": "Root Rot, Damping Off, Wilt & Blight",
      "dealer_name": "Krishi Vigyan Kendra (KVK) Input Store",
      "dealer_phone": "9823112233",
      "dealer_address": "KVK Campus, YCMOU Road, Nashik",
      "distance_km": "6.2 km away",
      "in_stock": true,
      "qr_verified": true,
    },
    {
      "id": "PROD-008",
      "name": "16L 12V Battery Knapsack Sprayer",
      "brand": "Aspee Agri Equipment",
      "category": "Equipment",
      "category_key": "cat_equipment",
      "crop": "All",
      "crop_key": "All",
      "rating": 4.8,
      "price": 2450,
      "unit": "Complete Unit with 4 Brass Nozzles",
      "image_url": "https://images.unsplash.com/photo-1589923188900-85dae523342b?w=400&auto=format&fit=crop&q=60",
      "dosage": "Delivers uniform 0.3 - 0.4 MPa spray pressure",
      "target_pest": "Precision foliar spray & zero manual pumping",
      "dealer_name": "Kisan Machinery & Tools Emporium",
      "dealer_phone": "9823998877",
      "dealer_address": "Old Agra Road, Nashik",
      "distance_km": "2.8 km away",
      "in_stock": true,
      "qr_verified": true,
    }
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _catalogProducts.where((p) {
      final matchesCategory = _selectedCategory == "All" || p['category'] == _selectedCategory;
      final matchesCrop = _selectedCrop == "All" || p['crop'] == _selectedCrop || p['crop'] == "All";
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          p['name'].toString().toLowerCase().contains(q) ||
          p['brand'].toString().toLowerCase().contains(q) ||
          p['crop'].toString().toLowerCase().contains(q) ||
          p['target_pest'].toString().toLowerCase().contains(q) ||
          p['dealer_name'].toString().toLowerCase().contains(q);

      return matchesCategory && matchesCrop && matchesSearch;
    }).toList();
  }

  void _callDealer(String phone) async {
    final uri = Uri.parse("tel:$phone");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  void _showProductDetailsModal(Map<String, dynamic> prod, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with Certified Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF047857)),
                            const SizedBox(width: 4),
                            Text(
                              AppTranslations.tr(lang, "certified_genuine", "100% Genuine & Batch Certified"),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "⭐ ${prod['rating']}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD97706)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Product Title & Brand
                  Text(
                    prod['name'],
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "By ${prod['brand']}",
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),

                  // Price Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "MRP / Price",
                              style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                            ),
                            Text(
                              "₹${prod['price']}",
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                        Text(
                          prod['unit'],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Technical Specifications
                  const Text(
                    "Agronomic Specifications",
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildSpecRow("🌾 Suitable Crop", prod['crop']),
                        const Divider(height: 14),
                        _buildSpecRow("🧪 Recommended Dose", prod['dosage']),
                        const Divider(height: 14),
                        _buildSpecRow("🎯 Target Control", prod['target_pest']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Authorized Dealer Card
                  const Text(
                    "Authorized Local Dealer",
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD1FAE5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFECFDF5),
                          child: Icon(Icons.storefront_rounded, color: Color(0xFF047857), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prod['dealer_name'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "📍 ${prod['dealer_address']}",
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "🛵 ${prod['distance_km']} • In Stock",
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                      label: Text(
                        "${AppTranslations.tr(lang, "call_dealer", "Call Dealer")} (${prod['dealer_phone']})",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _callDealer(prod['dealer_phone']);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final lang = auth.selectedLanguage;
    final products = _filteredProducts;

    final categories = [
      {"label": "All", "name": AppTranslations.tr(lang, "filter_all", "All")},
      {"label": "Fungicide", "name": AppTranslations.tr(lang, "cat_fungicide", "Fungicides")},
      {"label": "Organic", "name": AppTranslations.tr(lang, "cat_organic", "Bio & Organic")},
      {"label": "Seeds", "name": AppTranslations.tr(lang, "cat_seeds", "Seeds")},
      {"label": "Insecticide", "name": AppTranslations.tr(lang, "cat_insecticide", "Insecticides")},
      {"label": "Fertilizer", "name": AppTranslations.tr(lang, "cat_fertilizer", "Fertilizers")},
      {"label": "Equipment", "name": AppTranslations.tr(lang, "cat_equipment", "Equipment")},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.tr(lang, "agri_store_title", "Kisan Agri Store"),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            Text(
              AppTranslations.tr(lang, "store_subtitle", "Verified Seeds, Fertilizers & Crop Protection"),
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppTranslations.tr(lang, "select_language"),
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                lang.toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
              ),
            ),
            onPressed: () => AppTranslations.showLanguageSelectorModal(
              context,
              lang,
              (newLang) => auth.setLanguage(newLang),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              children: [
                // Search Input
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: AppTranslations.tr(lang, "search_store_hint", "Search seeds, fertilizers, pesticides..."),
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Category Chips Scroll
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final isSel = _selectedCategory == cat['label'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(cat['name'] as String),
                          selected: isSel,
                          selectedColor: const Color(0xFF047857),
                          backgroundColor: const Color(0xFFF8FAFC),
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? Colors.white : const Color(0xFF334155),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: isSel ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = cat['label'] as String);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 10),
                        Text(
                          AppTranslations.tr(lang, "no_products_found", "No agri-products found"),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final prod = products[index];
                      return _buildProductCard(prod, lang);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(
        currentIndex: 1, // Store Tab
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> prod, String lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Thumbnail Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: Image.network(
                      prod['image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, _, _) => Container(
                        color: const Color(0xFFECFDF5),
                        child: const Icon(Icons.science_rounded, color: Color(0xFF047857), size: 30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Verified Tag & Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "✓ ${prod['category']}",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ),
                          Text(
                            "⭐ ${prod['rating']}",
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Name
                      Text(
                        prod['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Target crop & unit
                      Text(
                        "🌾 ${prod['crop']} • ${prod['unit']}",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Price
                      Row(
                        children: [
                          Text(
                            "₹${prod['price']}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                          ),
                          const Spacer(),
                          const Text(
                            "In Stock ✓",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Dealer info banner
            Row(
              children: [
                const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${prod['dealer_name']} (${prod['distance_km']})",
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showProductDetailsModal(prod, lang),
                    child: Text(
                      AppTranslations.tr(lang, "view_all", "View Details"),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 15),
                    label: Text(
                      AppTranslations.tr(lang, "call_dealer", "Call Dealer"),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _callDealer(prod['dealer_phone']),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
