import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; // Para la imagen
import '../../models/event.dart';
import '../../providers/event_provider.dart';

class EventCreationScreen extends StatefulWidget {
  const EventCreationScreen({super.key});

  @override
  State<EventCreationScreen> createState() => _EventCreationScreenState();
}

class _EventCreationScreenState extends State<EventCreationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Variables para guardar los datos
  String _title = '';
  String _description = '';
  String? _location; // Ahora es nullable para el Dropdown
  String _clue = '';
  String _pin = ''; // Variable para el PIN
  int _maxParticipants = 0;
  DateTime _selectedDate = DateTime.now();

  // Variable para la imagen seleccionada
  XFile? _selectedImage;

  // Lista de Estados de Venezuela
  final List<String> _states = [
    'Amazonas',
    'Anzoátegui',
    'Apure',
    'Aragua',
    'Barinas',
    'Bolívar',
    'Carabobo',
    'Cojedes',
    'Delta Amacuro',
    'Distrito Capital',
    'Falcón',
    'Guárico',
    'La Guaira',
    'Lara',
    'Mérida',
    'Miranda',
    'Monagas',
    'Nueva Esparta',
    'Portuguesa',
    'Sucre',
    'Táchira',
    'Trujillo',
    'Yaracuy',
    'Zulia'
  ];

  // Función para seleccionar imagen
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  // Función para enviar el formulario
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Validación de imagen obligatoria
      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Debes seleccionar una imagen')),
        );
        return;
      }

      // CREAR EL OBJETO EVENTO
      // Nota: En un caso real, primero subes la imagen a la nube y obtienes la URL.
      // Aquí simularemos que la URL es el nombre del archivo.
      final newEvent = Event(
        id: DateTime.now().toString(),
        title: _title,
        description: _description,
        location: _location!, // Ya validado por el form
        date: _selectedDate,
        createdByAdminId: 'admin_1', // ID simulado del admin
        imageUrl: _selectedImage!.name, // Simulamos la URL
        clue: _clue,
        maxParticipants: _maxParticipants,
        pin: _pin,
      );

      // Guardar usando el Provider
      final provider = Provider.of<EventProvider>(context, listen: false);

      // Mostrar indicador de carga (opcional, pero recomendado)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏳ Guardando evento...')),
      );

      provider.createEvent(newEvent, _selectedImage).then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Competencia creada con éxito')),
          );
          // Limpiar formulario
          _formKey.currentState!.reset();
          setState(() {
            _selectedImage = null;
            _location = null; // Resetear dropdown
          });
        }
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al crear evento: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Estilo común para los inputs
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: const Color.fromARGB(255, 38, 13,
          109), // <--- AQUÍ CAMBIAS EL COLOR DE FONDO DE LOS INPUTS
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.emoji_events, color: Colors.white),
            SizedBox(width: 10),
            Text("Crear Competencia"),
          ],
        ),
      ),
      body: Center(
        child: Container(
          width: 800, // Ancho limitado para que se vea bien en Web
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text("Nueva Competencia",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // 1. Título
                    TextFormField(
                      decoration: inputDecoration.copyWith(
                          labelText: 'Título del Evento'),
                      validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                      onSaved: (v) => _title = v!,
                    ),
                    const SizedBox(height: 15),

                    // 2. Descripción
                    TextFormField(
                      decoration:
                          inputDecoration.copyWith(labelText: 'Descripción'),
                      maxLines: 3,
                      validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                      onSaved: (v) => _description = v!,
                    ),
                    const SizedBox(height: 15),

                    // 3. Imagen (Botón de carga)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 17, 5, 83),
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.image),
                            label: const Text("Subir Imagen"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors
                                  .indigo.shade50, // Color de fondo del botón
                              foregroundColor:
                                  Colors.indigo, // Color del texto e icono
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              _selectedImage == null
                                  ? "Ninguna imagen seleccionada"
                                  : "✅ ${_selectedImage!.name}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 4. Pista
                    TextFormField(
                      decoration: inputDecoration.copyWith(
                          labelText: 'Pista (Clue)',
                          prefixIcon: const Icon(Icons.lightbulb)),
                      validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                      onSaved: (v) => _clue = v!,
                    ),
                    const SizedBox(height: 15),

                    // 4.1 PIN de Acceso
                    TextFormField(
                      decoration: inputDecoration.copyWith(
                          labelText: 'PIN de Acceso (Código)',
                          prefixIcon: const Icon(Icons.lock)),
                      validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                      onSaved: (v) => _pin = v!,
                    ),
                    const SizedBox(height: 15),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 5. Lugar (Dropdown)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: inputDecoration.copyWith(
                                labelText: 'Lugar / Ubicación',
                                prefixIcon: const Icon(Icons.map)),
                            value: _location,
                            items: _states.map((state) {
                              return DropdownMenuItem(
                                value: state,
                                child: Text(state),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _location = value;
                              });
                            },
                            validator: (v) =>
                                v == null ? 'Campo requerido' : null,
                            onSaved: (v) => _location = v,
                          ),
                        ),
                        const SizedBox(width: 15),
                        // 6. Capacidad
                        Expanded(
                          child: TextFormField(
                            decoration: inputDecoration.copyWith(
                                labelText: 'Max Participantes',
                                prefixIcon: const Icon(Icons.group)),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            onSaved: (v) => _maxParticipants = int.parse(v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Botón Guardar
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(20),
                          backgroundColor: Colors.indigo,
                          foregroundColor:
                              const Color.fromARGB(255, 255, 255, 255),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _submitForm,
                        child: const Text("CREAR EVENTO",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)))
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
