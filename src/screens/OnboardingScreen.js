import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function OnboardingScreen({ onFinish }) {
  const [step, setStep] = useState(0);

  const slides = [
    {
      icon: 'pulse',
      color: SENSE_COLORS.electricBlue,
      title: 'Welcome to SENSE',
      sub: 'Personalized Well-being Pattern Research',
      desc: 'SENSE helps you observe subtle longitudinal shifts in your personal stress resilience across emotional, behavioral, and lifestyle channels.',
    },
    {
      icon: 'shield-checkmark',
      color: SENSE_COLORS.cyan,
      title: 'Strict Non-Clinical Boundary',
      sub: 'Self-Reflection Mirror, Not Diagnosis',
      desc: 'SENSE does not diagnose anxiety, clinical depression, or medical conditions. It serves solely as an observational self-reflection research tool.',
    },
    {
      icon: 'lock-closed',
      color: SENSE_COLORS.calm,
      title: 'Edge Privacy & Consent',
      sub: 'DPDP Act 2023 Compliant',
      desc: 'All 6 input modalities are strictly voluntary. Your data is encrypted on this device and your personal baselines never leave your phone without explicit consent.',
    },
  ];

  const currentSlide = slides[step];

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        {/* Progress indicator */}
        <View style={styles.progressRow}>
          {slides.map((_, i) => (
            <View
              key={i}
              style={[
                styles.progressDot,
                step === i ? styles.progressDotActive : null,
              ]}
            />
          ))}
        </View>

        {/* Icon Circle */}
        <View style={[styles.iconCircle, { backgroundColor: `${currentSlide.color}15` }]}>
          <Ionicons name={currentSlide.icon} size={48} color={currentSlide.color} />
        </View>

        <Text style={styles.title}>{currentSlide.title}</Text>
        <Text style={styles.subtitle}>{currentSlide.sub}</Text>
        <Text style={styles.desc}>{currentSlide.desc}</Text>
      </View>

      {/* Buttons */}
      <View style={styles.footer}>
        {step < slides.length - 1 ? (
          <TouchableOpacity
            style={styles.nextBtn}
            onPress={() => setStep(step + 1)}
            activeOpacity={0.85}
          >
            <LinearGradient
              colors={SENSE_COLORS.primaryGradient}
              style={styles.btnGradient}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 0 }}
            >
              <Text style={styles.btnText}>Next →</Text>
            </LinearGradient>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity
            style={styles.nextBtn}
            onPress={onFinish}
            activeOpacity={0.85}
          >
            <LinearGradient
              colors={SENSE_COLORS.primaryGradient}
              style={styles.btnGradient}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 0 }}
            >
              <Text style={styles.btnText}>Agree & Begin SENSE</Text>
            </LinearGradient>
          </TouchableOpacity>
        )}

        {step < slides.length - 1 && (
          <TouchableOpacity onPress={onFinish} style={styles.skipBtn}>
            <Text style={styles.skipText}>Skip directly to Home</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: SENSE_COLORS.background,
    justifyContent: 'space-between',
    padding: SENSE_SPACING.xl,
  },
  content: {
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
  },
  progressRow: {
    flexDirection: 'row',
    marginBottom: 40,
  },
  progressDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#C5DCED',
    marginHorizontal: 4,
  },
  progressDotActive: {
    width: 24,
    backgroundColor: SENSE_COLORS.electricBlue,
  },
  iconCircle: {
    width: 100,
    height: 100,
    borderRadius: 50,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 24,
    ...SENSE_SHADOWS.raised,
  },
  title: {
    fontSize: 24,
    fontWeight: '800',
    color: SENSE_COLORS.textPrimary,
    textAlign: 'center',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 13,
    fontWeight: '700',
    color: SENSE_COLORS.electricBlue,
    textAlign: 'center',
    marginBottom: 16,
  },
  desc: {
    fontSize: 13,
    color: SENSE_COLORS.textSecondary,
    textAlign: 'center',
    lineHeight: 22,
    paddingHorizontal: 16,
  },
  footer: {
    width: '100%',
    paddingBottom: 20,
  },
  nextBtn: {
    borderRadius: SENSE_RADII.lg,
    overflow: 'hidden',
    ...SENSE_SHADOWS.raised,
  },
  btnGradient: {
    paddingVertical: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  btnText: {
    fontSize: 15,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  skipBtn: {
    marginTop: 12,
    alignItems: 'center',
    paddingVertical: 6,
  },
  skipText: {
    fontSize: 12,
    fontWeight: '600',
    color: SENSE_COLORS.textMuted,
  },
});

