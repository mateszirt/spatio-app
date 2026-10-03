import 'package:flutter/material.dart';

/// A furniture category shown as a tab in the catalog (and used for color coding on the canvas).
class FurnitureCategory {
  /// Stable key persisted in `Furniture_Item.category`.
  final String key;
  final String label;
  final IconData icon;
  final String emoji;
  final Color color;

  const FurnitureCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.emoji,
    required this.color,
  });
}

/// A placeable furniture / appliance type with its default footprint (canvas px, unrotated).
class FurnitureType {
  /// Display name persisted in `Furniture_Item.name`.
  final String name;
  final String category;
  final IconData icon;
  final String emoji;
  final double width;
  final double height;

  /// Material style hint: 'wood', 'fabric', 'porcelain', 'appliance', 'metal', 'plant', 'structure'
  final String material;

  /// Legacy / alternative names that resolve to this type (keeps old data rendering correctly).
  final List<String> aliases;

  const FurnitureType({
    required this.name,
    required this.category,
    required this.icon,
    required this.emoji,
    required this.width,
    required this.height,
    this.material = 'wood',
    this.aliases = const [],
  });

  bool get isStairs => category == 'stairs';
}

/// Central, single source of truth for every furniture type, its icon, emoji, color and size.
class FurnitureCatalog {
  FurnitureCatalog._();

  static const List<FurnitureCategory> categories = [
    FurnitureCategory(
      key: 'living_room',
      label: 'Living Room',
      icon: Icons.weekend_rounded,
      emoji: '🛋️',
      color: Color(0xFF7C3AED), // Vibrant Purple
    ),
    FurnitureCategory(
      key: 'bedroom',
      label: 'Bedroom',
      icon: Icons.king_bed_rounded,
      emoji: '🛏️',
      color: Color(0xFF4F46E5), // Indigo
    ),
    FurnitureCategory(
      key: 'kitchen',
      label: 'Kitchen',
      icon: Icons.kitchen_rounded,
      emoji: '🍳',
      color: Color(0xFFEA580C), // Orange
    ),
    FurnitureCategory(
      key: 'bathroom',
      label: 'Bathroom',
      icon: Icons.bathtub_rounded,
      emoji: '🛁',
      color: Color(0xFF0891B2), // Cyan
    ),
    FurnitureCategory(
      key: 'dining',
      label: 'Dining',
      icon: Icons.table_restaurant_rounded,
      emoji: '🍽️',
      color: Color(0xFFB45309), // Warm Amber
    ),
    FurnitureCategory(
      key: 'office',
      label: 'Office & Work',
      icon: Icons.desktop_windows_rounded,
      emoji: '🖥️',
      color: Color(0xFF2563EB), // Royal Blue
    ),
    FurnitureCategory(
      key: 'kids',
      label: 'Kids & Play',
      icon: Icons.smart_toy_rounded,
      emoji: '🧸',
      color: Color(0xFFEC4899), // Pink
    ),
    FurnitureCategory(
      key: 'laundry',
      label: 'Laundry & Clean',
      icon: Icons.local_laundry_service_rounded,
      emoji: '🧺',
      color: Color(0xFF0D9488), // Teal
    ),
    FurnitureCategory(
      key: 'utility',
      label: 'Utility & Gym',
      icon: Icons.fitness_center_rounded,
      emoji: '⚙️',
      color: Color(0xFF475569), // Slate
    ),
    FurnitureCategory(
      key: 'outdoor',
      label: 'Outdoor & Patio',
      icon: Icons.deck_rounded,
      emoji: '🌿',
      color: Color(0xFF16A34A), // Emerald Green
    ),
    FurnitureCategory(
      key: 'stairs',
      label: 'Stairs',
      icon: Icons.stairs_rounded,
      emoji: '🪜',
      color: Color(0xFFE11D48), // Rose
    ),
  ];

