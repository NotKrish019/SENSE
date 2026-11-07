import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function LogHubScreen({ onNavigate }) {
  const modalities = [
    {
      key: 'check_in',
      title: 'M1: Mood & Perceived Stress',
      desc: '1-5 emotional valence and stress scale self-reports.',
      icon: 'happy-outline',
      color: SENSE_COLORS.electricBlue,
      status: 'Logged 2h ago',
    },
    {
      key: 'journal',
      title: 'M2: Reflective Journal',
      desc: 'Free-text diary with local encryption and crisis interceptor.',
      icon: 'create-outline',
      color: SENSE_COLORS.cyan,
      status: 'Ready to write',
    },
    {
      key: 'sleep',
      title: 'M3: Sleep Indicator',
      desc: 'Hours slept, wakefulness ratings, and 7-day mini trend.',
      icon: 'moon-outline',
      color: SENSE_COLORS.secondaryBlue,
      status: '6.5h logged',
    },
    {
      key: 'workload',
      title: 'M4: Cognitive Workload',
      desc: 'NASA-TLX demand metrics, urgency, and deadline tracker.',
      icon: 'briefcase-outline',
      color: SENSE_COLORS.navy,
      status: 'Index: 68/100',
    },
    {
      key: 'voice',
      title: 'M5: Acoustic Biomarkers',
      desc: 'Voluntary 30-second spoken reflection (zero background mic).',
      icon: 'mic-outline',
      color: SENSE_COLORS.electricBlue,
      status: 'Optional',
    },
    {
      key: 'activity',
      title: 'M6: Physical Activity',
      desc: 'Step volume and active minutes without continuous GPS.',
      icon: 'walk-outline',
      color: SENSE_COLORS.calm,
      status: '7,420 steps',
    },
  ];

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>Data Collection Hub</Text>
      <Text style={styles.subtitle}>
        Select a modality to record an observation. All 6 streams are optional and processed with privacy-preserving edge baselines.
      </Text>

      {modalities.map((m) => (
        <TouchableOpacity
          key={m.key}
          style={styles.card}
          onPress={() => onNavigate(m.key)}
          activeOpacity={0.8}
        >
          <View style={[styles.iconCircle, { backgroundColor: `${m.color}15` }]}>
            <Ionicons name={m.icon} size={22} color={m.color} />
          </View>
          <View style={{ flex: 1, marginLeft: 12 }}>
            <View style={styles.titleRow}>
              <Text style={styles.cardTitle}>{m.title}</Text>
              <Text style={styles.statusText}>{m.status}</Text>
            </View>
            <Text style={styles.cardDesc}>{m.desc}</Text>
          </View>
          <Ionicons name="chevron-forward" size={18} color={SENSE_COLORS.textMuted} style={{ marginLeft: 6 }} />
        </TouchableOpacity>
      ))}

      <View style={{ height: 30 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: SENSE_COLORS.background,
  },
  content: {
    padding: SENSE_SPACING.base,
  },
  title: {
    fontSize: 22,
    fontWeight: '800',
    color: SENSE_COLORS.textPrimary,
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 12,
    color: SENSE_COLORS.textSecondary,
    lineHeight: 18,
    marginBottom: SENSE_SPACING.lg,
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: SENSE_COLORS.surface,
    borderRadius: SENSE_RADII.lg,
    padding: SENSE_SPACING.md,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    marginBottom: SENSE_SPACING.md,
    ...SENSE_SHADOWS.card,
  },
  iconCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
  },
  titleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  cardTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  statusText: {
    fontSize: 10,
    fontWeight: '700',
    color: SENSE_COLORS.secondaryBlue,
    backgroundColor: '#E6F4FE',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: SENSE_RADII.pill,
  },
  cardDesc: {
    fontSize: 11,
    color: SENSE_COLORS.textSecondary,
    lineHeight: 16,
  },
});

