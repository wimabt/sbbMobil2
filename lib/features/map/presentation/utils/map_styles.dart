/// Google Maps custom styles
library;

/// Minimal style - Sadece Google'ın POI iconlarını kaldırır
/// Google Maps'in orijinal renklerini korur
const String minimalMapStyle = '''
[
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.business",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.business",
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.attraction",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.attraction",
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.place_of_worship",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.place_of_worship",
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.school",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.school",
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.sports_complex",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.sports_complex",
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  }
]
''';

/// Dark theme style for Google Maps.
/// Premium Night Mode - Professional navigation with visible streets.
/// Roads are brightened for clear navigation, water is deep navy blue.
const String darkMapStyle = '''
[
  { "elementType": "geometry", "stylers": [ { "color": "#1E1E1E" } ] },
  { "elementType": "labels.text.fill", "stylers": [ { "color": "#9E9E9E" } ] },
  { "elementType": "labels.text.stroke", "stylers": [ { "color": "#1E1E1E" } ] },
  { "featureType": "administrative", "elementType": "geometry.stroke", "stylers": [ { "color": "#4A4A4A" } ] },
  { "featureType": "administrative.land_parcel", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [ { "color": "#BDBDBD" } ] },
  { "featureType": "landscape.man_made", "stylers": [ { "color": "#1A1A1A" } ] },
  { "featureType": "landscape.natural", "stylers": [ { "color": "#1E1E1E" } ] },
  { "featureType": "poi", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "poi.park", "elementType": "geometry.fill", "stylers": [ { "color": "#1C2E1C" } ] },
  { "featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [ { "color": "#6B9B6B" } ] },
  { "featureType": "road", "elementType": "geometry", "stylers": [ { "color": "#424242" } ] },
  { "featureType": "road", "elementType": "geometry.stroke", "stylers": [ { "color": "#2A2A2A" } ] },
  { "featureType": "road", "elementType": "labels.text.fill", "stylers": [ { "color": "#9E9E9E" } ] },
  { "featureType": "road", "elementType": "labels.text.stroke", "stylers": [ { "color": "#1E1E1E" } ] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [ { "color": "#505050" } ] },
  { "featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [ { "color": "#2A2A2A" } ] },
  { "featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [ { "color": "#BDBDBD" } ] },
  { "featureType": "transit", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#141B2D" } ] },
  { "featureType": "water", "elementType": "labels.text.fill", "stylers": [ { "color": "#4A5A7A" } ] }
]
''';