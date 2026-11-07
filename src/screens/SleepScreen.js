import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function SleepScreen({ onBack }) {
  const [duration, setDuration] = useState(6.5);
  const [quality, setQuality] = useState(4);
  const [bedtime, setBedtime] = useState('11:30 PM');
  const [wakeTime, setWakeTime] = useState('06:00 AM');
  const [saved, setSaved] = useState(false);

  const weeklyHistory = [
    { day: 'M', hours: 7.2, quality: 4 },
    { day: 'T', hours: 6.8, quality: 3 },
    { day: 'W', hours: 5.5, quality: 2 },
    { day: 'T', hours: 6.0, quality: 3 },
    { day: 'F', hours: 7.5, quality: 5 },
    { day: 'S', hours: 8.0, quality: 5 },
    { day: 'S', hours: 6.5, quality: 4 },
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
        <Text style={styles.provenanceText}>MODALITY M3: SLEEP INDICATOR</Text>
      </View>

      <Text style={styles.title}>Sleep & Recovery</Text>
      <Text style={styles.subtitle}>
        Consistent sleep duration and perceived restfulness are key baselines in evaluating cumulative stress resilience.
      </Text>

      {/* Duration Card */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <Text style={styles.cardTitle}>Total Sleep Duration</Text>
          <Text style={styles.highlightVal}>{duration.toFixed(1)} hrs</Text>
        </View>

        {/* Stepper buttons */}
        <View style={styles.stepperRow}>
          <TouchableOpacity
            style={styles.stepBtn}
            onPress={() => setDuration(Math.max(3, duration - 0.5))}
          >
            <Ionicons name="remove" size={20} color={SENSE_COLORS.secondaryBlue} />
          </TouchableOpacity>

          <View style={styles.durationDisplay}>
            <Ionicons name="moon" size={24} color={SENSE_COLORS.cyan} />
            <Text style={styles.durationBigText}>{duration.toFixed(1)}</Text>
            <Text style={styles.durationUnitText}>HOURS</Text>
          </View>

          <TouchableOpacity
            style={styles.stepBtn}
            onPress={() => setDuration(Math.min(12, duration + 0.5))}
          >
            <Ionicons name="add" size={20} color={SENSE_COLORS.secondaryBlue} />
          </TouchableOpacity>
        </View>

        {/* Quick Time Row */}
        <View style={styles.timeRow}>
          <View style={styles.timeBox}>
            <Text style={styles.timeLabel}>Fell Asleep</Text>
            <Text style={styles.timeVal}>{bedtime}</Text>
          </View>
          <Ionicons name="arrow-forward" size={16} color={SENSE_COLORS.textMuted} />
          <View style={styles.timeBox}>
            <Text style={styles.timeLabel}>Woke Up</Text>
            <Text style={styles.timeVal}>{wakeTime}</Text>
          </View>
        </View>
      </View>

      {/* Quality Stars */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Sleep Quality & Restfulness</Text>
        <Text style={styles.helperText}>How refreshed did you feel upon waking?</Text>

        <View style={styles.starsRow}>
          {[1, 2, 3, 4, 5].map((star) => (
            <TouchableOpacity
              key={star}
              onPress={() => setQuality(star)}
              style={styles.starTouch}
            >
              <Ionicons
                name={star <= quality ? 'star' : 'star-outline'}
                size={34}
                color={star <= quality ? '#E6A700' : '#C2D8E8'}
              />
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* 7-Day Mini Trend Bars */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Last 7 Days Rest History</Text>
        <View style={styles.miniChartContainer}>
          {weeklyHistory.map((item, idx) => {
            const barHeight = (item.hours / 9) * 70;
            return (
              <View key={idx} style={styles.barCol}>
                <View style={styles.barTrack}>
                  <View
                    style={[
                      styles.barFill,
                      { height: barHeight },
                      item.hours < 6 ? { backgroundColor: SENSE_COLORS.elevated } : { backgroundColor: SENSE_COLORS.electricBlue },
                    ]}
                  />
                </View>
                <Text style={styles.barDay}>{item.day}</Text>
                <Text style={styles.barHours}>{item.hours}h</Text>
              </View>
            );
          })}
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
              <Text style={styles.saveBtnText}> Saved to Sleep Tracker</Text>
            </View>
          ) : (
            <Text style={styles.saveBtnText}>Log Sleep Session</Text>
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
    marginBottom: 10,
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
  helperText: {
    fontSize: 11,
    color: SENSE_COLORS.textMuted,
    marginTop: 2,
    marginBottom: 12,
  },
  stepperRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    paddingVertical: 8,
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
  durationDisplay: {
    alignItems: 'center',
  },
  durationBigText: {
    fontSize: 32,
    fontWeight: '800',
    color: SENSE_COLORS.textPrimary,
    marginTop: 2,
  },
  durationUnitText: {
    fontSize: 10,
    fontWeight: '700',
    color: SENSE_COLORS.textMuted,
    letterSpacing: 1,
  },
  timeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#EDF5FA',
    padding: 10,
    borderRadius: SENSE_RADII.md,
    marginTop: 14,
  },
  timeBox: {
    alignItems: 'center',
  },
  timeLabel: {
    fontSize: 10,
    color: SENSE_COLORS.textMuted,
  },
  timeVal: {
    fontSize: 13,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
    marginTop: 2,
  },
  starsRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    paddingVertical: 8,
  },
  starTouch: {
    paddingHorizontal: 8,
  },
  miniChartContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
    height: 110,
    marginTop: 12,
    paddingTop: 10,
  },
  barCol: {
    alignItems: 'center',
    flex: 1,
  },
  barTrack: {
    height: 70,
    width: 14,
    backgroundColor: '#E1EDF5',
    borderRadius: 7,
    justifyContent: 'flex-end',
    overflow: 'hidden',
  },
  barFill: {
    width: '100%',
    borderRadius: 7,
  },
  barDay: {
    fontSize: 11,
    fontWeight: '600',
    color: SENSE_COLORS.textSecondary,
    marginTop: 6,
  },
  barHours: {
    fontSize: 9,
    color: SENSE_COLORS.textMuted,
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

