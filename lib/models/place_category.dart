import 'package:flutter/material.dart';

enum PlaceCategory {
  publicInstitutions,
  businessesAndServices,
  lawFirms,
}

extension PlaceCategoryX on PlaceCategory {
  String get displayName {
    switch (this) {
      case PlaceCategory.publicInstitutions:
        return 'Instituciones públicas';
      case PlaceCategory.businessesAndServices:
        return 'Empresas y servicios';
      case PlaceCategory.lawFirms:
        return 'Despachos jurídicos';
    }
  }

  String get iconName {
    switch (this) {
      case PlaceCategory.publicInstitutions:
        return 'town-hall';
      case PlaceCategory.businessesAndServices:
        return 'town-hall';
      case PlaceCategory.lawFirms:
        return 'town-hall';
    }
  }

  Color get color {
    switch (this) {
      case PlaceCategory.publicInstitutions:
        return const Color(0xFF1E88E5);
      case PlaceCategory.businessesAndServices:
        return const Color(0xFF43A047);
      case PlaceCategory.lawFirms:
        return const Color(0xFF8E24AA);
    }
  }

  String get storageValue => toString().split('.').last;

  static PlaceCategory fromStorageValue(String? value) {
    switch (value) {
      case 'publicInstitutions':
        return PlaceCategory.publicInstitutions;
      case 'businessesAndServices':
        return PlaceCategory.businessesAndServices;
      case 'lawFirms':
        return PlaceCategory.lawFirms;
      default:
        return PlaceCategory.publicInstitutions;
    }
  }
}


