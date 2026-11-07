import 'package:latlong2/latlong.dart';

bool pointInBoundary(List<LatLng> boundary, double lat, double lng) {
  if (boundary.length < 3) return true;
  var inside = false;
  for (var i = 0, j = boundary.length - 1; i < boundary.length; j = i++) {
    final a = boundary[i];
    final b = boundary[j];
    final cross =
        (lat - a.latitude) * (b.longitude - a.longitude) -
        (lng - a.longitude) * (b.latitude - a.latitude);
    final onEdge =
        cross.abs() < 1e-10 &&
        lat >= (a.latitude < b.latitude ? a.latitude : b.latitude) &&
        lat <= (a.latitude > b.latitude ? a.latitude : b.latitude) &&
        lng >= (a.longitude < b.longitude ? a.longitude : b.longitude) &&
        lng <= (a.longitude > b.longitude ? a.longitude : b.longitude);
    if (onEdge) return true;
    if ((a.latitude > lat) != (b.latitude > lat)) {
      final intersection =
          (b.longitude - a.longitude) *
              (lat - a.latitude) /
              (b.latitude - a.latitude) +
          a.longitude;
      if (lng < intersection) inside = !inside;
    }
  }
  return inside;
}
