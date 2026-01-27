import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/office_location.dart';
import '../models/tramite.dart';

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

  /// Extrae palabras clave relevantes y específicas de la consulta del usuario
  List<String> _extractRelevantKeywords(String message) {
    final keywords = <String>[];
    
    // Palabras clave específicas de trámites comunes
    final specificKeywords = {
      'matrimonio': ['matrimonio', 'casarse', 'casamiento', 'unión'],
      'acta de nacimiento': ['nacimiento', 'acta nacimiento', 'certificado nacimiento'],
      'acta nacimiento': ['nacimiento', 'acta nacimiento', 'certificado nacimiento'],
      'nacimiento': ['nacimiento', 'acta nacimiento'],
      'cédula': ['cédula', 'identidad', 'ci'],
      'pasaporte': ['pasaporte'],
      'visa': ['visa'],
      'licencia conducir': ['licencia', 'conducir', 'conductor'],
      'matrícula': ['matrícula', 'vehículo', 'auto', 'carro'],
      'catastro': ['catastro', 'predio', 'terreno'],
      'impuesto': ['impuesto', 'tributario', 'renta'],
    };
    
    // Buscar coincidencias específicas primero
    for (final entry in specificKeywords.entries) {
      if (message.contains(entry.key)) {
        keywords.addAll(entry.value);
        break; // Solo usar la primera coincidencia específica
      }
    }
    
    // Extraer palabras importantes del mensaje (verbos y sustantivos)
    final words = message.split(' ')
        .where((w) => w.length > 4)
        .where((w) => !_isStopWord(w))
        .toList();
    
    keywords.addAll(words);
    
    return keywords.toSet().toList(); // Eliminar duplicados
  }
  
  /// Verifica si una palabra es una palabra de parada (stop word)
  bool _isStopWord(String word) {
    final stopWords = {
      'donde', 'puedo', 'puede', 'como', 'que', 'para', 'con', 'por', 'de', 'la', 'el', 'los', 'las',
      'mi', 'tu', 'su', 'nuestro', 'este', 'ese', 'aqui', 'alli', 'cuando', 'porque',
      'obtener', 'sacar', 'conseguir', 'realizar', 'hacer', 'tramitar', 'registrar',
    };
    return stopWords.contains(word.toLowerCase());
  }
  
  /// Calcula un score de coincidencia entre la consulta del usuario y un trámite
  int _calculateTramiteMatchScore(String userQuery, List<String> keywords, String tramiteName) {
    int score = 0;
    final lowerTramite = tramiteName.toLowerCase();
    final lowerQuery = userQuery.toLowerCase();
    
    // Normalizar la consulta para extraer el concepto principal
    final queryWords = lowerQuery.split(' ').where((w) => w.length > 3 && !_isStopWord(w)).toList();
    final tramiteWords = lowerTramite.split(' ').where((w) => w.length > 3).toList();
    
    // Coincidencia exacta del query completo (score muy alto)
    if (lowerTramite.contains(lowerQuery) || lowerQuery.contains(lowerTramite)) {
      score += 100;
    }
    
    // Coincidencia de todas las palabras clave importantes
    int matchingKeywords = 0;
    for (final keyword in keywords) {
      final lowerKeyword = keyword.toLowerCase();
      if (lowerTramite.contains(lowerKeyword)) {
        matchingKeywords++;
        // Coincidencia exacta de palabra clave completa (mayor peso)
        if (lowerTramite.contains(' $lowerKeyword ') || 
            lowerTramite.startsWith('$lowerKeyword ') ||
            lowerTramite.endsWith(' $lowerKeyword')) {
          score += 30;
        } else {
          score += 15;
        }
      }
    }
    
    // Bonus si coinciden múltiples palabras clave
    if (matchingKeywords >= 2) {
      score += 20;
    }
    
    // Coincidencia de palabras individuales importantes de la consulta
    for (final queryWord in queryWords) {
      if (tramiteWords.contains(queryWord)) {
        score += 10;
      } else if (lowerTramite.contains(queryWord)) {
        score += 5;
      }
    }
    
    // Matching semántico mejorado para casos específicos
    final semanticMatches = {
      'matrimonio': ['matrimonio', 'casarse', 'casamiento', 'unión de hecho', 'registro matrimonio'],
      'acta de nacimiento': ['acta nacimiento', 'certificado nacimiento', 'copia acta nacimiento', 'emisión copia acta registral: nacimiento'],
      'acta nacimiento': ['acta nacimiento', 'certificado nacimiento', 'copia acta nacimiento', 'emisión copia acta registral: nacimiento'],
      'nacimiento': ['nacimiento', 'acta nacimiento', 'certificado nacimiento'],
      'cédula': ['cédula', 'identidad', 'emisión cédula', 'renovación cédula'],
      'pasaporte': ['pasaporte', 'emisión pasaporte'],
      'licencia': ['licencia', 'conducir', 'licencia conducir'],
      'matrícula': ['matrícula', 'vehículo', 'automotor'],
    };
    
    for (final entry in semanticMatches.entries) {
      if (lowerQuery.contains(entry.key)) {
        for (final match in entry.value) {
          if (lowerTramite.contains(match)) {
            score += 25; // Bonus alto por matching semántico
          }
        }
      }
    }
    
    // Penalizar coincidencias parciales que pueden ser falsos positivos
    final falsePositives = {
      'matrimonio': ['matrícula', 'matricula', 'calificación'],
      'matrícula': ['matrimonio'],
      'nacimiento': ['filiación', 'reconocimiento', 'actualización filiación'],
      'acta': ['actualización', 'rectificación', 'modificación'],
      'registrar': ['calificación', 'artesanal'],
    };
    
    for (final entry in falsePositives.entries) {
      if (lowerQuery.contains(entry.key)) {
        for (final falsePositive in entry.value) {
          if (lowerTramite.contains(falsePositive)) {
            score -= 50; // Penalización muy fuerte
          }
        }
      }
    }
    
    return score;
  }

  /// Busca oficinas relacionadas con el trámite mencionado por el usuario
  Future<OfficeSearchResult> findOfficesForTransaction(
    String userMessage,
    List<OfficeLocation> offices, {
    geo.Position? userLocation,
  }) async {
    try {
      // PRIMERO: Extraer palabras clave relevantes de la consulta del usuario
      final lowerMessage = userMessage.toLowerCase();
      final queryKeywords = _extractRelevantKeywords(lowerMessage);
      
      // Buscar oficinas con coincidencias EXACTAS en trámites usando scoring
      final officesWithTramite = <Map<String, dynamic>>[];
      final otherOffices = <OfficeLocation>[];
      
      for (final office in offices) {
        Tramite? bestMatchingTramite;
        int bestScore = 0;
        
        for (final tramite in office.tramites) {
          final score = _calculateTramiteMatchScore(
            lowerMessage,
            queryKeywords,
            tramite.nombre.toLowerCase(),
          );
          
          if (score > bestScore) {
            bestScore = score;
            bestMatchingTramite = tramite;
          }
        }
        
        // Solo incluir oficinas con un score suficientemente alto (trámite realmente relevante)
        // El sistema ya analizó TODOS los trámites y encontró el mejor match
        if (bestMatchingTramite != null && bestScore >= 15) {
          officesWithTramite.add({
            'office': office,
            'tramite': bestMatchingTramite,
            'score': bestScore,
          });
        } else {
          otherOffices.add(office);
        }
      }
      
      // Ordenar por score (mayor a menor)
      officesWithTramite.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      
      // Si encontramos oficinas con el trámite específico, usar solo esas
      final officesToUse = officesWithTramite.isNotEmpty 
          ? officesWithTramite.map((item) => item['office'] as OfficeLocation).toList()
          : otherOffices;
      
      // Calcular distancias si hay ubicación del usuario
      final officesWithDistance = <Map<String, dynamic>>[];
      for (final office in officesToUse) {
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
        
        // Encontrar el trámite matching para esta oficina
        final matchingItem = officesWithTramite.firstWhere(
          (item) => item['office'] == office,
          orElse: () => <String, dynamic>{},
        );
        
        officesWithDistance.add({
          'office': office,
          'distance': distanceInKm,
          'hasTramite': officesWithTramite.isNotEmpty,
          'matchingTramite': matchingItem['tramite'] as Tramite?,
          'score': matchingItem['score'] as int? ?? 0,
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

      // Analizar todos los trámites internamente y seleccionar solo el mejor para mostrar
      final officesList = officesWithDistance.map((item) {
        final office = item['office'] as OfficeLocation;
        final distance = item['distance'] as double?;
        final matchingTramite = item['matchingTramite'] as Tramite?;
        final score = item['score'] as int? ?? 0;
        String distanceText = '';
        if (distance != null) {
          if (distance < 1) {
            distanceText = ' (${(distance * 1000).toStringAsFixed(0)} m de distancia)';
          } else {
            distanceText = ' (${distance.toStringAsFixed(1)} km de distancia)';
          }
        }
        
        // Solo mostrar el trámite que mejor coincide (ya fue analizado internamente)
        String tramiteInfo = '';
        if (matchingTramite != null && score > 0) {
          tramiteInfo = '\n  📋 Trámite: ${matchingTramite.nombre}';
          if (matchingTramite.costo != null && matchingTramite.costo!.isNotEmpty) {
            tramiteInfo += '\n  💰 Costo: ${matchingTramite.costo}';
          }
          if (matchingTramite.requisitos.isNotEmpty) {
            tramiteInfo += '\n  📄 Requisitos:';
            for (final requisito in matchingTramite.requisitos) {
              tramiteInfo += '\n    • $requisito';
            }
          }
          if (matchingTramite.descripcion != null && matchingTramite.descripcion!.isNotEmpty) {
            tramiteInfo += '\n  ℹ️ Descripción: ${matchingTramite.descripcion}';
          }
        }
        
        String priorityMark = score >= 20 ? ' ⭐ RELEVANTE' : '';
        return '• ${office.name}$distanceText$priorityMark$tramiteInfo';
      }).join('\n\n');

      final prompt = '''
Eres un asistente especializado en ayudar a los usuarios a encontrar oficinas gubernamentales para realizar trámites en Ecuador.

El usuario quiere realizar el siguiente trámite o consulta:
"$userMessage"

OFICINAS DISPONIBLES EN EL SISTEMA:
$officesList

INSTRUCCIONES CRÍTICAS:

**IMPORTANTE: El sistema ya analizó todos los trámites disponibles y seleccionó el más relevante para cada oficina. Tu tarea es verificar que la selección sea correcta y presentar la información de forma clara.**

**PASO 1: VERIFICAR LA SELECCIÓN**
- Revisa que el trámite mostrado para cada oficina realmente coincida con la consulta del usuario
- Si el trámite mostrado NO es relevante, NO lo incluyas en tu respuesta
- Solo incluye oficinas que tengan trámites directamente relevantes

**PASO 2: PRESENTAR LA INFORMACIÓN**
- Muestra SOLO el trámite que ya está identificado (no busques otros)
- Usa la información de requisitos y costo que está proporcionada
- NO inventes información adicional

**PASO 3: FORMATO DE RESPUESTA**

🏛️ **Oficinas Recomendadas:**

Para cada oficina relevante, muestra:
- Nombre de la oficina
- Distancia (si está disponible)
- El trámite específico que está identificado
- Los requisitos del trámite (de la información proporcionada)
- El costo del trámite (de la información proporcionada)

Ejemplo:
• REGISTRO CIVIL - Primera Constituyente y Juan Montalvo (1.2 km)
  📋 Trámite: Emisión de copia del acta registral: nacimiento
  💰 Costo: [del trámite mostrado]
  📄 Requisitos:
    • [del trámite mostrado]

📋 **Información del Trámite:**
[Explica brevemente (1-2 líneas) qué es este trámite específico]

💡 **Recomendaciones:**
[2-3 consejos breves y útiles]

REGLAS ESTRICTAS:
- **Solo muestra el trámite que ya está identificado en la información proporcionada**
- **NO busques otros trámites, usa SOLO el que está listado**
- **NO inventes información: usa SOLO los datos proporcionados**
- **Si el trámite mostrado NO es relevante para la consulta, NO incluyas esa oficina**
- **Si NO hay trámites relevantes, di claramente que no hay trámites registrados para esa consulta**
- Máximo 200 palabras. Sé preciso y directo.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      // Obtener las oficinas encontradas (ordenadas por distancia si hay ubicación)
      // Priorizar oficinas que tienen el trámite específico con mejor score
      final foundOffices = officesWithDistance
          .where((item) => (item['score'] as int? ?? 0) >= 15)
          .map((item) => item['office'] as OfficeLocation)
          .toList();
      
      if (response.text != null && response.text!.isNotEmpty) {
        // Buscar oficinas mencionadas en la respuesta del AI
        final mentionedOffices = _extractOfficesFromResponse(response.text!, foundOffices);
        // Usar las oficinas mencionadas o las encontradas por score
        final finalOffices = mentionedOffices.isNotEmpty ? mentionedOffices : foundOffices;
        return OfficeSearchResult(
          response: response.text!,
          foundOffices: finalOffices,
        );
      } else {
        // Usar oficinas con trámite específico encontradas
        final fallbackResponse = _getFallbackResponse(userMessage, foundOffices, userLocation: userLocation);
        return OfficeSearchResult(
          response: fallbackResponse,
          foundOffices: foundOffices,
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
      final officeTramites = office.tramites.map((t) => t.nombre.toLowerCase()).toList();
      
      // PRIORIDAD: Buscar si algún trámite de la oficina aparece en la respuesta
      bool tramiteFound = false;
      for (final tramite in officeTramites) {
        if (lowerResponse.contains(tramite)) {
          foundOffices.add(office);
          tramiteFound = true;
          break;
        }
      }
      
      if (tramiteFound) continue;
      
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
      final officeTramites = office.tramites.map((t) => t.nombre.toLowerCase()).toList();
      int score = 0;
      
      // PRIORIDAD MÁXIMA: Buscar coincidencias en los trámites de la oficina
      for (final tramite in officeTramites) {
        for (final keyword in keywords) {
          if (tramite.contains(keyword) || keyword.contains(tramite)) {
            score += 15; // Puntuación muy alta para coincidencias en trámites
          }
        }
        // También buscar directamente en el query
        if (lowerQuery.contains(tramite) || tramite.contains(lowerQuery)) {
          score += 15;
        }
      }
      
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
          // Buscar también en los trámites
          for (final tramite in officeTramites) {
            if (tramite.contains(word) || word.contains(tramite)) {
              score += 3; // Puntuación alta para coincidencias directas en trámites
            }
          }
        }
      }
      
      // Buscar el query completo en los trámites (para casos como "visa", "pasaporte", etc.)
      for (final tramite in officeTramites) {
        if (tramite.contains(lowerQuery) || lowerQuery.contains(tramite)) {
          score += 20; // Puntuación muy alta para coincidencias exactas
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
      
      // Trámites de identidad y migración
      'cédula': ['registro civil', 'identidad'],
      'pasaporte': ['migración', 'extranjería'],
      'visa': ['migración', 'extranjería', 'visa', 'consulado'],
      'migración': ['migración', 'extranjería', 'visa', 'pasaporte'],
      'extranjería': ['migración', 'extranjería', 'visa'],
      
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
    // Primero buscar oficinas que tengan el trámite específico en su lista
    final lowerMessage = userMessage.toLowerCase();
    final messageWords = lowerMessage.split(' ').where((w) => w.length > 3).toList();
    
    final officesWithTramite = offices.where((office) {
      return office.tramites.any((tramite) {
        final lowerTramite = tramite.nombre.toLowerCase();
        return lowerTramite.contains(lowerMessage) || 
               lowerMessage.contains(lowerTramite) ||
               messageWords.any((word) => lowerTramite.contains(word));
      });
    }).toList();
    
    // Si encontramos oficinas con el trámite específico, usar solo esas
    final matchingOffices = officesWithTramite.isNotEmpty 
        ? officesWithTramite 
        : searchOfficesByKeywords(userMessage, offices);
    
    if (matchingOffices.isEmpty) {
      return '''
🤖 **Asistente de Trámites**

No encontré oficinas registradas que ofrezcan el trámite: "$userMessage"

💡 **Sugerencias:**
• Verifica que el trámite esté relacionado con oficinas gubernamentales
• Intenta usar términos más específicos (ej: "trámite de vehículo", "licencia de conducir", "visa", "pasaporte")
• Revisa la lista completa de oficinas y sus trámites disponibles en el mapa
• Es posible que este trámite no esté registrado en el sistema aún

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
      // Analizar todos los trámites internamente y seleccionar solo el mejor para mostrar
      final lowerMessage = userMessage.toLowerCase();
      final queryKeywords = _extractRelevantKeywords(lowerMessage);
      
      final officesList = officesWithDistance.map((item) {
        final o = item['office'] as OfficeLocation;
        final distance = item['distance'] as double?;
        String distanceText = '';
        if (distance != null) {
          if (distance < 1) {
            distanceText = ' (${(distance * 1000).toStringAsFixed(0)} m de distancia)';
          } else {
            distanceText = ' (${distance.toStringAsFixed(1)} km de distancia)';
          }
        }
        
        // Analizar TODOS los trámites internamente y encontrar el mejor
        Tramite? bestTramite;
        int bestScore = 0;
        for (final tramite in o.tramites) {
          final score = _calculateTramiteMatchScore(
            lowerMessage,
            queryKeywords,
            tramite.nombre.toLowerCase(),
          );
          if (score > bestScore) {
            bestScore = score;
            bestTramite = tramite;
          }
        }
        
        // Solo mostrar el trámite que mejor coincide (ya fue analizado internamente)
        String tramiteInfo = '';
        if (bestTramite != null && bestScore >= 15) {
          tramiteInfo = '\n  📋 Trámite: ${bestTramite.nombre}';
          if (bestTramite.costo != null && bestTramite.costo!.isNotEmpty) {
            tramiteInfo += '\n  💰 Costo: ${bestTramite.costo}';
          }
          if (bestTramite.requisitos.isNotEmpty) {
            tramiteInfo += '\n  📄 Requisitos:';
            for (final requisito in bestTramite.requisitos) {
              tramiteInfo += '\n    • $requisito';
            }
          }
          if (bestTramite.descripcion != null && bestTramite.descripcion!.isNotEmpty) {
            tramiteInfo += '\n  ℹ️ Descripción: ${bestTramite.descripcion}';
          }
        }
        
        return '• **${o.name}**$distanceText$tramiteInfo';
      }).join('\n\n');
      
      // Determinar tipo de trámite para dar información más específica
      String tramiteInfo = 'Basándome en tu consulta, estas son las oficinas que podrían ayudarte con tu trámite.';
      
      final lowerMsg = userMessage.toLowerCase();
      if (lowerMsg.contains('territorio') || lowerMsg.contains('casa') || 
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

