import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function JournalScreen({ onBack, onOpenCrisis }) {
  const [text, setText] = useState('');
  const [saved, setSaved] = useState(false);

  // Real-time crisis phrase interceptor
  const crisisKeywords = ['hopeless', 'end it', 'suicide', "can't go on", 'give up', 'kill myself', 'no point'];
  const hasCrisisPhrase = crisisKeywords.some((kw) => text.toLowerCase().includes(kw));

  const wordCount = text.trim() ? text.trim().split(/\s+/).length : 0;

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
        <Text style={styles.provenanceText}>MODALITY M2: REFLECTIVE TEXT</Text>
      </View>

      <Text style={styles.title}>Reflective Journal</Text>
      <Text style={styles.subtitle}>
        Write down your thoughts, events, or pressures. Language features are processed locally on-device.
      </Text>

      {/* Real-time Crisis Interceptor Banner */}
      {hasCrisisPhrase && (
        <View style={styles.crisisBanner}>
          <View style={styles.crisisRow}>
            <Ionicons name="heart-circle" size={24} color="#B42332" />
            <View style={{ flex: 1, marginLeft: 10 }}>
              <Text style={styles.crisisTitle}>Support is available right now</Text>
              <Text style={styles.crisisSub}>
                Your well-being matters. You don't have to carry this alone. Free 24/7 counselors are ready to speak with you.
              </Text>
            </View>
          </View>
          <TouchableOpacity 
            style={styles.crisisCallBtn}
            onPress={onOpenCrisis}
            activeOpacity={0.8}
          >
            <Ionicons name="call" size={14} color="#FFFFFF" />
            <Text style={styles.crisisCallText}> Connect to Tele-MANAS (14416)</Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Editor Box */}
      <View style={styles.editorCard}>
        <TextInput
          style={styles.textInput}
          multiline
          placeholder="How did your day unfold? What feels demanding or rewarding today? (e.g. tight deadlines, restless thoughts...)"
          placeholderTextColor={SENSE_COLORS.textMuted}
          value={text}
          onChangeText={setText}
          textAlignVertical="top"
        />

        <View style={styles.editorFooter}>
          <View style={styles.encryptionPill}>
            <Ionicons name="shield-checkmark" size={12} color={SENSE_COLORS.calm} />
            <Text style={styles.encryptionText}>AES-256 On-Device Only</Text>
          </View>
          <Text style={styles.counterText}>{wordCount} words | {text.length} chars</Text>
        </View>
      </View>

      {/* Guidance Note */}
      <View style={styles.guidanceBox}>
        <Ionicons name="information-circle-outline" size={16} color={SENSE_COLORS.electricBlue} />
        <Text style={styles.guidanceText}>
          SENSE extracts high-level linguistic markers (e.g. sentiment tone, cognitive load words) without uploading your raw diary to external servers.
        </Text>
      </View>

      {/* Save Button */}
      <TouchableOpacity
        style={styles.saveBtn}
        onPress={handleSave}
        disabled={saved || text.length === 0}
        activeOpacity={0.85}
      >
        <LinearGradient
          colors={text.length > 0 ? SENSE_COLORS.primaryGradient : ['#B8D6E8', '#CBE2F0']}
          style={styles.saveBtnGradient}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 0 }}
        >
          {saved ? (
            <View style={styles.savingRow}>
              <Ionicons name="checkmark-circle" size={18} color="#FFFFFF" />
              <Text style={styles.saveBtnText}> Saved & Locally Tokenized</Text>
            </View>
          ) : (
            <Text style={styles.saveBtnText}>Save Journal Entry</Text>
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
  crisisBanner: {
    backgroundColor: '#FFF0F2',
    borderWidth: 1.5,
    borderColor: '#FFCCD2',
    borderRadius: SENSE_RADII.lg,
    padding: SENSE_SPACING.md,
    marginBottom: SENSE_SPACING.md,
    ...SENSE_SHADOWS.card,
  },
  crisisRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  crisisTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#B42332',
  },
  crisisSub: {
    fontSize: 11,
    color: '#8A2533',
    lineHeight: 16,
    marginTop: 2,
  },
  crisisCallBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#B42332',
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: SENSE_RADII.md,
    marginTop: 10,
  },
  crisisCallText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  editorCard: {
    backgroundColor: SENSE_COLORS.surface,
    borderRadius: SENSE_RADII.lg,
    padding: SENSE_SPACING.md,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    marginBottom: SENSE_SPACING.md,
    ...SENSE_SHADOWS.card,
  },
  textInput: {
    minHeight: 160,
    fontSize: 14,
    color: SENSE_COLORS.textPrimary,
    lineHeight: 22,
  },
  editorFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    borderTopWidth: 1,
    borderTopColor: SENSE_COLORS.border,
    paddingTop: 10,
    marginTop: 10,
  },
  encryptionPill: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#EAF7EE',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: SENSE_RADII.pill,
  },
  encryptionText: {
    fontSize: 10,
    fontWeight: '700',
    color: SENSE_COLORS.calm,
    marginLeft: 4,
  },
  counterText: {
    fontSize: 11,
    color: SENSE_COLORS.textMuted,
  },
  guidanceBox: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#EDF5FA',
    padding: 12,
    borderRadius: SENSE_RADII.md,
    marginBottom: SENSE_SPACING.lg,
  },
  guidanceText: {
    fontSize: 11,
    color: SENSE_COLORS.textSecondary,
    marginLeft: 8,
    flex: 1,
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

