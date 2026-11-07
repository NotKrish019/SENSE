import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function Header({ onOpenCrisis, currentScreen, onBack }) {
  const isHome = currentScreen === 'dashboard';

  return (
    <View style={styles.container}>
      <View style={styles.leftRow}>
        {!isHome ? (
          <TouchableOpacity onPress={onBack} style={styles.backBtn} activeOpacity={0.7}>
            <Ionicons name="arrow-back" size={20} color={SENSE_COLORS.navy} />
          </TouchableOpacity>
        ) : (
          <View style={styles.logoBadge}>
            <View style={styles.logoInner}>
              <Ionicons name="pulse" size={16} color={SENSE_COLORS.cyan} />
            </View>
          </View>
        )}

        <View style={styles.titleCol}>
          <Text style={styles.titleText}>SENSE</Text>
          <Text style={styles.subText}>WELL-BEING RESEARCH</Text>
        </View>
      </View>

      <TouchableOpacity 
        style={styles.helplineBtn} 
        onPress={onOpenCrisis}
        activeOpacity={0.8}
      >
        <Ionicons name="shield-checkmark" size={13} color="#B42332" />
        <Text style={styles.helplineText}>24/7 Helpline</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: SENSE_SPACING.base,
    paddingVertical: SENSE_SPACING.md,
    backgroundColor: SENSE_COLORS.background,
    borderBottomWidth: 1,
    borderBottomColor: SENSE_COLORS.border,
  },
  leftRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  backBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: SENSE_COLORS.surface,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    ...SENSE_SHADOWS.card,
  },
  logoBadge: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: SENSE_COLORS.navy,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
    ...SENSE_SHADOWS.card,
  },
  logoInner: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  titleCol: {
    justifyContent: 'center',
  },
  titleText: {
    fontSize: 16,
    fontWeight: '800',
    color: SENSE_COLORS.navy,
    letterSpacing: 1.2,
  },
  subText: {
    fontSize: 8,
    fontWeight: '700',
    color: SENSE_COLORS.electricBlue,
    letterSpacing: 0.8,
  },
  helplineBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: SENSE_COLORS.white,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: SENSE_RADII.pill,
    borderWidth: 1,
    borderColor: '#FFE0E4',
    ...SENSE_SHADOWS.card,
  },
  helplineText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#B42332',
    marginLeft: 4,
  },
});

