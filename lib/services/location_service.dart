import 'package:geolocator/geolocator.dart';

// A small helper that wraps the messy parts of asking for location
// permission and getting the phone's current position, so the rest
// of the app doesn't need to worry about that boilerplate.
class LocationService {
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are off entirely (not just permission) —
      // nothing we can do from here except ask the user to enable it.
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // User permanently denied it — we'd need to send them to app
      // settings to fix this, but for now just return null gracefully.
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }
}