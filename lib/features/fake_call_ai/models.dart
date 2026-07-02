class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);
}

class NavStep {
  final String instruction;
  final LatLng endLocation;

  const NavStep({required this.instruction, required this.endLocation});
}

class NavCue {
  final String text;
  final bool priority;

  const NavCue({required this.text, this.priority = false});
}
