import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Switch, Alert } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function SettingsScreen({ onOpenCrisis }) {
  const [toggles, setToggles] = useState({
    m1: true,
    m2: true,
    m3: true,
    m4: true,
    m5: false, // Voice optional by default
    m6: true,
  });

  const handleToggle = (key) => {
    setToggles((prev) => ({ ...prev, [key]: !prev[key] }));
  };

  const handleExport = () => {
    Alert.alert(
      'Export Data (DPDP Act 2023)',
      'Your encrypted longitudinal dataset has been bundled into sense_data_export.json for your local download.',
      [{ text: 'OK' }]
    );
  };

  const handlePurge = () => {
    Alert.alert(
      'Purge All Data',
      'Are you sure you want to exercise your right to be forgotten? This permanently deletes all your local baseline records and encryption keys.',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Delete Everything', style: 'destructive' },
      ]
    );
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>Privacy & Settings</Text>
      <Text style={styles.subtitle}>
        Manage consent, review your pseudonymous ID, and control data boundaries under DPDP Act 2023.
      </Text>

      {/* Pseudonymous Profile Card */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <View style={styles.avatarCircle}>
            <Ionicons name="finger-print" size={20} color={SENSE_COLORS.cyan} />
          </View>
          <View style={{ flex: 1, marginLeft: 12 }}>
            <Text style={styles.participantLabel}>PSEUDONYMOUS ID</Text>
            <Text style={styles.participantId}>SENSE-8492-X</Text>
          </View>
          <View style={styles.activePill}>
            <Text style={styles.activePillText}>Local Edge</Text>
          </View>
        </View>
        <Text style={styles.edgeNotice}>
          No personal identifiable information (name, phone, email) is attached to your baseline vectors.
        </Text>
      </View>

      {/* Granular Modality Toggles */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Granular Modality Consent</Text>
        <Text style={styles.helperText}>
          Every modality is strictly voluntary. Disable any channel at any time without penalty:
        </Text>

        {[
          { key: 'm1', label: 'M1: Mood & Stress Check-in', desc: '1-5 emotional valence self-report' },
          { key: 'm2', label: 'M2: Reflective Journal', desc: 'On-device text sentiment tokenization' },
          { key: 'm3', label: 'M3: Sleep Indicator', desc: 'Duration and wakefulness rest scoring' },
          { key: 'm4', label: 'M4: Cognitive Workload', desc: 'NASA-TLX demand & deadline tracking' },
          { key: 'm5', label: 'M5: Acoustic Biomarkers', desc: 'Voluntary 30s voice reflection only' },
          { key: 'm6', label: 'M6: Physical Activity', desc: 'Step counts without GPS tracking' },
        ].map((item) => (
          <View key={item.key} style={styles.toggleRow}>
            <View style={{ flex: 1, marginRight: 8 }}>
              <Text style={styles.toggleLabel}>{item.label}</Text>
              <Text style={styles.toggleDesc}>{item.desc}</Text>
            </View>
            <Switch
              value={toggles[item.key]}
              onValueChange={() => handleToggle(item.key)}
              trackColor={{ false: '#D0E0EC', true: SENSE_COLORS.cyan }}
              thumbColor={SENSE_COLORS.white}
            />
          </View>
        ))}
      </View>

      {/* DPDP Act 2023 Compliance */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Data Rights (DPDP Act 2023)</Text>
        <Text style={styles.helperText}>
          You retain complete ownership of all baseline features and entries:
        </Text>

        <TouchableOpacity style={styles.actionBtn} onPress={handleExport} activeOpacity={0.75}>
          <Ionicons name="download-outline" size={18} color={SENSE_COLORS.secondaryBlue} />
          <Text style={styles.actionBtnText}>Export Personal Data (JSON)</Text>
        </TouchableOpacity>

        <TouchableOpacity style={[styles.actionBtn, styles.dangerBtn]} onPress={handlePurge} activeOpacity={0.75}>
          <Ionicons name="trash-outline" size={18} color="#B42332" />
          <Text style={[styles.actionBtnText, { color: '#B42332' }]}>Purge All Local Records</Text>
        </TouchableOpacity>
      </View>

      {/* Crisis Help Card */}
      <TouchableOpacity style={styles.crisisBanner} onPress={onOpenCrisis} activeOpacity={0.8}>
        <Ionicons name="shield-checkmark" size={22} color="#B42332" />
        <View style={{ flex: 1, marginLeft: 10 }}>
          <Text style={styles.crisisTitle}>Need Support? 24/7 Helplines</Text>
          <Text style={styles.crisisSub}>Tele-MANAS: 14416 | KIRAN: 1800-599-0019</Text>
        </View>
        <Ionicons name="chevron-forward" size={18} color="#B42332" />
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
    alignItems: 'center',
    marginBottom: 8,
  },
  avatarCircle: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: SENSE_COLORS.navy,
    alignItems: 'center',
    justifyContent: 'center',
  },
  participantLabel: {
    fontSize: 9,
    fontWeight: '700',
    color: SENSE_COLORS.textMuted,
    letterSpacing: 0.8,
  },
  participantId: {
    fontSize: 16,
    fontWeight: '800',
    color: SENSE_COLORS.textPrimary,
  },
  activePill: {
    backgroundColor: '#E6F4EA',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: SENSE_RADII.pill,
  },
  activePillText: {
    fontSize: 10,
    fontWeight: '700',
    color: SENSE_COLORS.calm,
  },
  edgeNotice: {
    fontSize: 11,
    color: SENSE_COLORS.textSecondary,
    lineHeight: 16,
    marginTop: 4,
  },
  cardTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
    marginBottom: 4,
  },
  helperText: {
    fontSize: 11,
    color: SENSE_COLORS.textMuted,
    marginBottom: 10,
    lineHeight: 16,
  },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#EDF3F7',
  },
  toggleLabel: {
    fontSize: 13,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  toggleDesc: {
    fontSize: 10,
    color: SENSE_COLORS.textMuted,
    marginTop: 2,
  },
  actionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: SENSE_COLORS.white,
    paddingVertical: 12,
    borderRadius: SENSE_RADII.md,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    marginTop: 8,
    ...SENSE_SHADOWS.card,
  },
  actionBtnText: {
    fontSize: 12,
    fontWeight: '700',
    color: SENSE_COLORS.secondaryBlue,
    marginLeft: 8,
  },
  dangerBtn: {
    borderColor: '#FFDCE1',
    backgroundColor: '#FFF7F8',
  },
  crisisBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF2F4',
    borderWidth: 1,
    borderColor: '#FFCCD2',
    borderRadius: SENSE_RADII.lg,
    padding: SENSE_SPACING.base,
    marginTop: 6,
    ...SENSE_SHADOWS.card,
  },
  crisisTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: '#B42332',
  },
  crisisSub: {
    fontSize: 11,
    color: '#8A2533',
    marginTop: 2,
  },
});