  static const List<FurnitureType> items = [
    // -------------------------------------------------------------------------
    // 1. LIVING ROOM
    // -------------------------------------------------------------------------
    FurnitureType(
      name: 'Sofa',
      category: 'living_room',
      icon: Icons.weekend_rounded,
      emoji: '🛋️',
      width: 140,
      height: 65,
      material: 'fabric',
      aliases: ['Kanapé', 'Couch'],
    ),
    FurnitureType(
      name: 'L-Shaped Couch',
      category: 'living_room',
      icon: Icons.airline_seat_recline_extra_rounded,
      emoji: '🛋️',
      width: 170,
      height: 120,
      material: 'fabric',
      aliases: ['Corner Sofa', 'Sarokkanapé'],
    ),
    FurnitureType(
      name: 'Armchair',
      category: 'living_room',
      icon: Icons.chair_rounded,
      emoji: '🪑',
      width: 65,
      height: 65,
      material: 'fabric',
      aliases: ['Fotel'],
    ),
    FurnitureType(
      name: 'Coffee Table',
      category: 'living_room',
      icon: Icons.table_bar_rounded,
      emoji: '☕',
      width: 80,
      height: 50,
      material: 'wood',
      aliases: ['Dohányzóasztal'],
    ),
    FurnitureType(
      name: 'TV Stand',
      category: 'living_room',
      icon: Icons.tv_rounded,
      emoji: '📺',
      width: 120,
      height: 38,
      material: 'wood',
      aliases: ['TV Console', 'TV állvány'],
    ),
    FurnitureType(
      name: 'Bookshelf',
      category: 'living_room',
      icon: Icons.shelves,
      emoji: '📚',
      width: 90,
      height: 32,
      material: 'wood',
      aliases: ['Könyvespolc', 'Bookcase'],
    ),
    FurnitureType(
      name: 'Fireplace',
      category: 'living_room',
      icon: Icons.fireplace_rounded,
      emoji: '🔥',
      width: 95,
      height: 36,
      material: 'stone',
      aliases: ['Kandalló'],
    ),
    FurnitureType(
      name: 'Piano',
      category: 'living_room',
      icon: Icons.piano_rounded,
      emoji: '🎹',
      width: 120,
      height: 55,
      material: 'wood',
      aliases: ['Zongora', 'Grand Piano'],
    ),
    FurnitureType(
      name: 'Floor Lamp',
      category: 'living_room',
      icon: Icons.light_rounded,
      emoji: '💡',
      width: 35,
      height: 35,
      material: 'metal',
      aliases: ['Állólámpa'],
    ),

    // -------------------------------------------------------------------------
    // 2. BEDROOM
    // -------------------------------------------------------------------------
    FurnitureType(
      name: 'Double Bed',
      category: 'bedroom',
      icon: Icons.king_bed_rounded,
      emoji: '🛏️',
      width: 115,
      height: 140,
      material: 'wood',
      aliases: ['Bed', 'Franciaágy', 'King Bed'],
    ),
    FurnitureType(
      name: 'Single Bed',
      category: 'bedroom',
      icon: Icons.single_bed_rounded,
      emoji: '🛌',
      width: 70,
      height: 135,
      material: 'wood',
      aliases: ['Egyszemélyes ágy'],
    ),
    FurnitureType(
      name: 'Bunk Bed',
      category: 'bedroom',
      icon: Icons.bedroom_child_rounded,
      emoji: '🛏️',
      width: 75,
      height: 140,
      material: 'wood',
      aliases: ['Emeletes ágy'],
    ),
    FurnitureType(
      name: 'Wardrobe',
      category: 'bedroom',
      icon: Icons.door_sliding_rounded,
      emoji: '🚪',
      width: 110,
      height: 45,
      material: 'wood',
      aliases: ['Szekrény', 'Closet'],
    ),
    FurnitureType(
      name: 'Dresser',
      category: 'bedroom',
      icon: Icons.inventory_2_rounded,
      emoji: '🗄️',
      width: 85,
      height: 42,
      material: 'wood',
      aliases: ['Komód'],
    ),
    FurnitureType(
      name: 'Nightstand',
      category: 'bedroom',
      icon: Icons.table_restaurant_outlined,
      emoji: '🕰️',
      width: 40,
      height: 38,
      material: 'wood',
      aliases: ['Éjjeliszekrény', 'Bedside Table'],
    ),
    FurnitureType(
      name: 'Vanity Desk',
      category: 'bedroom',
      icon: Icons.face_retouching_natural_rounded,
      emoji: '💄',
      width: 85,
      height: 45,
      material: 'wood',
      aliases: ['Fésülködőasztal', 'Make-up Table'],
    ),

    // -------------------------------------------------------------------------
    // 3. KITCHEN
    // -------------------------------------------------------------------------
    FurnitureType(
      name: 'Fridge',
      category: 'kitchen',
      icon: Icons.kitchen_rounded,
      emoji: '🧊',
      width: 60,
      height: 65,
      material: 'appliance',
      aliases: ['Hűtő', 'Refrigerator', 'Freezer'],
    ),
    FurnitureType(
      name: 'Double Door Fridge',
      category: 'kitchen',
      icon: Icons.kitchen_rounded,
      emoji: '🧊',
      width: 85,
      height: 68,
      material: 'appliance',
      aliases: ['Side-by-side Fridge', 'Amerikai hűtő'],
    ),
    FurnitureType(
      name: 'Stove & Oven',
      category: 'kitchen',
      icon: Icons.soup_kitchen_rounded,
      emoji: '🍳',
      width: 60,
      height: 60,
      material: 'appliance',
      aliases: ['Stove', 'Tűzhely', 'Oven', 'Sütő'],
    ),
    FurnitureType(
      name: 'Kitchen Sink',
      category: 'kitchen',
      icon: Icons.water_damage_rounded,
      emoji: '🚰',
      width: 80,
      height: 50,
      material: 'porcelain',
      aliases: ['Sink', 'Mosogató'],
    ),
    FurnitureType(
      name: 'Kitchen Counter',
      category: 'kitchen',
      icon: Icons.countertops_rounded,
      emoji: '🍱',
      width: 110,
      height: 55,
      material: 'stone',
      aliases: ['Konyhapult', 'Countertop'],
    ),
    FurnitureType(
      name: 'Kitchen Island',
      category: 'kitchen',
      icon: Icons.table_bar_rounded,
      emoji: '🏝️',
      width: 120,
      height: 70,
      material: 'stone',
      aliases: ['Konyhasziget'],
    ),
    FurnitureType(
      name: 'Dishwasher',
      category: 'kitchen',
      icon: Icons.flatware_rounded,
      emoji: '🍽️',
      width: 60,
      height: 60,
      material: 'appliance',
      aliases: ['Mosogatógép'],
    ),
    FurnitureType(
      name: 'Microwave',
      category: 'kitchen',
      icon: Icons.microwave_rounded,
      emoji: '🍿',
      width: 45,
      height: 35,
      material: 'appliance',
      aliases: ['Mikró'],
    ),
    FurnitureType(
      name: 'Coffee Machine',
      category: 'kitchen',
      icon: Icons.coffee_maker_rounded,
      emoji: '☕',
      width: 32,
      height: 32,
      material: 'appliance',
      aliases: ['Kávéfőző'],
    ),
    FurnitureType(
      name: 'Pantry Cupboard',
      category: 'kitchen',
      icon: Icons.inventory_rounded,
      emoji: '🥫',
      width: 75,
      height: 48,
      material: 'wood',
      aliases: ['Kamraszekrény'],
    ),

    // -------------------------------------------------------------------------
    // 4. BATHROOM
    // -------------------------------------------------------------------------
    FurnitureType(
      name: 'Toilet',
      category: 'bathroom',
      icon: Icons.wc_rounded,
      emoji: '🚽',
      width: 42,
      height: 65,
      material: 'porcelain',
      aliases: ['WC', 'Vécé'],
    ),
    FurnitureType(
      name: 'Shower',
      category: 'bathroom',
      icon: Icons.shower_rounded,
      emoji: '🚿',
      width: 80,
      height: 80,
      material: 'porcelain',
      aliases: ['Zuhanyzó', 'Zuhanyfülke'],
    ),
    FurnitureType(
      name: 'Bathtub',
      category: 'bathroom',
      icon: Icons.bathtub_rounded,
      emoji: '🛁',
      width: 75,
      height: 150,
      material: 'porcelain',
      aliases: ['Kád', 'Fürdőkád'],
    ),
    FurnitureType(
      name: 'Jacuzzi Tub',
      category: 'bathroom',
      icon: Icons.hot_tub_rounded,
      emoji: '🫧',
      width: 125,
      height: 125,
      material: 'porcelain',
      aliases: ['Pezsgőfürdő'],
    ),
    FurnitureType(
      name: 'Washbasin',
      category: 'bathroom',
      icon: Icons.clean_hands_rounded,
      emoji: '🚰',
      width: 55,
      height: 45,
      material: 'porcelain',
      aliases: ['Mosdó', 'Kézmosó', 'Vanity Sink'],
    ),
    FurnitureType(
      name: 'Double Vanity',
      category: 'bathroom',
      icon: Icons.dry_cleaning_rounded,
      emoji: '🪞',
      width: 120,
      height: 50,
      material: 'porcelain',
      aliases: ['Dupla mosdó'],
    ),
    FurnitureType(
      name: 'Towel Warmer',
      category: 'bathroom',
      icon: Icons.thermostat_rounded,
      emoji: '🧖',
      width: 50,
      height: 18,
      material: 'metal',
      aliases: ['Törölközőszárító'],
    ),

    // -------------------------------------------------------------------------
    // 5. DINING
    // -------------------------------------------------------------------------
    FurnitureType(
      name: 'Dining Table',
      category: 'dining',
      icon: Icons.table_restaurant_rounded,
      emoji: '🍽️',
      width: 130,
      height: 80,
      material: 'wood',
      aliases: ['Table', 'Étkezőasztal'],
    ),
    FurnitureType(
      name: 'Round Dining Table',
      category: 'dining',
      icon: Icons.panorama_fish_eye_rounded,
      emoji: '🥘',
      width: 90,
      height: 90,
      material: 'wood',
      aliases: ['Kerek étkezőasztal'],
    ),
    FurnitureType(
      name: 'Dining Chair',
      category: 'dining',
      icon: Icons.chair_alt_rounded,
      emoji: '🪑',
      width: 42,
      height: 42,
      material: 'wood',
      aliases: ['Szék', 'Étkezőszék'],
    ),
    FurnitureType(
      name: 'Bar Stool',
      category: 'dining',
      icon: Icons.event_seat_rounded,
      emoji: '🍸',
      width: 35,
      height: 35,
      material: 'metal',
      aliases: ['Bárszék'],
    ),
    FurnitureType(
      name: 'Sideboard Buffet',
      category: 'dining',
      icon: Icons.inventory_2_rounded,
      emoji: '🍷',
      width: 115,
      height: 42,
      material: 'wood',
      aliases: ['Tálalószekrény', 'Sideboard'],
    ),

    // -------------------------------------------------------------------------
    // 6. OFFICE & WORK
    // -------------------------------------------------------------------------
    FurnitureType(
      name: 'Desk',
      category: 'office',
      icon: Icons.desk_rounded,
      emoji: '🖥️',
      width: 120,
      height: 60,
      material: 'wood',
      aliases: ['Íróasztal', 'Computer Desk'],
    ),
    FurnitureType(
      name: 'Office Chair',
      category: 'office',
      icon: Icons.chair_rounded,
      emoji: '💺',
      width: 48,
      height: 48,
      material: 'fabric',
      aliases: ['Irodai szék', 'Forgószék'],
    ),
    FurnitureType(
      name: 'Computer Setup',
      category: 'office',
      icon: Icons.computer_rounded,
      emoji: '💻',
      width: 50,
      height: 35,
      material: 'metal',
      aliases: ['PC', 'Monitor', 'Számítógép'],
    ),
    FurnitureType(
      name: 'Printer Station',
      category: 'office',
      icon: Icons.print_rounded,
      emoji: '🖨️',
      width: 45,
      height: 42,
      material: 'appliance',
      aliases: ['Nyomtató'],
    ),
    FurnitureType(
      name: 'Filing Cabinet',
      category: 'office',
      icon: Icons.folder_copy_rounded,
      emoji: '📁',
      width: 45,
      height: 52,
      material: 'metal',
      aliases: ['Iratrendező'],
    ),
    FurnitureType(
      name: 'Whiteboard',
      category: 'office',
      icon: Icons.crop_landscape_rounded,
      emoji: '📊',
      width: 100,
      height: 16,
      material: 'metal',
      aliases: ['Tábla', 'Prezentációs tábla'],
    ),

    // -------------------------------------------------------------------------
    // 7. KIDS & PLAY
    // -------------------------------------------------------------------------
    FurnitureType(
      name: 'Crib',
      category: 'kids',
      icon: Icons.crib_rounded,
      emoji: '👶',
      width: 60,
      height: 90,
      material: 'wood',
      aliases: ['Kiságy', 'Rácsos ágy'],
    ),
    FurnitureType(
      name: 'Toy Box',
      category: 'kids',
      icon: Icons.smart_toy_rounded,
      emoji: '🧸',
      width: 75,
      height: 42,
      material: 'wood',
      aliases: ['Játéktároló'],
    ),
    FurnitureType(
      name: 'Kids Study Desk',
      category: 'kids',
      icon: Icons.school_rounded,
      emoji: '🎨',
      width: 85,
      height: 50,
      material: 'wood',
      aliases: ['Gyerek tanulóasztal'],
    ),
    FurnitureType(
      name: 'Play Mat Rug',
      category: 'kids',
      icon: Icons.dashboard_rounded,
      emoji: '🧩',
      width: 100,
      height: 100,
      material: 'fabric',
      aliases: ['Játszószőnyeg'],
    ),
    FurnitureType(
      name: 'Bean Bag Chair',
      category: 'kids',
      icon: Icons.airline_seat_legroom_extra_rounded,
      emoji: '🛋️',
      width: 55,
      height: 55,
      material: 'fabric',
      aliases: ['Babzsákfotel'],
    ),

    // -------------------------------------------------------------------------
    // 8. LAUNDRY & CLEANING
    // -------------------------------------------------------------------------
    FurnitureType(
      name: 'Washing Machine',
      category: 'laundry',
      icon: Icons.local_laundry_service_rounded,
      emoji: '🧼',
      width: 60,
      height: 60,
      material: 'appliance',
      aliases: ['Washer', 'Mosógép'],
    ),
    FurnitureType(
      name: 'Dryer',
      category: 'laundry',
      icon: Icons.cyclone_rounded,
      emoji: '🌀',
      width: 60,
      height: 60,
      material: 'appliance',
      aliases: ['Szárítógép'],
    ),
    FurnitureType(
      name: 'Ironing Board',
      category: 'laundry',
      icon: Icons.iron_rounded,
      emoji: '👔',
      width: 40,
      height: 120,
      material: 'metal',
      aliases: ['Vasalódeszka'],
    ),
    FurnitureType(
      name: 'Laundry Basket',
      category: 'laundry',
      icon: Icons.shopping_basket_rounded,
      emoji: '🧺',
      width: 42,
      height: 42,
      material: 'fabric',
      aliases: ['Szennyeskosár'],
    ),
    FurnitureType(
      name: 'Cleaning Cabinet',
      category: 'laundry',
      icon: Icons.cleaning_services_rounded,
      emoji: '🧹',
      width: 65,
      height: 45,
      material: 'wood',
      aliases: ['Takarítószekrény'],
    ),

    // -------------------------------------------------------------------------
    // 9. UTILITY & CLIMATE & GYM
    // -------------------------------------------------------------------------
    FurnitureType(
      name: 'Air Conditioner',
      category: 'utility',
      icon: Icons.ac_unit_rounded,
      emoji: '❄️',
      width: 80,
      height: 24,
      material: 'appliance',
      aliases: ['Klíma', 'AC'],
    ),
    FurnitureType(
      name: 'Radiator',
      category: 'utility',
      icon: Icons.heat_pump_rounded,
      emoji: '♨️',
      width: 85,
      height: 16,
      material: 'metal',
      aliases: ['Radiátor', 'Heater'],
    ),
    FurnitureType(
      name: 'Water Heater',
      category: 'utility',
      icon: Icons.water_drop_rounded,
      emoji: '💧',
      width: 50,
      height: 50,
      material: 'metal',
      aliases: ['Bojler', 'Kazán', 'Boiler'],
    ),
    FurnitureType(
      name: 'Storage Rack',
      category: 'utility',
      icon: Icons.storage_rounded,
      emoji: '📦',
      width: 90,
      height: 42,
      material: 'metal',
      aliases: ['Salgó polc', 'Tárolópolc'],
    ),
    FurnitureType(
      name: 'Indoor Plant',
      category: 'utility',
      icon: Icons.local_florist_rounded,
      emoji: '🪴',
      width: 40,
      height: 40,
      material: 'plant',
      aliases: ['Plant', 'Szobanövény'],
    ),
    FurnitureType(
      name: 'Pet Bed',
      category: 'utility',
      icon: Icons.pets_rounded,
      emoji: '🐾',
      width: 60,
      height: 45,
      material: 'fabric',
      aliases: ['Kutyafekhely', 'Cicakosár'],
    ),
    FurnitureType(
      name: 'Treadmill',
      category: 'utility',
      icon: Icons.directions_run_rounded,
      emoji: '🏃',
      width: 65,
      height: 130,
      material: 'metal',
      aliases: ['Futópad'],
    ),
    FurnitureType(
      name: 'Exercise Bike',
      category: 'utility',
      icon: Icons.directions_bike_rounded,
      emoji: '🚴',
      width: 55,
      height: 95,
      material: 'metal',
      aliases: ['Szobakerékpár'],
    ),
    FurnitureType(
      name: 'Trash Bin',
      category: 'utility',
      icon: Icons.delete_outline_rounded,
      emoji: '🗑️',
      width: 35,
      height: 35,
      material: 'metal',
      aliases: ['Szemetes'],
    ),

    // -------------------------------------------------------------------------
    // 10. OUTDOOR & PATIO
    // -------------------------------------------------------------------------
    FurnitureType(
      name: 'BBQ Grill',
      category: 'outdoor',
      icon: Icons.outdoor_grill_rounded,
      emoji: '🥩',
      width: 65,
      height: 50,
      material: 'metal',
      aliases: ['Grill', 'Kerti grill'],
    ),
    FurnitureType(
      name: 'Garden Bench',
      category: 'outdoor',
      icon: Icons.deck_rounded,
      emoji: '🪵',
      width: 110,
      height: 42,
      material: 'wood',
      aliases: ['Kerti pad', 'Bench'],
    ),
    FurnitureType(
      name: 'Sun Lounger',
      category: 'outdoor',
      icon: Icons.beach_access_rounded,
      emoji: '⛱️',
      width: 60,
      height: 140,
      material: 'fabric',
      aliases: ['Napágy'],
    ),
    FurnitureType(
      name: 'Outdoor Patio Set',
      category: 'outdoor',
      icon: Icons.yard_rounded,
      emoji: '🏡',
      width: 120,
      height: 120,
      material: 'wood',
      aliases: ['Kerti bútor', 'Patio Set'],
    ),
    FurnitureType(
      name: 'Car',
      category: 'outdoor',
      icon: Icons.directions_car_rounded,
      emoji: '🚗',
      width: 95,
      height: 190,
      material: 'metal',
      aliases: ['Autó', 'Garázs autó'],
    ),

    // -------------------------------------------------------------------------
    // 11. STRUCTURE
    // -------------------------------------------------------------------------
    FurnitureType(
      name: 'Stairs',
      category: 'stairs',
      icon: Icons.stairs_rounded,
      emoji: '🪜',
      width: 75,
      height: 120,
      material: 'structure',
      aliases: ['Lépcső', 'Staircase', 'Straight Stairs'],
    ),
  ];

