/// Crisis Safety Service.
/// Implements decoupled emergency helpline access and client-side journal keyword interceptor.
class CrisisHelpline {
  final String name;
  final String phoneNumber;
  final String description;
  final bool is24x7;

  const CrisisHelpline({
    required this.name,
    required this.phoneNumber,
    required this.description,
    this.is24x7 = true,
  });
}

class CrisisService {
  /// Regular expression for detecting overt self-harm or suicidal expressions in reflective text
  static final RegExp _crisisPattern = RegExp(
    r'\b(suicide|kill myself|end my life|want to die|hang myself|slit my wrist|take all my pills|no reason to live)\b',
    caseSensitive: false,
  );

  /// Returns true if the provided text contains acute distress or self-harm keywords
  static bool containsCrisisMarkers(String text) {
    if (text.trim().isEmpty) return false;
    return _crisisPattern.hasMatch(text);
  }

  /// Verified list of Indian and international national support helplines
  static const List<CrisisHelpline> helplines = [
    CrisisHelpline(
      name: 'Tele-MANAS (Govt. of India)',
      phoneNumber: '14416',
      description: 'Comprehensive, 24/7, free, confidential mental health tele-counseling across 20+ languages.',
      is24x7: true,
    ),
    CrisisHelpline(
      name: 'Tele-MANAS (Toll-Free Alternate)',
      phoneNumber: '1800-891-4416',
      description: 'National toll-free tele-mental health support.',
      is24x7: true,
    ),
    CrisisHelpline(
      name: 'KIRAN Helpline (Dept. of Empowerment)',
      phoneNumber: '1800-599-0019',
      description: '24/7 national mental health rehabilitation and early screening helpline.',
      is24x7: true,
    ),
    CrisisHelpline(
      name: 'Vandrevala Foundation Helpline',
      phoneNumber: '+919999666555',
      description: 'Free 24/7 psychological counseling and crisis intervention.',
      is24x7: true,
    ),
    CrisisHelpline(
      name: 'AASRA Suicide Prevention',
      phoneNumber: '+919820466726',
      description: 'Crisis intervention and suicide prevention helpline.',
      is24x7: true,
    ),
  ];
}

