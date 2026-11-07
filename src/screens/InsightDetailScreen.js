import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function InsightDetailScreen({ onBack, onOpenCrisis }) {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.provenanceTag}>
        <Text style={styles.provenanceText}>EXPLAINABLE AI OBSERVATION</Text>
      </View>

      <Text style={styles.title}>Pattern Analysis Breakdown</Text>
      <Text style={styles.subtitle}>
        Transparent explanation of the factors leading to your recent moderate stress indicator.
      </Text>

      {/* What Changed Card */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <View style={styles.iconCircle}>
            <Ionicons name="git-compare-outline" size={18} color={SENSE_COLORS.secondaryBlue} />
          </View>
          <Text style={styles.cardTitle}>1. What Changed?</Text>
        </View>
        <Text style={styles.bodyText}>
          Over the past 7 days, your composite stress indicator rose by <Text style={styles.boldText}>+1.4 standard deviations</Text> relative to your 21-day baseline mean.
        </Text>
      </View>

      {/* Supporting Observations Card */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <View style={styles.iconCircle}>
            <Ionicons name="layers-outline" size={18} color={SENSE_COLORS.electricBlue} />
          </View>
          <Text style={styles.cardTitle}>2. Supporting Modalities</Text>
        </View>

        <View style={styles.obsItem}>
          <Text style={styles.obsModality}>• M3 Sleep Duration:</Text>
          <Text style={styles.obsVal}>Averaged 5.8h (Baseline: 7.2h, -19% drop)</Text>
        </View>
        <View style={styles.obsItem}>
          <Text style={styles.obsModality}>• M4 Cognitive Workload:</Text>
          <Text style={styles.obsVal}>Workload score 78/100 (3 active deadlines)</Text>
        </View>
        <View style={styles.obsItem}>
          <Text style={styles.obsModality}>• M1 Emotional Check-in:</Text>
          <Text style={styles.obsVal}>Self-reported stress rated 4/5 for 3 consecutive days</Text>
        </View>
      </View>

      {/* Non-clinical Boundary Card */}
      <View style={[styles.card, styles.cautionCard]}>
        <View style={styles.cardHeaderRow}>
          <View style={[styles.iconCircle, { backgroundColor: '#FFEBEF' }]}>
            <Ionicons name="alert-circle" size={18} color="#B42332" />
          </View>
          <Text style={[styles.cardTitle, { color: '#B42332' }]}>3. What SENSE Cannot Conclude</Text>
        </View>
        <Text style={styles.cautionBody}>
          SENSE is a digital research mirror, NOT a diagnostic medical tool. SENSE cannot diagnose clinical depression, anxiety disorders, burnout, or any psychiatric condition. If emotional strain persists, professional healthcare consultation is strongly recommended.
        </Text>
      </View>

      {/* Supportive Steps Card */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <View style={[styles.iconCircle, { backgroundColor: '#E8F5FD' }]}>
            <Ionicons name="leaf-outline" size={18} color={SENSE_COLORS.secondaryBlue} />
          </View>
          <Text style={styles.cardTitle}>4. Supportive Considerations</Text>
        </View>

        <View style={styles.stepItem}>
          <Ionicons name="checkmark-circle-outline" size={16} color={SENSE_COLORS.calm} />
          <Text style={styles.stepText}>Prioritize an extra 45–60 minutes of rest tonight before 11:00 PM.</Text>
        </View>
        <View style={styles.stepItem}>
          <Ionicons name="checkmark-circle-outline" size={16} color={SENSE_COLORS.calm} />
          <Text style={styles.stepText}>Schedule a 15-minute screen-free break between demanding tasks.</Text>
        </View>
      </View>

      {/* Crisis Action */}
      <TouchableOpacity
        style={styles.helplineBtn}
        onPress={onOpenCrisis}
        activeOpacity={0.8}
      >
        <Ionicons name="heart" size={16} color="#FFFFFF" />
        <Text style={styles.helplineBtnText}> Access Free 24/7 Helplines (Tele-MANAS)</Text>
      </TouchableOpacity>

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
  provenanceTag: {
    alignSelf: 'flex-start',
    backgroundColor: '#E1F0FA',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: SENSE_RADII.pill,
    marginBottom: 6,
  },
  provenanceText: {
    fontSize: 9,
    fontWeight: '800',
    color: SENSE_COLORS.secondaryBlue,
    letterSpacing: 0.6,
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
    backgroundColor: SENSE_COLORS.surface,
    borderRadius: SENSE_RADII.lg,
    padding: SENSE_SPACING.base,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    marginBottom: SENSE_SPACING.md,
    ...SENSE_SHADOWS.card,
  },
  cautionCard: {
    backgroundColor: '#FFF8F9',
    borderColor: '#FFD4DB',
  },
  cardHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  iconCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#E6F4FE',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 8,
  },
  cardTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  bodyText: {
    fontSize: 12,
    color: SENSE_COLORS.textSecondary,
    lineHeight: 18,
  },
  boldText: {
    fontWeight: '700',
    color: SENSE_COLORS.secondaryBlue,
  },
  obsItem: {
    paddingVertical: 4,
  },
  obsModality: {
    fontSize: 12,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  obsVal: {
    fontSize: 11,
    color: SENSE_COLORS.textSecondary,
    marginTop: 1,
  },
  cautionBody: {
    fontSize: 11,
    color: '#8A2533',
    lineHeight: 16,
  },
  stepItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 6,
  },
  stepText: {
    fontSize: 12,
    color: SENSE_COLORS.textPrimary,
    marginLeft: 8,
    flex: 1,
  },
  helplineBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#B42332',
    paddingVertical: 12,
    borderRadius: SENSE_RADII.md,
    marginTop: 8,
    ...SENSE_SHADOWS.card,
  },
  helplineBtnText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#FFFFFF',
  },
});

