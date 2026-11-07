import React from 'react';
import { View, Text, StyleSheet, Modal, TouchableOpacity, Linking, Platform } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function CrisisModal({ visible, onClose }) {
  const callNumber = (num) => {
    Linking.openURL(`tel:${num}`);
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
    >
      <View style={styles.overlay}>
        <View style={styles.modalContent}>
          <View style={styles.headerRow}>
            <View style={styles.iconCircle}>
              <Ionicons name="heart" size={24} color="#B42332" />
            </View>
            <View style={{ flex: 1, marginLeft: 12 }}>
              <Text style={styles.title}>24/7 Support & Care</Text>
              <Text style={styles.subtitle}>Free, confidential mental health helplines</Text>
            </View>
            <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
              <Ionicons name="close" size={22} color={SENSE_COLORS.textSecondary} />
            </TouchableOpacity>
          </View>

          <View style={styles.noticeBox}>
            <Text style={styles.noticeText}>
              SENSE is a research well-being tool, not an emergency service. If you are in distress or need someone to talk to right now, compassionate counselors are available 24/7.
            </Text>
          </View>

          {/* Tele-MANAS Card */}
          <TouchableOpacity 
            style={styles.helplineCard}
            onPress={() => callNumber('14416')}
            activeOpacity={0.8}
          >
            <View style={{ flex: 1 }}>
              <View style={styles.tagRow}>
                <Text style={styles.helplineName}>Tele-MANAS</Text>
                <View style={styles.tollFreeBadge}>
                  <Text style={styles.tollFreeText}>TOLL FREE</Text>
                </View>
              </View>
              <Text style={styles.helplineDesc}>National Mental Health Programme (India) — 20+ Languages</Text>
              <Text style={styles.phoneNum}>14416 / 1800-891-4416</Text>
            </View>
            <View style={styles.callIconBtn}>
              <Ionicons name="call" size={20} color="#FFFFFF" />
            </View>
          </TouchableOpacity>

          {/* KIRAN Card */}
          <TouchableOpacity 
            style={styles.helplineCard}
            onPress={() => callNumber('18005990019')}
            activeOpacity={0.8}
          >
            <View style={{ flex: 1 }}>
              <View style={styles.tagRow}>
                <Text style={styles.helplineName}>KIRAN Helpline</Text>
                <View style={styles.tollFreeBadge}>
                  <Text style={styles.tollFreeText}>24/7 GOVT</Text>
                </View>
              </View>
              <Text style={styles.helplineDesc}>Ministry of Social Justice & Empowerment</Text>
              <Text style={styles.phoneNum}>1800-599-0019</Text>
            </View>
            <View style={styles.callIconBtn}>
              <Ionicons name="call" size={20} color="#FFFFFF" />
            </View>
          </TouchableOpacity>

          {/* Dismiss button */}
          <TouchableOpacity style={styles.dismissBtn} onPress={onClose}>
            <Text style={styles.dismissText}>Close Support Sheet</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(1, 47, 95, 0.45)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: SENSE_SPACING.base,
  },
  modalContent: {
    backgroundColor: SENSE_COLORS.white,
    borderRadius: SENSE_RADII.xl,
    padding: SENSE_SPACING.xl,
    width: '100%',
    maxWidth: 420,
    ...SENSE_SHADOWS.raised,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SENSE_SPACING.md,
  },
  iconCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#FFEBEF',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 18,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  subtitle: {
    fontSize: 12,
    color: SENSE_COLORS.textSecondary,
    marginTop: 2,
  },
  closeBtn: {
    padding: 6,
  },
  noticeBox: {
    backgroundColor: '#F0F7FD',
    borderRadius: SENSE_RADII.md,
    padding: SENSE_SPACING.md,
    marginBottom: SENSE_SPACING.md,
    borderLeftWidth: 3,
    borderLeftColor: SENSE_COLORS.electricBlue,
  },
  noticeText: {
    fontSize: 12,
    color: SENSE_COLORS.textSecondary,
    lineHeight: 18,
  },
  helplineCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: SENSE_COLORS.surface,
    padding: SENSE_SPACING.md,
    borderRadius: SENSE_RADII.lg,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    marginBottom: SENSE_SPACING.md,
    ...SENSE_SHADOWS.card,
  },
  tagRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 2,
  },
  helplineName: {
    fontSize: 15,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  tollFreeBadge: {
    backgroundColor: '#E6F4EA',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: SENSE_RADII.pill,
    marginLeft: 8,
  },
  tollFreeText: {
    fontSize: 9,
    fontWeight: '700',
    color: SENSE_COLORS.calm,
  },
  helplineDesc: {
    fontSize: 11,
    color: SENSE_COLORS.textMuted,
    marginBottom: 4,
  },
  phoneNum: {
    fontSize: 14,
    fontWeight: '700',
    color: SENSE_COLORS.secondaryBlue,
  },
  callIconBtn: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: SENSE_COLORS.electricBlue,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 10,
    ...SENSE_SHADOWS.glow,
  },
  dismissBtn: {
    paddingVertical: 12,
    alignItems: 'center',
    marginTop: 4,
  },
  dismissText: {
    fontSize: 13,
    fontWeight: '600',
    color: SENSE_COLORS.textSecondary,
  },
});

