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
      backgroundColor: AppTheme.cardBg,
      contentPadding: const EdgeInsets.all(15),
      content: SizedBox(
        width: 350,
        height: 450,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar dirección...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
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
                borderRadius: BorderRadius.circular(12),
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
                              width: 40,
                              height: 40,
                              point: temp,
                              child: const Icon(Icons.location_on,
                                  color: Colors.red, size: 40),
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
                        height: 200,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(8)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: suggestions.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: Colors.white10),
                            itemBuilder: (context, index) {
                              final item = suggestions[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  item['display_name'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
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
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ElevatedButton(
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
                          child: const Text('Seleccionar esta ubicación'),
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
