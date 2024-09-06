import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecub_delivery/pages/home.dart';

class GoogleMapPage extends StatefulWidget {
  final OrdersSam oder;
  const GoogleMapPage({super.key, required this.oder});

  @override
  State<GoogleMapPage> createState() => _GoogleMapPageState();
}

class _GoogleMapPageState extends State<GoogleMapPage> {
  final locationController = Location();
  Timer? locationUpdateTimer;

  LatLng? currentPosition;
  LatLng? destinationPosition;
  Map<PolylineId, Polyline> polylines = {};
  BitmapDescriptor? currentLocationIcon;
  BitmapDescriptor? destinationIcon;
  String? eta; // Add a variable to store the ETA

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      currentLocationIcon =
          await createBitmapDescriptorFromIcon(Icons.location_on);
      destinationIcon = await createBitmapDescriptorFromIcon(Icons.flag);
      await initializeMap();
      await fetchAndStoreEstimatedTimeOfArrival(); // Fetch and store the ETD
      setState(() {}); // Update the UI

      // Start the timer to update location every second
      locationUpdateTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
        await fetchCurrentLocation();
        await updateLocationInFirestore();
      });
    });
  }

  @override
  void dispose() {
    locationUpdateTimer
        ?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  Future<BitmapDescriptor> createBitmapDescriptorFromIcon(
      IconData iconData) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = Colors.blue;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const iconSize = 48.0;

    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: iconSize,
        fontFamily: iconData.fontFamily,
        color: Colors.blue,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 0));

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(iconSize.toInt(), iconSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> initializeMap() async {
    await fetchCurrentLocation();
    destinationPosition =
        await fetchCoordinatesFromPlaceName(widget.oder.address);
    final coordinates = await fetchPolylinePoints();
    generatePolyLineFromPoints(coordinates);
  }

  Future<void> fetchAndStoreEstimatedTimeOfArrival() async {
    final apiKey =
        'AIzaSyClrhOKzru5eVbTkViOCRixNQ5nOvwep2I'; // Replace with your Google API Key
    final origin = '${currentPosition!.latitude},${currentPosition!.longitude}';
    final destination =
        '${destinationPosition!.latitude},${destinationPosition!.longitude}';
    final url =
        'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$origin&destinations=$destination&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint('API Response: $data'); // Debug print to check API response
      if (data['status'] == 'OK') {
        final elements = data['rows'][0]['elements'][0];
        if (elements['status'] == 'OK') {
          final duration = elements['duration']['text'];
          if (mounted) {
            setState(() {
              eta = duration;
            });
          }
          await storeETDInFirestore(duration); // Store ETD in Firestore
        } else {
          debugPrint('Error fetching ETA: ${elements['status']}');
        }
      } else {
        debugPrint('Error fetching ETA: ${data['status']}');
      }
    } else {
      debugPrint('Error fetching ETA: ${response.statusCode}');
    }
  }

  Future<void> storeETDInFirestore(String etd) async {
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.oder.orderId); // Using orderId which is actually itemId

      // Check if the document exists
      final docSnapshot = await orderRef.get();
      if (!docSnapshot.exists) {
        throw 'Document with itemId ${widget.oder.orderId} does not exist';
      }

      await orderRef.update({'etd': etd});
      debugPrint('ETD stored in Firestore successfully');
    } catch (e) {
      debugPrint('Error storing ETD in Firestore: $e');
    }
  }

  Future<String?> getLoggedInUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> updateOrderStatus(String status) async {
    try {
      debugPrint('Updating order status to $status');
      debugPrint(
          'Item ID: ${widget.oder.orderId}'); // Assuming orderId is actually itemId

      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.oder.orderId); // Using orderId which is actually itemId

      // Check if the document exists
      final docSnapshot = await orderRef.get();
      if (!docSnapshot.exists) {
        throw 'Document with itemId ${widget.oder.orderId} does not exist';
      }

      // Get the logged-in user's ID
      final userId = await getLoggedInUserId();
      if (userId == null) {
        throw 'User is not logged in';
      }

      // Update the order document with the status and del_agent ID
      await orderRef.update({
        'status': status,
        'del_agent': userId,
      });

      setState(() {
        widget.oder.status = status;
      });

      if (status == 'in_transit') {
        final url =
            'google.navigation:q=${destinationPosition!.latitude},${destinationPosition!.longitude}&mode=d';
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          throw 'Could not launch $url';
        }
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }

  Future<void> updateSalaryAndRides() async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final String agentId =
        await getLoggedInUserId() ?? ''; // Get the logged-in user's ID

    if (agentId.isEmpty) {
      debugPrint('User is not logged in');
      return;
    }

    try {
      DocumentReference agentRef =
          _firestore.collection('delivery_agent').doc(agentId);
      DocumentSnapshot agentSnapshot = await agentRef.get();

      if (agentSnapshot.exists) {
        int currentSalary = agentSnapshot['salary'] is int
            ? agentSnapshot['salary']
            : (agentSnapshot['salary'] as double).toInt();
        int currentRides = agentSnapshot['rides'] is int
            ? agentSnapshot['rides']
            : (agentSnapshot['rides'] as double).toInt();

        // Log current salary and rides
        debugPrint('Current Salary: $currentSalary');
        debugPrint('Current Rides: $currentRides');

        int updatedSalary = currentSalary + 30;
        int updatedRides = currentRides + 1;

        // Log updated salary and rides
        debugPrint('Updated Salary: $updatedSalary');
        debugPrint('Updated Rides: $updatedRides');

        await agentRef.update({
          'salary': updatedSalary,
          'rides': updatedRides,
        });

        debugPrint('Salary and rides updated successfully');
      } else {
        debugPrint('Agent document does not exist');
      }
    } catch (e) {
      debugPrint('Error updating salary and rides: $e');
    }
  }

  Future<void> updateLocationInFirestore() async {
    try {
      final userId = await getLoggedInUserId();
      if (userId == null) {
        throw 'User is not logged in';
      }

      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.oder.orderId); // Using orderId which is actually itemId

      // Check if the document exists
      final docSnapshot = await orderRef.get();
      if (!docSnapshot.exists) {
        throw 'Document with itemId ${widget.oder.orderId} does not exist';
      }

      await orderRef.update({
        'current_latitude': currentPosition!.latitude,
        'current_longitude': currentPosition!.longitude,
      });

      debugPrint('Location updated in Firestore');
    } catch (e) {
      debugPrint('Error updating location in Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          children: [
            currentPosition == null || destinationPosition == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: currentPosition!,
                      zoom: 13,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('currentLocation'),
                        icon: currentLocationIcon ??
                            BitmapDescriptor.defaultMarker,
                        position: currentPosition!,
                      ),
                      Marker(
                        markerId: const MarkerId('destinationLocation'),
                        icon: destinationIcon ?? BitmapDescriptor.defaultMarker,
                        position: destinationPosition!,
                      ),
                    },
                    polylines: Set<Polyline>.of(polylines.values),
                  ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10.0,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Order ID: ${widget.oder.orderId}'),
                    Text('Item Name: ${widget.oder.itemName}'),
                    Text('Customer Name: ${widget.oder.customerName}'),
                    Text('Item Price: ${widget.oder.itemPrice}'),
                    Text('Address: ${widget.oder.address}'),
                    if (eta != null) Text('ETD: $eta'), // Display the ETD
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            debugPrint('Accept button pressed');
                            await updateOrderStatus('in_transit');
                          },
                          child: Text('Accept'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            debugPrint('Delivered button pressed');
                            await updateOrderStatus('delivered');

                            // Update salary and rides
                            await updateSalaryAndRides();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => HomeScreen()),
                            ); // Navigate back to the home screen
                          },
                          child: Text('Delivered'),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> fetchCurrentLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationController.requestService();
      if (!serviceEnabled) {
        debugPrint('Location service is not enabled');
        return;
      }
    }

    permissionGranted = await locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        debugPrint('Location permission is not granted');
        return;
      }
    }

    LocationData locationData = await locationController.getLocation();
    setState(() {
      currentPosition = LatLng(locationData.latitude!, locationData.longitude!);
    });
    debugPrint('Current position: $currentPosition');
  }

  Future<LatLng?> fetchCoordinatesFromPlaceName(String placeName) async {
    final apiKey =
        'AIzaSyClrhOKzru5eVbTkViOCRixNQ5nOvwep2I'; // Replace with your Google API Key
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?address=$placeName&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final location = data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      } else {
        debugPrint('Error fetching coordinates: ${data['status']}');
        return null;
      }
    } else {
      debugPrint('Error fetching coordinates: ${response.statusCode}');
      return null;
    }
  }

  Future<List<LatLng>> fetchPolylinePoints() async {
    final polylinePoints = PolylinePoints();

    final result = await polylinePoints.getRouteBetweenCoordinates(
      'AIzaSyClrhOKzru5eVbTkViOCRixNQ5nOvwep2I', // Replace with your Maps API Key
      PointLatLng(currentPosition!.latitude, currentPosition!.longitude),
      PointLatLng(
          destinationPosition!.latitude, destinationPosition!.longitude),
    );

    if (result.points.isNotEmpty) {
      debugPrint('Polyline points fetched successfully');
      return result.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    } else {
      debugPrint('Error fetching polyline points: ${result.errorMessage}');
      return [];
    }
  }

  Future<void> generatePolyLineFromPoints(
      List<LatLng> polylineCoordinates) async {
    const PolylineId id = PolylineId('polyline');

    final Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.blueAccent,
      points: polylineCoordinates,
      width: 5,
    );

    if (mounted) {
      setState(() {
        polylines[id] = polyline;
      });
      debugPrint('Polyline added to the map');
    }
  }
}
