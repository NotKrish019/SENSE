// SENSE Design System Tokens — Authoritative from design.md & Toolkit Board

export const SENSE_COLORS = {
  // Brand Anchors
  navy: '#012F5F',          // Deep ocean navy
  secondaryBlue: '#02549B', // Secondary ocean blue
  electricBlue: '#059BE0',  // Primary interactive blue
  cyan: '#07CCFC',          // Primary cyan accent
  softCyan: '#58E2F9',      // Pale cyan highlight
  
  // Surfaces & Backgrounds
  background: '#E6F6FF',    // Pale icy-blue canvas
  surface: '#F4F7F7',       // Soft off-white neumorphic card surface
  white: '#FFFFFF',         // Pure white
  border: '#D6E7F2',        // Delicate card border
  
  // Typography
  textPrimary: '#082B52',   // Deep navy primary text
  textSecondary: '#496784', // Slate secondary text
  textMuted: '#607B93',     // Muted caption text
  
  // Semantic Status
  calm: '#087F6E',          // Low/calm green
  moderate: '#9A5B00',      // Moderate amber
  elevated: '#B42332',      // Elevated coral red
  
  // Gradients (tuples for expo-linear-gradient)
  heroGradient: ['#02549B', '#012F5F'],
  primaryGradient: ['#059BE0', '#07CCFC'],
  accentGradient: ['#07CCFC', '#58E2F9'],
  progressGradient: ['#059BE0', '#58E2F9'],
};

export const SENSE_SHADOWS = {
  // Neumorphic card dual-shadow simulation for React Native
  card: {
    shadowColor: '#012F5F',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.08,
    shadowRadius: 10,
    elevation: 3,
  },
  raised: {
    shadowColor: '#012F5F',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.12,
    shadowRadius: 14,
    elevation: 5,
  },
  hero: {
    shadowColor: '#012F5F',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.22,
    shadowRadius: 18,
    elevation: 7,
  },
  glow: {
    shadowColor: '#07CCFC',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.35,
    shadowRadius: 10,
    elevation: 4,
  },
};

export const SENSE_SPACING = {
  xs: 4,
  sm: 8,
  md: 12,
  base: 16,
  lg: 20,
  xl: 24,
  xxl: 32,
  xxxl: 48,
};

export const SENSE_RADII = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 22,
  pill: 999,
};

