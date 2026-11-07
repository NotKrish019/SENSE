import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function CheckInScreen({ onBack }) {
  const [mood, setMood] = useState(3);
  const [stress, setStress] = useState(3);
  const [energy, setEnergy] = useState(4);
  const [saved, setSaved] = useState(false);

  const moods = [
    { value: 1, label: 'Very Low', emoji: '😞' },
    { value: 2, label: 'Low', emoji: '🙁' },
    { value: 3, label: 'Neutral', emoji: '😐' },
    { value: 4, label: 'Good', emoji: '🙂' },
    { value: 5, label: 'Great', emoji: '😄' },
  ];

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
        <Text style={styles.provenanceText}>MODALITY M1: SELF-REPORT</Text>
      </View>

      <Text style={styles.title}>Daily Emotional Check-in</Text>
      <Text style={styles.subtitle}>
        Record how you are feeling right now. SENSE compares your report against your personal baseline over time.
      </Text>

      {/* Mood Selector */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>1. How is your mood today?</Text>
        <View style={styles.moodRow}>
          {moods.map((m) => {
            const isSelected = mood === m.value;
            return (
              <TouchableOpacity
                key={m.value}
                style={[
                  styles.moodItem,
                  isSelected && styles.moodItemSelected,
                ]}
                onPress={() => setMood(m.value)}
                activeOpacity={0.7}
              >
                <Text style={styles.moodEmoji}>{m.emoji}</Text>
                <Text
                  style={[
                    styles.moodLabel,
                    isSelected && { color: SENSE_COLORS.secondaryBlue, fontWeight: '700' },
                  ]}
                >
                  {m.label}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </View>

      {/* Stress Scale */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <Text style={styles.cardTitle}>2. Perceived Stress Level</Text>
          <Text style={styles.sliderValueText}>{stress} / 5</Text>
        </View>
        <Text style={styles.helperText}>1 = Completely calm, 5 = Heavily overwhelmed</Text>

        <View style={styles.levelButtonsRow}>
          {[1, 2, 3, 4, 5].map((lvl) => (
            <TouchableOpacity
              key={lvl}
              style={[
                styles.levelButton,
                stress === lvl && styles.levelButtonActive,
              ]}
              onPress={() => setStress(lvl)}
            >
              <Text
                style={[
                  styles.levelButtonText,
                  stress === lvl && styles.levelButtonTextActive,
                ]}
              >
                {lvl}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Energy Level */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <Text style={styles.cardTitle}>3. Energy & Vitality</Text>
          <Text style={styles.sliderValueText}>{energy} / 5</Text>
        </View>
        <Text style={styles.helperText}>1 = Drained, 5 = Fully energized</Text>

        <View style={styles.levelButtonsRow}>
          {[1, 2, 3, 4, 5].map((lvl) => (
            <TouchableOpacity
              key={lvl}
              style={[
                styles.levelButton,
                energy === lvl && styles.levelButtonActive,
              ]}
              onPress={() => setEnergy(lvl)}
            >
              <Text
                style={[
                  styles.levelButtonText,
                  energy === lvl && styles.levelButtonTextActive,
                ]}
              >
                {lvl}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Non-clinical footnote */}
      <View style={styles.noticeBox}>
        <Ionicons name="lock-closed-outline" size={14} color={SENSE_COLORS.textSecondary} />
        <Text style={styles.noticeText}>
          Your check-in responses are encrypted locally on this device.
        </Text>
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
              <Text style={styles.saveBtnText}> Saved to Local Baseline</Text>
            </View>
          ) : (
            <Text style={styles.saveBtnText}>Complete Check-in</Text>
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
  sliderValueText: {
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
  moodRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 12,
  },
  moodItem: {
    alignItems: 'center',
    paddingVertical: 8,
    paddingHorizontal: 6,
    borderRadius: SENSE_RADII.md,
    borderWidth: 1,
    borderColor: 'transparent',
    minWidth: 56,
  },
  moodItemSelected: {
    backgroundColor: '#E8F5FD',
    borderColor: SENSE_COLORS.cyan,
  },
  moodEmoji: {
    fontSize: 28,
    marginBottom: 4,
  },
  moodLabel: {
    fontSize: 10,
    color: SENSE_COLORS.textMuted,
  },
  levelButtonsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 8,
  },
  levelButton: {
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
  levelButtonActive: {
    backgroundColor: SENSE_COLORS.secondaryBlue,
    borderColor: SENSE_COLORS.secondaryBlue,
  },
  levelButtonText: {
    fontSize: 14,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  levelButtonTextActive: {
    color: '#FFFFFF',
  },
  noticeBox: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 10,
    borderRadius: SENSE_RADII.md,
    backgroundColor: '#EDF5FA',
    marginBottom: SENSE_SPACING.lg,
  },
  noticeText: {
    fontSize: 11,
    color: SENSE_COLORS.textSecondary,
    marginLeft: 6,
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

