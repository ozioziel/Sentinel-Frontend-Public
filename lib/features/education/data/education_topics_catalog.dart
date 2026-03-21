import 'package:flutter/material.dart';

import '../../../core/localization/app_language_service.dart';
import '../domain/models/education_story_panel.dart';
import '../domain/models/education_topic.dart';

class EducationTopicsCatalog {
  static List<EducationTopic> get topics {
    final l10n = AppLanguageService.instance;
    String t(String es, String en) => l10n.pick(es: es, en: en);

    return [
      EducationTopic(
        id: 'violencia-sexual',
        icon: Icons.gpp_maybe_rounded,
        color: const Color(0xFFD63864),
        title: t('Violencia Sexual', 'Sexual Violence'),
        description: t(
          'Aprende que es la violencia sexual, como reconocerla y por que nunca es culpa de la victima.',
          'Learn what sexual violence is, how to recognize it, and why it is never the victim\'s fault.',
        ),
        tag: t('Prioritario', 'Priority'),
        storyPanels: const [
          EducationStoryPanel(
            eyebrow: 'Infografia 01',
            title: 'Que es la violencia sexual',
            caption:
                'Esta infografia explica de forma visual que es la violencia sexual y ayuda a identificar conductas que no deben normalizarse.',
            bubbleText: 'Reconocerla es el primer paso para pedir ayuda.',
            footer:
                'Imagen cargada desde assets/images/infografias/que es la violencia sexual.jpeg.',
            icon: Icons.info_outline_rounded,
            color: Color(0xFFD63864),
            imageAssetPath:
                'assets/images/infografias/que es la violencia sexual.jpeg',
            imageSemanticLabel: 'Infografia sobre que es la violencia sexual',
          ),
        ],
        textBlocks: [
          t(
            'La violencia sexual ocurre cuando una persona es forzada, presionada, manipulada o tocada sin su consentimiento. Puede pasar con agresiones fisicas, amenazas, chantaje o aprovechando una situacion de vulnerabilidad.',
            'Sexual violence happens when a person is forced, pressured, manipulated, or touched without consent. It can involve physical aggression, threats, coercion, or taking advantage of vulnerability.',
          ),
          t(
            'El consentimiento debe ser libre, claro e informado, y puede retirarse en cualquier momento. El miedo, el silencio o la presion no significan que alguien acepto.',
            'Consent must be free, clear, and informed, and it can be withdrawn at any time. Fear, silence, or pressure do not mean someone agreed.',
          ),
          t(
            'Si esto te ocurre a ti o a alguien cercano, buscar apoyo en una persona de confianza o en un servicio especializado puede ayudar a tomar decisiones con mas seguridad.',
            'If this happens to you or someone close to you, seeking support from a trusted person or a specialized service can help you make safer decisions.',
          ),
        ],
      ),
      EducationTopic(
        id: 'tipos-de-violencia',
        icon: Icons.fact_check_rounded,
        color: const Color(0xFF8E44AD),
        title: t('Tipos de Violencia', 'Types of Violence'),
        description: t(
          'Revisa las distintas formas en las que puede presentarse la violencia sexual para identificar senales de alerta.',
          'Review the different ways sexual violence can appear so warning signs are easier to identify.',
        ),
        tag: t('Clave', 'Key'),
        storyPanels: const [
          EducationStoryPanel(
            eyebrow: 'Infografia 02',
            title: 'Tipos de violencia sexual',
            caption:
                'La infografia resume distintas manifestaciones de la violencia sexual para reconocer que no todas se presentan de la misma manera.',
            bubbleText:
                'La violencia puede verse distinta, pero sigue siendo violencia.',
            footer:
                'Imagen cargada desde assets/images/infografias/tipos de violencia sexual.jpeg.',
            icon: Icons.auto_stories_rounded,
            color: Color(0xFF8E44AD),
            imageAssetPath:
                'assets/images/infografias/tipos de violencia sexual.jpeg',
            imageSemanticLabel: 'Infografia sobre tipos de violencia sexual',
          ),
        ],
        textBlocks: [
          t(
            'La violencia sexual no siempre se presenta igual. Puede incluir acoso, insinuaciones no deseadas, tocamientos sin permiso, coercion, abuso o cualquier accion sexual impuesta.',
            'Sexual violence does not always look the same. It can include harassment, unwanted sexual comments, non-consensual touching, coercion, abuse, or any imposed sexual act.',
          ),
          t(
            'Identificar los tipos de violencia ayuda a poner limites, buscar apoyo antes y entender que una situacion no deja de ser grave solo porque no se parece a otras.',
            'Identifying different forms of violence helps set boundaries, seek support earlier, and understand that a situation is still serious even if it looks different from others.',
          ),
          t(
            'Hablar del tema con informacion clara permite detectar riesgos, acompanar mejor a otras personas y actuar con mas cuidado frente a una senal de alerta.',
            'Talking about this clearly helps detect risks, support others better, and respond more carefully when warning signs appear.',
          ),
        ],
      ),
    ];
  }
}
