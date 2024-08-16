import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';

class OrdersSam {
  final String orderId;
  final String itemName;
  final String customerName;
  final String customerMobile;
  final String itemPrice;
  final String latt;
  final String long;
  final String address;

  OrdersSam({
    required this.orderId,
    required this.itemName,
    required this.customerName,
    required this.customerMobile,
    required this.itemPrice,
    required this.latt,
    required this.long,
    required this.address,
  });
}

class NavigationPage extends StatefulWidget {
  const NavigationPage({Key? key}) : super(key: key);

  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  OrdersSam order = OrdersSam(
    orderId: '3216',
    itemName: 'Veg Briyani',
    customerName: 'Ajay',
    customerMobile: '7075123456',
    itemPrice: '₹200',
    latt: '9.167414',
    long: '77.876747',
    address: 'Customer Address, Kalasalingam University',
  );

  bool _isNavigating = false;
  late GoogleMapController _googleMapController;
  LocationData? _currentLocation;
  final Location _location = Location();
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _initializeLocationService();
  }

  Future<void> _initializeLocationService() async {
    final bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      final bool serviceRequested = await _location.requestService();
      if (!serviceRequested) {
        return;
      }
    }

    final PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      final PermissionStatus permissionRequested =
          await _location.requestPermission();
      if (permissionRequested != PermissionStatus.granted) {
        return;
      }
    }

    _permissionGranted = true;

    _location.onLocationChanged.listen((LocationData currentLocation) {
      setState(() {
        _currentLocation = currentLocation;
      });

      if (_googleMapController != null) {
        _googleMapController.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(
              _currentLocation!.latitude!,
              _currentLocation!.longitude!,
            ),
          ),
        );
      }
    });
  }

  Future<void> _callCustomer() async {
    final url = Uri.parse('tel:${order.customerMobile}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _acceptOrder() {
    setState(() {
      _isNavigating = true;
    });
  }

  void _rejectOrder() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          if (!_isNavigating)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Do you want to accept this order?',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: _acceptOrder,
                      child: const Text('Accept'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: _rejectOrder,
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: _permissionGranted && _currentLocation != null
                  ? GoogleMap(
                      onMapCreated: (controller) {
                        _googleMapController = controller;
                      },
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          double.parse(order.latt),
                          double.parse(order.long),
                        ),
                        zoom: 14,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId('customer_location'),
                          position: LatLng(
                            double.parse(order.latt),
                            double.parse(order.long),
                          ),
                          infoWindow: InfoWindow(
                            title: order.address,
                          ),
                        ),
                        Marker(
                          markerId: MarkerId('current_location'),
                          position: LatLng(
                            _currentLocation!.latitude!,
                            _currentLocation!.longitude!,
                          ),
                          infoWindow: const InfoWindow(
                            title: 'Your Location',
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueBlue,
                          ),
                        ),
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          if (_isNavigating)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ID: ${order.orderId}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Item: ${order.itemName}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Customer: ${order.customerName}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Price: ${order.itemPrice}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Address: ${order.address}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                    onPressed: _callCustomer,
                    child: const Text('Call Customer'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _googleMapController.dispose();
    super.dispose();
  }
}
