import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/office_location.dart';

/// Resultado de la búsqueda de oficinas
class OfficeSearchResult {
  final String response;
  final List<OfficeLocation> foundOffices;

  OfficeSearchResult({
    required this.response,
    required this.foundOffices,
  });
}

class AiAssistantService {
  static const String _apiKey = 'AIzaSyCqOoy37xN3R_VCHOpwn2lmesPbR2oXwyE';
  
  late final GenerativeModel _model;

  AiAssistantService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
  }

  /// Busca oficinas relacionadas con el trámite mencionado por el usuario
  Future<OfficeSearchResult> findOfficesForTransaction(
    String userMessage,
    List<OfficeLocation> offices, {
    geo.Position? userLocation,
  }) async {
    try {
      // Calcular distancias si hay ubicación del usuario
      final officesWithDistance = <Map<String, dynamic>>[];
      for (final office in offices) {
        double? distanceInKm;
        if (userLocation != null) {
          final distanceInMeters = geo.Geolocator.distanceBetween(
            userLocation.latitude,
            userLocation.longitude,
            office.latitude,
            office.longitude,
          );
          distanceInKm = distanceInMeters / 1000.0;
        }
        officesWithDistance.add({
          'office': office,
          'distance': distanceInKm,
        });
      }

      // Ordenar por distancia si hay ubicación
      if (userLocation != null) {
        officesWithDistance.sort((a, b) {
          final distA = a['distance'] as double? ?? double.infinity;
          final distB = b['distance'] as double? ?? double.infinity;
          return distA.compareTo(distB);
        });
      }

      // Crear lista de oficinas disponibles para el prompt con distancias
      final officesList = officesWithDistance.map((item) {
        final office = item['office'] as OfficeLocation;
        final distance = item['distance'] as double?;
        String distanceText = '';
        if (distance != null) {
          if (distance < 1) {
            distanceText = ' (${(distance * 1000).toStringAsFixed(0)} m de distancia)';
          } else {
            distanceText = ' (${distance.toStringAsFixed(1)} km de distancia)';
          }
        }
        return '• ${office.name} - ${office.description}${office.schedule != null ? " (Horario: ${office.schedule})" : ""}$distanceText';
      }).join('\n');

      final prompt = '''
Eres un asistente especializado en ayudar a los usuarios a encontrar oficinas gubernamentales para realizar trámites en Ecuador.

El usuario quiere realizar el siguiente trámite o consulta:
"$userMessage"

OFICINAS DISPONIBLES EN EL SISTEMA:
$officesList

INSTRUCCIONES CRÍTICAS - LEE CON ATENCIÓN Y ANALIZA CADA OFICINA:

**PASO 1: IDENTIFICAR EL TIPO DE TRÁMITE**
Analiza la consulta del usuario y determina el tipo de trámite:
- Trámites de VEHÍCULOS (auto, carro, moto, matrícula, licencia de conducir) → ANT (Agencia Nacional de Tránsito)
- Trámites de TERRITORIO/PROPIEDAD (casa, terreno, lote, catastro) → Municipios o GADs
- Trámites de IMPUESTOS → SRI (Servicio de Rentas Internas)
- Trámites de TRABAJO → Ministerio de Trabajo
- Trámites de IDENTIDAD → Registro Civil

**PASO 2: ANALIZAR CADA OFICINA EN LA LISTA**
Para CADA oficina en la lista, lee COMPLETAMENTE su nombre Y descripción:
- NO te bases solo en el nombre, LEE la descripción completa
- Busca palabras clave específicas en la descripción que coincidan con el tipo de trámite
- PRIORIZA oficinas con coincidencias EXACTAS sobre coincidencias parciales

**PASO 3: COINCIDENCIAS ESPECÍFICAS POR TIPO DE TRÁMITE**

Para TRÁMITES DE VEHÍCULOS (auto, carro, moto, matrícula, licencia):
✅ BUSCA PRIMERO: Oficinas que en su nombre O descripción mencionen:
   - "ANT" o "Agencia Nacional de Tránsito"
   - "Tránsito" (específicamente relacionado con vehículos)
   - "Automotor" o "automotriz"
   ❌ NO incluyas: GAD, municipio, gobierno provincial (estos NO manejan trámites de vehículos)

Para TRÁMITES DE TERRITORIO/PROPIEDAD (casa, terreno, lote, catastro):
✅ BUSCA: Oficinas que mencionen:
   - "gestión territorial"
   - "catastro"
   - "municipio" (para catastro municipal)
   - "GAD" o "Gobierno Provincial" (para gestión territorial provincial)

Para TRÁMITES DE IMPUESTOS:
✅ BUSCA: Oficinas que mencionen:
   - "SRI" o "Servicio de Rentas Internas"
   - "Rentas Internas"
   - "Tributario" o "fiscal"

Para TRÁMITES DE TRABAJO:
✅ BUSCA: Oficinas que mencionen:
   - "Ministerio de Trabajo" o "Relaciones Laborales"
   - "Laboral"

Para TRÁMITES DE IDENTIDAD:
✅ BUSCA: Oficinas que mencionen:
   - "Registro Civil"

**PASO 4: PRIORIZACIÓN**
1. PRIMERO: Oficinas con coincidencia EXACTA en nombre o descripción
2. SEGUNDO: Oficinas con coincidencia parcial pero clara
3. NO incluyas oficinas que NO tengan relación directa con el trámite

**PASO 5: LISTAR RESULTADOS**
- Lista TODAS las oficinas que encontraste relacionadas
- Si hay múltiples opciones válidas, menciónalas todas
- Para cada oficina, explica brevemente por qué es relevante según su descripción

FORMATO DE RESPUESTA:

🏛️ **Oficinas Recomendadas:**
[IMPORTANTE: Lista TODAS las oficinas encontradas, no solo una. Si hay múltiples opciones (ej: municipio y GAD), menciónalas todas. Para cada oficina, incluye su nombre completo, la distancia si está disponible, y explica brevemente por qué es relevante según su descripción. Si hay distancias disponibles, prioriza mencionar las más cercanas primero]

📋 **Información del Trámite:**
[Explica brevemente qué se necesita para este trámite, basándote en las descripciones de las oficinas encontradas]

📄 **Documentos Comunes Necesarios:**
• [Documento 1]
• [Documento 2]
• [Documento 3]

💡 **Recomendaciones:**
[Consejos útiles para realizar el trámite]

IMPORTANTE CRÍTICO: 
- LEE COMPLETAMENTE la descripción de CADA oficina antes de decidir si es relevante
- Para trámites de VEHÍCULOS, busca específicamente "ANT" o "Tránsito" en la descripción, NO incluyas GAD o municipios
- Para trámites de TERRITORIO, busca "gestión territorial", "catastro", "municipio" o "GAD" en la descripción
- PRIORIZA coincidencias exactas sobre coincidencias parciales
- Si encuentras múltiples oficinas relacionadas, menciónalas todas
- NO incluyas oficinas que NO tengan relación directa con el trámite específico

Máximo 400 palabras. Sé claro, conciso y útil. Lista TODAS las opciones disponibles que sean realmente relevantes.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      // Obtener las oficinas encontradas (ordenadas por distancia si hay ubicación)
      final foundOffices = officesWithDistance.map((item) => item['office'] as OfficeLocation).toList();
      
      if (response.text != null && response.text!.isNotEmpty) {
        // Buscar oficinas mencionadas en la respuesta del AI
        final mentionedOffices = _extractOfficesFromResponse(response.text!, foundOffices);
        return OfficeSearchResult(
          response: response.text!,
          foundOffices: mentionedOffices.isNotEmpty ? mentionedOffices : foundOffices,
        );
      } else {
        final officesList = foundOffices;
        final fallbackResponse = _getFallbackResponse(userMessage, officesList, userLocation: userLocation);
        return OfficeSearchResult(
          response: fallbackResponse,
          foundOffices: officesList,
        );
      }
    } catch (e) {
      print('Error al buscar oficinas: $e');
      // En caso de error, usar la lista original de oficinas sin distancias
      final fallbackResponse = _getFallbackResponse(userMessage, offices, userLocation: userLocation);
      final matchingOffices = searchOfficesByKeywords(userMessage, offices);
      return OfficeSearchResult(
        response: fallbackResponse,
        foundOffices: matchingOffices,
      );
    }
  }

  /// Extrae las oficinas mencionadas en la respuesta del AI
  List<OfficeLocation> _extractOfficesFromResponse(String response, List<OfficeLocation> allOffices) {
    final foundOffices = <OfficeLocation>[];
    final lowerResponse = response.toLowerCase();
    
    for (final office in allOffices) {
      final officeName = office.name.toLowerCase();
      final officeDesc = office.description.toLowerCase();
      
      // Buscar si el nombre completo de la oficina aparece en la respuesta
      if (lowerResponse.contains(officeName)) {
        foundOffices.add(office);
      } else {
        // Buscar palabras clave del nombre en la respuesta
        final nameWords = officeName.split(' ');
        int matches = 0;
        for (final word in nameWords) {
          if (word.length > 3 && lowerResponse.contains(word)) {
            matches++;
          }
        }
        // Si al menos 2 palabras del nombre aparecen, considerarlo
        if (matches >= 2) {
          foundOffices.add(office);
        } else {
          // Buscar términos clave de la descripción
          if (officeDesc.contains('ant') && lowerResponse.contains('ant')) {
            foundOffices.add(office);
          } else if (officeDesc.contains('tránsito') && lowerResponse.contains('tránsito')) {
            foundOffices.add(office);
          } else if (officeDesc.contains('agencia nacional') && lowerResponse.contains('agencia')) {
            foundOffices.add(office);
          }
        }
      }
    }
    
    return foundOffices;
  }

  /// Busca oficinas específicas basándose en palabras clave
  List<OfficeLocation> searchOfficesByKeywords(String query, List<OfficeLocation> offices) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    final keywords = _extractKeywords(lowerQuery);
    
    // Detectar tipo de trámite para priorización
    final isVehicleQuery = lowerQuery.contains('carro') || 
                          lowerQuery.contains('auto') || 
                          lowerQuery.contains('vehículo') || 
                          lowerQuery.contains('moto') ||
                          lowerQuery.contains('matrícula') ||
                          lowerQuery.contains('licencia') ||
                          lowerQuery.contains('tránsito');
    
    final isTerritoryQuery = lowerQuery.contains('territorio') || 
                            lowerQuery.contains('casa') || 
                            lowerQuery.contains('terreno') ||
                            lowerQuery.contains('lote') ||
                            lowerQuery.contains('predio') ||
                            lowerQuery.contains('catastro') ||
                            lowerQuery.contains('propiedad');
    
    final matches = <OfficeLocation>[];
    final matchScores = <OfficeLocation, int>{};
    
    for (final office in offices) {
      final officeName = office.name.toLowerCase();
      final officeDesc = office.description.toLowerCase();
      int score = 0;
      
      // Priorización especial para trámites de vehículos
      if (isVehicleQuery) {
        // Priorizar ANT sobre otras oficinas
        if (officeName.contains('ant') || 
            officeName.contains('agencia nacional de tránsito') ||
            officeDesc.contains('ant') ||
            officeDesc.contains('agencia nacional de tránsito') ||
            officeDesc.contains('tránsito')) {
          score += 10; // Puntuación muy alta para ANT
        }
        // Penalizar GAD y municipios para trámites de vehículos
        if (officeName.contains('gad') || 
            officeName.contains('municipio') ||
            officeDesc.contains('gad') ||
            officeDesc.contains('municipio') ||
            officeDesc.contains('gestión territorial')) {
          score -= 5; // Penalización para evitar recomendarlos
        }
      }
      
      // Priorización especial para trámites de territorio
      if (isTerritoryQuery) {
        // Priorizar oficinas con gestión territorial
        if (officeDesc.contains('gestión territorial') ||
            officeDesc.contains('catastro') ||
            officeName.contains('municipio') ||
            officeName.contains('gad') ||
            officeDesc.contains('municipio') ||
            officeDesc.contains('gad')) {
          score += 5;
        }
        // Penalizar ANT para trámites de territorio
        if (officeName.contains('ant') || officeDesc.contains('tránsito')) {
          score -= 5;
        }
      }
      
      // Buscar coincidencias por palabras clave
      for (final keyword in keywords) {
        // Coincidencia exacta en el nombre (mayor peso)
        if (officeName == keyword || officeName.contains(' $keyword ') || 
            officeName.startsWith('$keyword ') || officeName.endsWith(' $keyword')) {
          score += 5;
        } else if (officeName.contains(keyword)) {
          score += 3;
        }
        
        // Coincidencia exacta en la descripción
        if (officeDesc.contains(' $keyword ') || 
            officeDesc.startsWith('$keyword ') || 
            officeDesc.endsWith(' $keyword')) {
          score += 4;
        } else if (officeDesc.contains(keyword)) {
          score += 2;
        }
        
        // Coincidencia parcial en palabras individuales
        final keywordWords = keyword.split(' ');
        for (final word in keywordWords) {
          if (word.length > 3) {
            if (officeName.contains(word) || officeDesc.contains(word)) {
              score += 1;
            }
          }
        }
      }
      
      // También buscar términos relacionados directamente en el query
      final queryWords = lowerQuery.split(' ');
      for (final word in queryWords) {
        if (word.length > 4) {
          if (officeName.contains(word) || officeDesc.contains(word)) {
            score += 1;
          }
        }
      }
      
      if (score > 0) {
        matchScores[office] = score;
        if (!matches.contains(office)) {
          matches.add(office);
        }
      }
    }
    
    // Ordenar por score (mayor a menor)
    matches.sort((a, b) {
      final scoreA = matchScores[a] ?? 0;
      final scoreB = matchScores[b] ?? 0;
      return scoreB.compareTo(scoreA);
    });
    
    return matches;
  }

  /// Extrae palabras clave relevantes del mensaje del usuario
  List<String> _extractKeywords(String message) {
    final keywords = <String>[];
    
    // Palabras clave relacionadas con trámites comunes
    // IMPORTANTE: Para vehículos, priorizar ANT sobre otras oficinas
    final tramiteKeywords = {
      // Trámites de vehículos - PRIORIDAD ALTA para ANT
      'carro': ['ant', 'agencia nacional de tránsito', 'tránsito', 'vehículo', 'automotor', 'matrícula', 'licencia'],
      'auto': ['ant', 'agencia nacional de tránsito', 'tránsito', 'vehículo', 'automotor', 'matrícula'],
      'vehículo': ['ant', 'agencia nacional de tránsito', 'tránsito', 'automotor'],
      'moto': ['ant', 'agencia nacional de tránsito', 'tránsito', 'vehículo', 'automotor'],
      'licencia': ['ant', 'agencia nacional de tránsito', 'tránsito', 'conducir'],
      'matrícula': ['ant', 'agencia nacional de tránsito', 'tránsito', 'vehículo', 'automotor'],
      'trámite': ['ant', 'agencia nacional de tránsito'], // Contexto adicional
      
      // Trámites de identidad
      'cédula': ['registro civil', 'identidad'],
      'pasaporte': ['migración', 'extranjería'],
      
      // Trámites de impuestos
      'impuesto': ['sri', 'servicio de rentas internas', 'tributario', 'fiscal', 'rentas'],
      'tributario': ['sri', 'servicio de rentas internas'],
      
      // Trámites de trabajo
      'trabajo': ['ministerio trabajo', 'relaciones laborales', 'laboral'],
      'laboral': ['ministerio trabajo', 'relaciones laborales'],
      
      // Trámites de salud y educación
      'salud': ['ministerio salud', 'salud pública'],
      'educación': ['ministerio educación', 'educación'],
      
      // Términos relacionados con territorio y propiedad - NO incluir para vehículos
      'territorio': ['territorial', 'gestión territorial', 'municipio', 'gobierno provincial', 'gad', 'catastro', 'predio'],
      'territorial': ['territorio', 'gestión territorial', 'municipio', 'gobierno provincial', 'gad', 'catastro'],
      'propiedad': ['catastro', 'municipio', 'territorio', 'predio', 'lote', 'terreno'],
      'casa': ['catastro', 'municipio', 'territorio', 'predio', 'lote', 'terreno', 'propiedad'],
      'terreno': ['catastro', 'municipio', 'territorio', 'predio', 'lote', 'propiedad'],
      'lote': ['catastro', 'municipio', 'territorio', 'predio', 'terreno', 'propiedad'],
      'predio': ['catastro', 'municipio', 'territorio', 'lote', 'terreno', 'propiedad'],
      'catastro': ['municipio', 'territorio', 'predio', 'lote', 'terreno', 'propiedad'],
      'información': ['municipio', 'gobierno provincial', 'gad', 'gestión'],
    };
    
    for (final entry in tramiteKeywords.entries) {
      if (message.contains(entry.key)) {
        keywords.addAll(entry.value);
      }
    }
    
    // Agregar palabras del mensaje que puedan ser relevantes
    final words = message.split(' ');
    for (final word in words) {
      if (word.length > 4) {
        keywords.add(word);
      }
    }
    
    return keywords;
  }

  /// Respuesta de fallback cuando no se puede conectar con la API
  String _getFallbackResponse(
    String userMessage,
    List<OfficeLocation> offices, {
    geo.Position? userLocation,
  }) {
    final matchingOffices = searchOfficesByKeywords(userMessage, offices);
    
    if (matchingOffices.isEmpty) {
      return '''
🤖 **Asistente de Trámites**

No encontré oficinas específicas registradas para tu consulta: "$userMessage"

💡 **Sugerencias:**
• Verifica que el trámite esté relacionado con oficinas gubernamentales
• Intenta usar términos más específicos (ej: "trámite de vehículo", "licencia de conducir", "información territorial")
• Revisa la lista completa de oficinas en el mapa

Si necesitas ayuda con un trámite específico, describe mejor qué necesitas hacer.
''';
    }

    // Calcular distancias si hay ubicación
    final officesWithDistance = matchingOffices.map((office) {
      double? distanceInKm;
      if (userLocation != null) {
        final distanceInMeters = geo.Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          office.latitude,
          office.longitude,
        );
        distanceInKm = distanceInMeters / 1000.0;
      }
      return {
        'office': office,
        'distance': distanceInKm,
      };
    }).toList();

    // Ordenar por distancia si hay ubicación
    if (userLocation != null) {
      officesWithDistance.sort((a, b) {
        final distA = a['distance'] as double? ?? double.infinity;
        final distB = b['distance'] as double? ?? double.infinity;
        return distA.compareTo(distB);
      });
    }
    
    if (matchingOffices.isNotEmpty) {
      // Crear lista detallada de todas las oficinas encontradas con distancias
      final officesList = officesWithDistance.map((item) {
        final o = item['office'] as OfficeLocation;
        final distance = item['distance'] as double?;
        final desc = o.description.isNotEmpty ? o.description.split('\n').first : '';
        String distanceText = '';
        if (distance != null) {
          if (distance < 1) {
            distanceText = ' (${(distance * 1000).toStringAsFixed(0)} m de distancia)';
          } else {
            distanceText = ' (${distance.toStringAsFixed(1)} km de distancia)';
          }
        }
        return '• **${o.name}**${desc.isNotEmpty ? ' - $desc' : ''}$distanceText';
      }).join('\n\n');
      
      // Determinar tipo de trámite para dar información más específica
      final lowerMessage = userMessage.toLowerCase();
      String tramiteInfo = 'Basándome en tu consulta, estas son las oficinas que podrían ayudarte con tu trámite.';
      
      if (lowerMessage.contains('territorio') || lowerMessage.contains('casa') || 
          lowerMessage.contains('terreno') || lowerMessage.contains('lote') ||
          lowerMessage.contains('propiedad') || lowerMessage.contains('predio')) {
        tramiteInfo = 'Para consultas sobre territorio, propiedad, catastro o información territorial, puedes acudir tanto a los municipios como a los GADs (Gobiernos Autónomos Descentralizados), ya que ambos manejan gestión territorial.';
      }
      
      return '''
🏛️ **Oficinas Recomendadas:**
$officesList

📋 **Información del Trámite:**
$tramiteInfo

📄 **Documentos Comunes Necesarios:**
• Cédula de identidad
• Documentos relacionados con tu consulta
• Comprobantes adicionales según el trámite específico

💡 **Recomendaciones:**
• Verifica el horario de atención de cada oficina antes de acudir
• Reúne todos los documentos necesarios
• Considera hacer una cita previa si es posible
• Si hay múltiples opciones (municipio y GAD), puedes consultar en ambas para obtener información completa

Para más información específica sobre el trámite, te recomiendo contactar directamente con las oficinas mencionadas.
''';
    } else {
      return '''
🤖 **Asistente de Trámites**

No encontré oficinas específicas registradas para tu consulta: "$userMessage"

💡 **Sugerencias:**
• Verifica que el trámite esté relacionado con oficinas gubernamentales
• Intenta usar términos más específicos (ej: "trámite de vehículo", "licencia de conducir", "información territorial")
• Revisa la lista completa de oficinas en el mapa

Si necesitas ayuda con un trámite específico, describe mejor qué necesitas hacer.
''';
    }
  }
}

