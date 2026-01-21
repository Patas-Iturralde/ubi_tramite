import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/office_location.dart';

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
  Future<String> findOfficesForTransaction(String userMessage, List<OfficeLocation> offices) async {
    try {
      // Crear lista de oficinas disponibles para el prompt
      final officesList = offices.map((office) {
        return '• ${office.name} - ${office.description}${office.schedule != null ? " (Horario: ${office.schedule})" : ""}';
      }).join('\n');

      final prompt = '''
Eres un asistente especializado en ayudar a los usuarios a encontrar oficinas gubernamentales para realizar trámites en Ecuador.

El usuario quiere realizar el siguiente trámite o consulta:
"$userMessage"

OFICINAS DISPONIBLES EN EL SISTEMA:
$officesList

INSTRUCCIONES CRÍTICAS - LEE CON ATENCIÓN:
1. **DEBES BUSCAR Y LISTAR TODAS LAS OFICINAS RELACIONADAS**, no solo una. Si hay múltiples opciones, menciónalas todas.
2. ANALIZA PROFUNDAMENTE las descripciones de CADA oficina en la lista, no solo el nombre
3. Busca términos relacionados y sinónimos en las descripciones:
   - "territorio", "territorial", "propiedad", "catastro", "lote", "casa", "terreno", "predio" → Busca TODAS las oficinas con "gestión territorial", "catastro", "municipio", "gobierno provincial", "GAD" en su descripción
   - "vehículo", "carro", "auto", "matrícula" → Busca "ANT", "tránsito", "automotor"
   - "cédula", "identidad" → Busca "registro civil"
   - "trabajo", "laboral", "despido" → Busca "ministerio trabajo", "relaciones laborales"
   - "impuesto", "tributario" → Busca "SRI", "rentas internas"
4. **ESPECIALMENTE IMPORTANTE**: Si el usuario pregunta sobre "territorio", "propiedad", "casa", "terreno", "lote", "información territorial", DEBES buscar y listar TODAS las oficinas que mencionen:
   - "gestión territorial" (incluye municipios y GADs)
   - "municipio" (los municipios manejan catastro y territorio)
   - "gobierno provincial" o "GAD" (manejan gestión territorial)
   - "catastro"
   - Cualquier referencia a territorio, predios, o gestión territorial
5. **NO TE LIMITES A UNA SOLA OFICINA**. Si encuentras un municipio Y un GAD relacionados, menciónalos AMBOS.
6. Identifica TODAS las oficinas de la lista que estén relacionadas con ese trámite, incluso si la relación es indirecta
7. Si encuentras múltiples oficinas relacionadas, menciónalas TODAS específicamente por su nombre completo
8. Proporciona información útil sobre el trámite basándote en las descripciones de las oficinas encontradas
9. Si no encuentras una oficina exacta, sugiere TODAS las más cercanas o relacionadas según las descripciones
10. Sé específico y práctico, usa la información de las descripciones

FORMATO DE RESPUESTA:

🏛️ **Oficinas Recomendadas:**
[IMPORTANTE: Lista TODAS las oficinas encontradas, no solo una. Si hay múltiples opciones (ej: municipio y GAD), menciónalas todas. Para cada oficina, incluye su nombre completo y explica brevemente por qué es relevante según su descripción]

📋 **Información del Trámite:**
[Explica brevemente qué se necesita para este trámite, basándote en las descripciones de las oficinas encontradas]

📄 **Documentos Comunes Necesarios:**
• [Documento 1]
• [Documento 2]
• [Documento 3]

💡 **Recomendaciones:**
[Consejos útiles para realizar el trámite]

IMPORTANTE CRÍTICO: 
- Si encuentras oficinas relacionadas aunque no sea una coincidencia exacta, menciónalas TODAS
- Si el usuario pregunta sobre "territorio", "casa", "propiedad", etc., busca y lista TODAS las oficinas con "gestión territorial", "municipio", "GAD", "gobierno provincial" en sus descripciones
- NO te limites a una sola oficina. Si hay un municipio Y un GAD relacionados, menciónalos AMBOS
- Revisa CADA oficina de la lista y si su descripción tiene alguna relación, inclúyela

Máximo 400 palabras. Sé claro, conciso y útil. Lista TODAS las opciones disponibles.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!;
      } else {
        return _getFallbackResponse(userMessage, offices);
      }
    } catch (e) {
      print('Error al buscar oficinas: $e');
      return _getFallbackResponse(userMessage, offices);
    }
  }

  /// Busca oficinas específicas basándose en palabras clave
  List<OfficeLocation> searchOfficesByKeywords(String query, List<OfficeLocation> offices) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    final keywords = _extractKeywords(lowerQuery);
    
    final matches = <OfficeLocation>[];
    final matchScores = <OfficeLocation, int>{};
    
    for (final office in offices) {
      final officeName = office.name.toLowerCase();
      final officeDesc = office.description.toLowerCase();
      int score = 0;
      
      // Buscar coincidencias por palabras clave
      for (final keyword in keywords) {
        // Coincidencia en el nombre (mayor peso)
        if (officeName.contains(keyword)) {
          score += 3;
        }
        // Coincidencia en la descripción (peso medio)
        if (officeDesc.contains(keyword)) {
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
    final tramiteKeywords = {
      'carro': ['tránsito', 'ant', 'vehículo', 'automotor', 'matrícula', 'licencia'],
      'vehículo': ['tránsito', 'ant', 'automotor', 'matrícula'],
      'licencia': ['tránsito', 'ant', 'conducir'],
      'cédula': ['registro civil', 'identidad'],
      'pasaporte': ['migración', 'extranjería'],
      'impuesto': ['sri', 'tributario', 'fiscal'],
      'trabajo': ['ministerio trabajo', 'laboral', 'relaciones laborales'],
      'salud': ['ministerio salud', 'salud pública'],
      'educación': ['ministerio educación', 'educación'],
      // Términos relacionados con territorio y propiedad
      'territorio': ['territorial', 'gestión territorial', 'municipio', 'gobierno provincial', 'catastro', 'predio'],
      'territorial': ['territorio', 'gestión territorial', 'municipio', 'gobierno provincial', 'catastro'],
      'propiedad': ['catastro', 'municipio', 'territorio', 'predio', 'lote', 'terreno'],
      'casa': ['catastro', 'municipio', 'territorio', 'predio', 'lote', 'terreno', 'propiedad'],
      'terreno': ['catastro', 'municipio', 'territorio', 'predio', 'lote', 'propiedad'],
      'lote': ['catastro', 'municipio', 'territorio', 'predio', 'terreno', 'propiedad'],
      'predio': ['catastro', 'municipio', 'territorio', 'lote', 'terreno', 'propiedad'],
      'catastro': ['municipio', 'territorio', 'predio', 'lote', 'terreno', 'propiedad'],
      'información': ['municipio', 'gobierno provincial', 'gestión'],
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
  String _getFallbackResponse(String userMessage, List<OfficeLocation> offices) {
    final matchingOffices = searchOfficesByKeywords(userMessage, offices);
    
    if (matchingOffices.isNotEmpty) {
      // Crear lista detallada de todas las oficinas encontradas
      final officesList = matchingOffices.map((o) {
        final desc = o.description.isNotEmpty ? o.description.split('\n').first : '';
        return '• **${o.name}**${desc.isNotEmpty ? ' - $desc' : ''}';
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

