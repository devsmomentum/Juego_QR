import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';

class LocationPickerDialog extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerDialog({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  latlng.LatLng? picked;
  late latlng.LatLng temp;
  final MapController mapController = MapController();
  final TextEditingController searchController = TextEditingController();
  Timer? debounce;
  List<dynamic> suggestions = [];

  @override
  void initState() {
    super.initState();
    // Default to a location in Venezuela if no initial location is provided
    temp = (widget.initialLatitude != null && widget.initialLongitude != null && 
            widget.initialLatitude != 0 && widget.initialLongitude != 0)
        ? latlng.LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : const latlng.LatLng(10.4806, -66.9036);
  }

  @override
  void dispose() {
    searchController.dispose();
    debounce?.cancel();
    super.dispose();
  }

  Future<void> searchLocation() async {
    final query = searchController.text;
    if (query.isEmpty) {
      if (mounted) setState(() => suggestions = []);
      return;
    }

    final apiKey = 'pk.45e576837f12504a63c6d1893820f1cf';
    final url = Uri.parse(
        'https://us1.locationiq.com/v1/search.php?key=$apiKey&q=$query&format=json&limit=5&countrycodes=ve');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && mounted) {
          setState(() {
            suggestions = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Error searching: $e');
    }
  }

  void selectSuggestion(dynamic suggestion) {
    final lat = double.parse(suggestion['lat']);
    final lon = double.parse(suggestion['lon']);
    final display = suggestion['display_name'];
    final newPos = latlng.LatLng(lat, lon);

    if (mounted) {
      setState(() {
        temp = newPos;
        suggestions = [];
        searchController.text = display;
      });
      mapController.move(newPos, 15);
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            // Header with search
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: TextField(
                controller: searchController,
                style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Buscar dirección...',
                  hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4)),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.location_searching_rounded, color: AppTheme.lGoldAction, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: AppTheme.lGoldAction),
                    onPressed: searchLocation,
                  ),
                ),
                onChanged: (value) {
                  if (debounce?.isActive ?? false) debounce!.cancel();
                  debounce = Timer(const Duration(milliseconds: 400), () {
                    searchLocation();
                  });
                },
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: temp,
                        initialZoom: 14,
                        cameraConstraint: CameraConstraint.contain(
                          bounds: LatLngBounds(
                            const latlng.LatLng(0.5, -73.5),
                            const latlng.LatLng(12.5, -59.5),
                          ),
                        ),
                        minZoom: 5,
                        onTap: (tapPos, latLng) {
                          if (mounted) {
                            setState(() {
                              temp = latLng;
                              suggestions = [];
                            });
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 50,
                              height: 50,
                              point: temp,
                              child: const Icon(Icons.location_on,
                                  color: Colors.redAccent, size: 50),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (suggestions.isNotEmpty)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 250,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(16)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: suggestions.length,
                            separatorBuilder: (_, __) => Divider(
                                height: 1, color: Theme.of(context).dividerColor.withOpacity(0.05)),
                            itemBuilder: (context, index) {
                              final item = suggestions[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.place_outlined, color: AppTheme.lGoldAction, size: 18),
                                title: Text(
                                  item['display_name'] ?? '',
                                  style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13, fontWeight: FontWeight.normal),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => selectSuggestion(item),
                              );
                            },
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (temp.latitude < 0.5 ||
                                temp.latitude > 12.5 ||
                                temp.longitude < -73.5 ||
                                temp.longitude > -59.5) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '⚠️ Por favor selecciona una ubicación dentro de Venezuela'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            picked = temp;
                            Navigator.of(context).pop(picked);
                          },
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                          label: const Text('SELECCIONAR ESTA UBICACIÓN', 
                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.lGoldAction,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 8,
                            shadowColor: AppTheme.lGoldAction.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
