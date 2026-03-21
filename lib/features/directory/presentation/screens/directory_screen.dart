import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';

class DirectoryScreen extends StatefulWidget {
  final bool isEmbedded;

  const DirectoryScreen({super.key, this.isEmbedded = false});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  int _selectedCategory = 0;
  bool _isRefreshingLocation = false;
  Position? _currentPosition;
  String _locationLabel = 'La Paz, Bolivia · Toca para actualizar';

  final List<String> _categories = [
    'Todos',
    'Salud',
    'Legal',
    'Psicológico',
    'Albergues',
  ];

  final List<_Center> _centers = const [
    _Center(
      name: 'PAIF Emergencia Línea 156',
      type: 'Legal / Psicológico / Social',
      address: 'Calle Chuquisaca, tras la Cervecería, La Paz',
      phone: '156',
      icon: Icons.phone_in_talk_rounded,
      color: Color(0xFF6C63FF),
      distance: 'Centro',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'PAIF Sur y Mallasa',
      type: 'Legal / Psicológico / Social',
      address: 'Calle 16 de Obrajes, detrás del DAE, La Paz',
      phone: '+591 2788105',
      icon: Icons.balance_rounded,
      color: Color(0xFF7E57C2),
      distance: 'Obrajes',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'PAIF San Antonio y Hampaturi',
      type: 'Legal / Psicológico / Social',
      address: 'Av. Josefa Mujía, interior Subalcaldía San Antonio, La Paz',
      phone: '+591 2238766',
      icon: Icons.balance_rounded,
      color: Color(0xFF5C6BC0),
      distance: 'San Antonio',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'PAIF Periférica y Zongo',
      type: 'Legal / Psicológico / Social',
      address:
          'Av. Prolongación Manco Kapac, frente al Teleférico Rojo, La Paz',
      phone: '+591 2456027',
      icon: Icons.balance_rounded,
      color: Color(0xFF3949AB),
      distance: 'Periférica',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'PAIF Max Paredes',
      type: 'Legal / Psicológico / Social',
      address:
          'Av. Entre Ríos esq. Chorolque y Los Andes, detrás del cementerio, La Paz',
      phone: '+591 2456242',
      icon: Icons.balance_rounded,
      color: Color(0xFF1E88E5),
      distance: 'Max Paredes',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'PAIF Cotahuma',
      type: 'Legal / Psicológico / Social',
      address: 'Av. General Lanza, frente a Plaza Lira, La Paz',
      phone: '+591 2455888',
      icon: Icons.balance_rounded,
      color: Color(0xFF00897B),
      distance: 'Cotahuma',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'PAIF Centro',
      type: 'Legal / Psicológico / Social',
      address: 'Pje. Melchor Jiménez y Calle Graneros, La Paz',
      phone: '+591 2317105',
      icon: Icons.balance_rounded,
      color: Color(0xFF43A047),
      distance: 'Centro',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'Defensoría Terminal Minasa',
      type: 'Legal / Social',
      address: 'Av. Ramiro Castillo, interior Terminal Minasa, La Paz',
      phone: '156',
      icon: Icons.family_restroom_rounded,
      color: Color(0xFF4CAF50),
      distance: 'Villa Fátima',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'Defensoría Terminal Central',
      type: 'Legal / Social',
      address: 'Av. Perú y Calle Uruguay, interior Terminal de Buses, La Paz',
      phone: '156',
      icon: Icons.family_restroom_rounded,
      color: Color(0xFF66BB6A),
      distance: 'Terminal',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'Hospital Municipal La Portada',
      type: 'Salud / Emergencias',
      address: 'Av. La Florida, Zona La Portada, La Paz',
      phone: '+591 2651756',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFFF44336),
      distance: 'La Portada',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'Hospital Municipal Los Pinos',
      type: 'Salud / Emergencias',
      address:
          'Calle 25 de Calacoto s/n, entre Muñoz Reyes y José Aguirre Acha, La Paz',
      phone: '+591 2771120',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFFE53935),
      distance: 'Zona Sur',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'Hospital Municipal La Merced',
      type: 'Salud / Emergencias',
      address:
          'Calle Villa Aspiazu s/n, entre Arapata y Tajma, Villa Fátima, La Paz',
      phone: '+591 2219685',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFFD81B60),
      distance: 'Villa Fátima',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'Hospital Municipal Cotahuma',
      type: 'Salud / Emergencias',
      address: 'Av. Jaimes Freire, Zona Tembladerani, La Paz',
      phone: '+591 2652767',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFFEF5350),
      distance: 'Tembladerani',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'Hospital La Paz',
      type: 'Salud / Emergencias',
      address: 'Zona 14 de Septiembre, frente a Plaza Garita de Lima, La Paz',
      phone: '+591 2454033',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFFFB8C00),
      distance: 'Garita',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'FELCV La Paz',
      type: 'Legal',
      address: 'Av. Sucre entre Catacora y Bolívar s/n, La Paz',
      phone: '+591 2285495',
      icon: Icons.gavel_rounded,
      color: Color(0xFFF57C00),
      distance: 'Central',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'Albergue del Bicentenario Bolivia Solidaria',
      type: 'Albergues / Protección',
      address: 'Zona Mallasa, Calle 7, La Paz',
      phone: '+591 2319905',
      icon: Icons.home_rounded,
      color: Color(0xFF8E24AA),
      distance: 'Mallasa',
      isOpen: true,
      hasPhysicalLocation: true,
    ),
    _Center(
      name: 'Línea Arco Iris',
      type: 'Psicológico / Apoyo',
      address: 'Atención telefónica municipal',
      phone: '+591 2650915',
      icon: Icons.phone_in_talk_rounded,
      color: Color(0xFF00BCD4),
      distance: '24 h',
      isOpen: true,
      hasPhysicalLocation: false,
    ),
    _Center(
      name: 'Red de Ambulancias',
      type: 'Salud / Emergencias',
      address: 'Atención telefónica municipal',
      phone: '167',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFF26A69A),
      distance: '24 h',
      isOpen: true,
      hasPhysicalLocation: false,
    ),
  ];

  List<_Center> get _filteredCenters {
    final selectedCategory = _normalizeText(_categories[_selectedCategory]);
    if (selectedCategory == 'todos') {
      return _centers;
    }

    return _centers.where((center) {
      final normalizedType = _normalizeText(center.type);
      return normalizedType.contains(selectedCategory);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    if (_isRefreshingLocation) return;

    setState(() => _isRefreshingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(
          'Activa la ubicación del dispositivo para calcular rutas.',
        );
        setState(() {
          _locationLabel = 'La Paz, Bolivia · Ubicación desactivada';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnackBar('No se concedió permiso de ubicación.');
        setState(() {
          _locationLabel = 'La Paz, Bolivia · Sin permiso de ubicación';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _locationLabel =
            'Ubicación lista · ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      _showSnackBar('No se pudo obtener tu ubicación actual.');
      if (!mounted) return;
      setState(() {
        _locationLabel = 'La Paz, Bolivia · Error al actualizar';
      });
    } finally {
      if (mounted) {
        setState(() => _isRefreshingLocation = false);
      }
    }
  }

  Future<void> _openCenterRoute(_Center center) async {
    if (!center.hasPhysicalLocation) {
      _showSnackBar('Este servicio es telefónico. Usa el botón Llamar.');
      return;
    }

    final queryParameters = <String, String>{
      'api': '1',
      'destination': center.address,
      'travelmode': 'driving',
    };

    final currentPosition = _currentPosition;
    if (currentPosition != null) {
      queryParameters['origin'] =
          '${currentPosition.latitude},${currentPosition.longitude}';
    }

    final mapsUri = Uri.https('www.google.com', '/maps/dir/', queryParameters);

    try {
      final opened = await launchUrl(
        mapsUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showSnackBar('No se pudo abrir la ruta en mapas.');
      }
    } catch (_) {
      _showSnackBar('No se pudo abrir la ruta en mapas.');
    }
  }

  Future<void> _callCenter(_Center center) async {
    final phone = _normalizePhone(center.phone);
    if (phone.isEmpty) {
      _showSnackBar('Este centro no tiene un número válido para llamar.');
      return;
    }

    final callUri = Uri(scheme: 'tel', path: phone);

    try {
      final opened = await launchUrl(
        callUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showSnackBar('No se pudo abrir el marcador para llamar.');
      }
    } catch (_) {
      _showSnackBar('No se pudo abrir el marcador para llamar.');
    }
  }

  String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';

    final hasLeadingPlus = trimmed.startsWith('+');
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
      return digits.isEmpty ? '' : '+$digits';
    }

    if (hasLeadingPlus) {
      return digits.isEmpty ? '' : '+$digits';
    }

    if (digits.startsWith('591')) {
      return '+$digits';
    }

    if (digits.length == 8) {
      return '+591$digits';
    }

    return digits;
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final filteredCenters = _filteredCenters;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: widget.isEmbedded ? AppBar(title: const Text('Destino')) : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isEmbedded) ...[
                    Text('Destino', style: AppTheme.headlineLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Centros de apoyo cercanos',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                  ],
                  InkWell(
                    onTap: _refreshLocation,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(
                            0xFF2196F3,
                          ).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.my_location_rounded,
                            color: Color(0xFF2196F3),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationLabel,
                              style: AppTheme.bodyMedium.copyWith(
                                color: const Color(0xFF2196F3),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: _isRefreshingLocation
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF2196F3),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    color: Color(0xFF2196F3),
                                    size: 18,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final selected = _selectedCategory == i;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.divider,
                              ),
                            ),
                            child: Text(
                              _categories[i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppTheme.surface
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${filteredCenters.length} centros encontrados',
                    style: AppTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(
              child: filteredCenters.isEmpty
                  ? const _EmptyDirectoryState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      itemCount: filteredCenters.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final center = filteredCenters[i];
                        return _CenterCard(
                          center: center,
                          onTap: () => _openCenterRoute(center),
                          onRouteTap: () => _openCenterRoute(center),
                          onCallTap: () => _callCenter(center),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterCard extends StatelessWidget {
  final _Center center;
  final VoidCallback onTap;
  final VoidCallback onRouteTap;
  final VoidCallback onCallTap;

  const _CenterCard({
    required this.center,
    required this.onTap,
    required this.onRouteTap,
    required this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: center.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(center.icon, color: center.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(center.name, style: AppTheme.labelLarge),
                    const SizedBox(height: 3),
                    Text(
                      center.type,
                      style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (center.isOpen
                              ? AppTheme.success
                              : AppTheme.textSecondary)
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  center.isOpen ? 'Abierto' : 'Cerrado',
                  style: TextStyle(
                    color: center.isOpen
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppTheme.textSecondary,
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  center.address,
                  style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                ),
              ),
              Text(
                center.distance,
                style: AppTheme.bodyMedium.copyWith(
                  fontSize: 12,
                  color: AppTheme.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                color: AppTheme.textSecondary,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                center.phone,
                style: AppTheme.bodyMedium.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRouteTap,
                  icon: const Icon(Icons.route_rounded, size: 18),
                  label: Text(center.hasPhysicalLocation ? 'Ruta' : 'Info'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.divider),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCallTap,
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Llamar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyDirectoryState extends StatelessWidget {
  const _EmptyDirectoryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 54,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'No hay centros en esta categoría',
              style: AppTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Prueba con otra categoría o actualiza tu ubicación para buscar rutas.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Center {
  final String name;
  final String type;
  final String address;
  final String phone;
  final IconData icon;
  final Color color;
  final String distance;
  final bool isOpen;
  final bool hasPhysicalLocation;

  const _Center({
    required this.name,
    required this.type,
    required this.address,
    required this.phone,
    required this.icon,
    required this.color,
    required this.distance,
    required this.isOpen,
    required this.hasPhysicalLocation,
  });
}