  static const FurnitureCategory _fallbackCategory = FurnitureCategory(
    key: 'utility',
    label: 'Utility',
    icon: Icons.home_repair_service_rounded,
    emoji: '📦',
    color: Color(0xFF475569),
  );

  /// Categories used in older data mapped onto the current ones.
  static const Map<String, String> _legacyCategories = {
    'appliance': 'laundry',
  };

  static List<FurnitureType> itemsIn(String categoryKey) {
    if (categoryKey == 'all') return items;
    return items.where((i) => i.category == categoryKey).toList();
  }

  static FurnitureCategory categoryOf(String? key) {
    final mapped = _legacyCategories[key] ?? key;
    for (final c in categories) {
      if (c.key == mapped) return c;
    }
    return _fallbackCategory;
  }

  /// Resolves a stored name (and legacy category) to its catalog type; `null` if unknown.
  static FurnitureType? byName(String? name) {
    if (name == null) return null;
    final lower = name.trim().toLowerCase();
    for (final t in items) {
      if (t.name.toLowerCase() == lower) return t;
      for (final a in t.aliases) {
        if (a.toLowerCase() == lower) return t;
      }
    }
    return null;
  }

  static IconData iconFor(String? name, String? category) {
    final type = byName(name);
    if (type != null) return type.icon;
    return categoryOf(category).icon;
  }

  static String emojiFor(String? name, String? category) {
    final type = byName(name);
    if (type != null) return type.emoji;
    return categoryOf(category).emoji;
  }

  static Color colorFor(String? name, String? category) {
    final type = byName(name);
    return categoryOf(type?.category ?? category).color;
  }

  static bool isStairs(String? name, String? category) =>
      category == 'stairs' || (byName(name)?.isStairs ?? false);
}
