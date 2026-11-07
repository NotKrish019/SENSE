import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function VoiceScreen({ onBack }) {
  const [recording, setRecording] = useState(false);
  const [seconds, setSeconds] = useState(0);
  const [recorded, setRecorded] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    let interval = null;
    if (recording) {
      interval = setInterval(() => {
        setSeconds((prev) => {
          if (prev >= 30) {
            setRecording(false);
            setRecorded(true);
            return 30;
          }
          return prev + 1;
        });
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [recording]);

  const toggleRecord = () => {
    if (recording) {
      setRecording(false);
      setRecorded(true);
    } else {
      setSeconds(0);
      setRecorded(false);
      setRecording(true);
    }
  };

  const handleSave = () => {
    setSaved(true);
    setTimeout(() => {
      setSaved(false);
      onBack();
    }, 1200);
  };

  const waveformHeights = [20, 35, 60, 40, 75, 90, 65, 45, 80, 50, 30, 65, 85, 40, 25];

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.provenanceTag}>
        <Text style={styles.provenanceText}>MODALITY M5: ACOUSTIC BIOMARKERS</Text>
      </View>

      <Text style={styles.title}>Voice Reflection</Text>
      <Text style={styles.subtitle}>
        Voluntary 30-second spoken reflection. Extracts acoustic prosody (pitch jitter, speech rate) without saving raw conversational audio.
      </Text>

      {/* Zero Background Recording Assurance */}
      <View style={styles.privacyBanner}>
        <Ionicons name="shield-checkmark" size={16} color={SENSE_COLORS.calm} />
        <Text style={styles.privacyText}>
          Strict Privacy: SENSE NEVER records ambient background audio. Microphone activates ONLY when you explicitly press and hold record.
        </Text>
      </View>

      {/* Waveform & Record Card */}
      <View style={styles.recorderCard}>
        <View style={styles.timerBadge}>
          <Text style={styles.timerText}>
            00:{seconds < 10 ? `0${seconds}` : seconds} / 00:30
          </Text>
        </View>

        {/* Waveform bars */}
        <View style={styles.waveformContainer}>
          {waveformHeights.map((h, i) => (
            <View
              key={i}
              style={[
                styles.waveformBar,
                {
                  height: recording ? Math.max(10, (h * (0.4 + (i % 3) * 0.3))) : 12,
                  backgroundColor: recording ? SENSE_COLORS.cyan : '#D0E4F2',
                },
              ]}
            />
          ))}
        </View>

        {/* Big Mic Button */}
        <TouchableOpacity
          style={styles.micTouch}
          onPress={toggleRecord}
          activeOpacity={0.85}
        >
          <LinearGradient
            colors={recording ? ['#B42332', '#E63946'] : SENSE_COLORS.primaryGradient}
            style={styles.micCircle}
          >
            <Ionicons
              name={recording ? 'stop' : 'mic'}
              size={36}
              color="#FFFFFF"
            />
          </LinearGradient>
        </TouchableOpacity>

        <Text style={styles.statusInstruction}>
          {recording
            ? 'Speaking... Tap to finish audio sample'
            : recorded
            ? 'Audio sample recorded (15 acoustic features extracted)'
            : 'Tap microphone to speak for 30 seconds'}
        </Text>
      </View>

      {/* Feature extraction preview */}
      {recorded && (
        <View style={styles.featuresCard}>
          <Text style={styles.featuresTitle}>Extracted Acoustic Features (Local):</Text>
          <View style={styles.featureItem}>
            <Text style={styles.featureLabel}>• Pitch Variability (F0 SD):</Text>
            <Text style={styles.featureVal}>28.4 Hz</Text>
          </View>
          <View style={styles.featureItem}>
            <Text style={styles.featureLabel}>• Speaking Rate:</Text>
            <Text style={styles.featureVal}>3.9 syllables/sec</Text>
          </View>
          <View style={styles.featureItem}>
            <Text style={styles.featureLabel}>• Jitter / Shimmer ratio:</Text>
            <Text style={styles.featureVal}>1.42% (Normal range)</Text>
          </View>
        </View>
      )}

      {/* Save Button */}
      <TouchableOpacity
        style={styles.saveBtn}
        onPress={handleSave}
        disabled={saved || !recorded}
        activeOpacity={0.85}
      >
        <LinearGradient
          colors={recorded ? SENSE_COLORS.primaryGradient : ['#B8D6E8', '#CBE2F0']}
          style={styles.saveBtnGradient}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 0 }}
        >
          {saved ? (
            <View style={styles.savingRow}>
              <Ionicons name="checkmark-circle" size={18} color="#FFFFFF" />
              <Text style={styles.saveBtnText}> Acoustic Features Preserved</Text>
            </View>
          ) : (
            <Text style={styles.saveBtnText}>Log Voice Biomarkers</Text>
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
  recorderCard: {
    backgroundColor: SENSE_COLORS.surface,
    borderRadius: SENSE_RADII.xl,
    padding: SENSE_SPACING.lg,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    alignItems: 'center',
    marginBottom: SENSE_SPACING.md,
    ...SENSE_SHADOWS.card,
  },
  timerBadge: {
    backgroundColor: SENSE_COLORS.white,
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: SENSE_RADII.pill,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    marginBottom: 20,
  },
  timerText: {
    fontSize: 13,
    fontWeight: '700',
    color: SENSE_COLORS.secondaryBlue,
  },
  waveformContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    height: 90,
    marginBottom: 24,
  },
  waveformBar: {
    width: 6,
    marginHorizontal: 3,
    borderRadius: 3,
  },
  micTouch: {
    width: 80,
    height: 80,
    borderRadius: 40,
    ...SENSE_SHADOWS.hero,
  },
  micCircle: {
    width: 80,
    height: 80,
    borderRadius: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  statusInstruction: {
    fontSize: 12,
    color: SENSE_COLORS.textSecondary,
    textAlign: 'center',
    marginTop: 18,
  },
  featuresCard: {
    backgroundColor: '#EDF5FA',
    borderRadius: SENSE_RADII.lg,
    padding: SENSE_SPACING.md,
    marginBottom: SENSE_SPACING.md,
  },
  featuresTitle: {
    fontSize: 12,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
    marginBottom: 6,
  },
  featureItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 3,
  },
  featureLabel: {
    fontSize: 11,
    color: SENSE_COLORS.textSecondary,
  },
  featureVal: {
    fontSize: 11,
    fontWeight: '700',
    color: SENSE_COLORS.secondaryBlue,
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

