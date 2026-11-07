import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function WorkloadScreen({ onBack }) {
  const [mentalDemand, setMentalDemand] = useState(4);
  const [temporalEffort, setTemporalEffort] = useState(4);
  const [deadlines, setDeadlines] = useState(2);
  const [saved, setSaved] = useState(false);

  // NASA-TLX composite index estimation (0-100)
  const workloadIndex = Math.min(100, Math.round(mentalDemand * 10 + temporalEffort * 8 + deadlines * 3.5));

  const handleSave = () => {
    setSaved(true);
    setTimeout(() => {
      setSaved(false);
      onBack();
    }, 1200);
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.provenanceTag}>
        <Text style={styles.provenanceText}>MODALITY M4: COGNITIVE WORKLOAD</Text>
      </View>

      <Text style={styles.title}>Workload & Demands</Text>
      <Text style={styles.subtitle}>
        Quantifies perceived mental demand and timeline pressure using an adapted NASA-TLX methodology.
      </Text>

      {/* Live Index Card */}
      <View style={styles.indexCard}>
        <View style={styles.indexRow}>
          <View>
            <Text style={styles.indexOverline}>COMPOSITE WORKLOAD INDEX</Text>
            <Text style={styles.indexValue}>{workloadIndex} / 100</Text>
          </View>
          <View
            style={[
              styles.indexBadge,
              workloadIndex > 70
                ? { backgroundColor: '#FFEBEF' }
                : workloadIndex > 40
                ? { backgroundColor: '#FFF5E5' }
                : { backgroundColor: '#E6F4EA' },
            ]}
          >
            <Text
              style={[
                styles.indexBadgeText,
                workloadIndex > 70
                  ? { color: SENSE_COLORS.elevated }
                  : workloadIndex > 40
                  ? { color: SENSE_COLORS.moderate }
                  : { color: SENSE_COLORS.calm },
              ]}
            >
              {workloadIndex > 70 ? 'High Demand' : workloadIndex > 40 ? 'Moderate Demand' : 'Manageable'}
            </Text>
          </View>
        </View>
      </View>

      {/* Mental Demand */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <Text style={styles.cardTitle}>1. Mental Demand</Text>
          <Text style={styles.cardScore}>{mentalDemand} / 5</Text>
        </View>
        <Text style={styles.helperText}>How much mental and perceptual activity was required?</Text>
        <View style={styles.buttonsRow}>
          {[1, 2, 3, 4, 5].map((lvl) => (
            <TouchableOpacity
              key={lvl}
              style={[styles.lvlBtn, mentalDemand === lvl && styles.lvlBtnActive]}
              onPress={() => setMentalDemand(lvl)}
            >
              <Text style={[styles.lvlText, mentalDemand === lvl && styles.lvlTextActive]}>{lvl}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Temporal Effort */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <Text style={styles.cardTitle}>2. Temporal Urgency</Text>
          <Text style={styles.cardScore}>{temporalEffort} / 5</Text>
        </View>
        <Text style={styles.helperText}>How hurried or rushed was the pace of your day?</Text>
        <View style={styles.buttonsRow}>
          {[1, 2, 3, 4, 5].map((lvl) => (
            <TouchableOpacity
              key={lvl}
              style={[styles.lvlBtn, temporalEffort === lvl && styles.lvlBtnActive]}
              onPress={() => setTemporalEffort(lvl)}
            >
              <Text style={[styles.lvlText, temporalEffort === lvl && styles.lvlTextActive]}>{lvl}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Deadlines Counter */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <Text style={styles.cardTitle}>3. Pending Major Deadlines</Text>
          <Text style={styles.cardScore}>{deadlines} active</Text>
        </View>
        <Text style={styles.helperText}>Academic, professional, or personal deadlines in next 48h</Text>
        <View style={styles.stepperContainer}>
          <TouchableOpacity
            style={styles.circleBtn}
            onPress={() => setDeadlines(Math.max(0, deadlines - 1))}
          >
            <Ionicons name="remove" size={18} color={SENSE_COLORS.secondaryBlue} />
          </TouchableOpacity>
          <Text style={styles.stepperVal}>{deadlines}</Text>
          <TouchableOpacity
            style={styles.circleBtn}
            onPress={() => setDeadlines(Math.min(10, deadlines + 1))}
          >
            <Ionicons name="add" size={18} color={SENSE_COLORS.secondaryBlue} />
          </TouchableOpacity>
        </View>
      </View>

      {/* Save Button */}
      <TouchableOpacity
        style={styles.saveBtn}
        onPress={handleSave}
        disabled={saved}
        activeOpacity={0.85}
      >
        <LinearGradient
          colors={SENSE_COLORS.primaryGradient}
          style={styles.saveBtnGradient}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 0 }}
        >
          {saved ? (
            <View style={styles.savingRow}>
              <Ionicons name="checkmark-circle" size={18} color="#FFFFFF" />
              <Text style={styles.saveBtnText}> Workload Score Recorded</Text>
            </View>
          ) : (
            <Text style={styles.saveBtnText}>Save Workload Metrics</Text>
          )}
        </LinearGradient>
      </TouchableOpacity>
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
  indexCard: {
    backgroundColor: SENSE_COLORS.surface,
    borderRadius: SENSE_RADII.lg,
    padding: SENSE_SPACING.base,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    marginBottom: SENSE_SPACING.md,
    ...SENSE_SHADOWS.card,
  },
  indexRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  indexOverline: {
    fontSize: 10,
    fontWeight: '700',
    color: SENSE_COLORS.textMuted,
    letterSpacing: 0.8,
  },
  indexValue: {
    fontSize: 24,
    fontWeight: '800',
    color: SENSE_COLORS.textPrimary,
    marginTop: 2,
  },
  indexBadge: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: SENSE_RADII.pill,
  },
  indexBadgeText: {
    fontSize: 11,
    fontWeight: '700',
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
  cardHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  cardTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  cardScore: {
    fontSize: 14,
    fontWeight: '800',
    color: SENSE_COLORS.electricBlue,
  },
  helperText: {
    fontSize: 11,
    color: SENSE_COLORS.textMuted,
    marginTop: 2,
    marginBottom: 12,
  },
  buttonsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 4,
  },
  lvlBtn: {
    width: 52,
    height: 44,
    borderRadius: SENSE_RADII.md,
    backgroundColor: SENSE_COLORS.white,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    alignItems: 'center',
    justifyContent: 'center',
    ...SENSE_SHADOWS.card,
  },
  lvlBtnActive: {
    backgroundColor: SENSE_COLORS.secondaryBlue,
    borderColor: SENSE_COLORS.secondaryBlue,
  },
  lvlText: {
    fontSize: 14,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  lvlTextActive: {
    color: '#FFFFFF',
  },
  stepperContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
  },
  circleBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: SENSE_COLORS.white,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    alignItems: 'center',
    justifyContent: 'center',
    ...SENSE_SHADOWS.card,
  },
  stepperVal: {
    fontSize: 22,
    fontWeight: '800',
    color: SENSE_COLORS.textPrimary,
    marginHorizontal: 24,
  },
  saveBtn: {
    borderRadius: SENSE_RADII.lg,
    overflow: 'hidden',
    marginBottom: 30,
    ...SENSE_SHADOWS.raised,
  },
  saveBtnGradient: {
    paddingVertical: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  savingRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  saveBtnText: {
    fontSize: 15,
    fontWeight: '700',
    color: '#FFFFFF',
  },
});

