import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Switch } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function ActivityScreen({ onBack }) {
  const [steps, setSteps] = useState(7420);
  const [activeMins, setActiveMins] = useState(42);
  const [healthSync, setHealthSync] = useState(true);
  const [saved, setSaved] = useState(false);

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
        <Text style={styles.provenanceText}>MODALITY M6: PHYSICAL MOVEMENT</Text>
      </View>

      <Text style={styles.title}>Physical Activity</Text>
      <Text style={styles.subtitle}>
        Step volume and active movement duration serve as physiological recovery correlates without continuous GPS tracking.
      </Text>

      {/* No GPS Tracking Guarantee */}
      <View style={styles.privacyBanner}>
        <Ionicons name="location-outline" size={16} color={SENSE_COLORS.calm} />
        <Text style={styles.privacyText}>
          Zero Location Tracking: SENSE tracks step counts only. Your GPS location, routes, and coordinates are never requested or stored.
        </Text>
      </View>

      {/* Steps Logger Card */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <Text style={styles.cardTitle}>Daily Step Count</Text>
          <Text style={styles.highlightVal}>{steps.toLocaleString()}</Text>
        </View>

        <View style={styles.stepperRow}>
          <TouchableOpacity
            style={styles.stepBtn}
            onPress={() => setSteps(Math.max(0, steps - 500))}
          >
            <Ionicons name="remove" size={20} color={SENSE_COLORS.secondaryBlue} />
          </TouchableOpacity>

          <View style={styles.displayCol}>
            <Ionicons name="footsteps" size={28} color={SENSE_COLORS.electricBlue} />
            <Text style={styles.bigVal}>{steps.toLocaleString()}</Text>
            <Text style={styles.goalText}>Goal: 8,000 steps (92%)</Text>
          </View>

          <TouchableOpacity
            style={styles.stepBtn}
            onPress={() => setSteps(steps + 500)}
          >
            <Ionicons name="add" size={20} color={SENSE_COLORS.secondaryBlue} />
          </TouchableOpacity>
        </View>
      </View>

      {/* Active Minutes Card */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <Text style={styles.cardTitle}>Active Movement Duration</Text>
          <Text style={styles.highlightVal}>{activeMins} mins</Text>
        </View>

        <View style={styles.chipsRow}>
          {[15, 30, 45, 60, 90].map((mins) => (
            <TouchableOpacity
              key={mins}
              style={[styles.chip, activeMins === mins && styles.chipActive]}
              onPress={() => setActiveMins(mins)}
            >
              <Text style={[styles.chipText, activeMins === mins && styles.chipTextActive]}>
                {mins}m
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Health Connect Switch */}
      <View style={styles.card}>
        <View style={styles.switchRow}>
          <View style={{ flex: 1, marginRight: 10 }}>
            <Text style={styles.switchTitle}>Health Connect / Apple Health</Text>
            <Text style={styles.switchSub}>
              Read daily step totals automatically without background sensor drain.
            </Text>
          </View>
          <Switch
            value={healthSync}
            onValueChange={setHealthSync}
            trackColor={{ false: '#D0E0EC', true: SENSE_COLORS.cyan }}
            thumbColor={SENSE_COLORS.white}
          />
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
              <Text style={styles.saveBtnText}> Activity Baseline Updated</Text>
            </View>
          ) : (
            <Text style={styles.saveBtnText}>Log Activity Data</Text>
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
  privacyBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#EBF7EE',
    padding: 10,
    borderRadius: SENSE_RADII.md,
    marginBottom: SENSE_SPACING.md,
    borderWidth: 1,
    borderColor: '#C7EDCF',
  },
  privacyText: {
    fontSize: 11,
    color: SENSE_COLORS.calm,
    marginLeft: 8,
    flex: 1,
    lineHeight: 16,
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
  highlightVal: {
    fontSize: 16,
    fontWeight: '800',
    color: SENSE_COLORS.electricBlue,
  },
  stepperRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    paddingVertical: 12,
  },
  stepBtn: {
    width: 46,
    height: 46,
    borderRadius: 23,
    backgroundColor: SENSE_COLORS.white,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    alignItems: 'center',
    justifyContent: 'center',
    ...SENSE_SHADOWS.card,
  },
  displayCol: {
    alignItems: 'center',
  },
  bigVal: {
    fontSize: 28,
    fontWeight: '800',
    color: SENSE_COLORS.textPrimary,
    marginTop: 4,
  },
  goalText: {
    fontSize: 11,
    color: SENSE_COLORS.calm,
    fontWeight: '600',
    marginTop: 2,
  },
  chipsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 12,
  },
  chip: {
    flex: 1,
    paddingVertical: 10,
    marginHorizontal: 3,
    borderRadius: SENSE_RADII.md,
    backgroundColor: SENSE_COLORS.white,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    alignItems: 'center',
  },
  chipActive: {
    backgroundColor: SENSE_COLORS.secondaryBlue,
    borderColor: SENSE_COLORS.secondaryBlue,
  },
  chipText: {
    fontSize: 12,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  chipTextActive: {
    color: '#FFFFFF',
  },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  switchTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  switchSub: {
    fontSize: 11,
    color: SENSE_COLORS.textMuted,
    marginTop: 2,
    lineHeight: 16,
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

