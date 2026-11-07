import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function DashboardScreen({ onNavigate }) {
  const quickActions = [
    { key: 'check_in', title: 'Check-in', sub: 'Mood & Stress', icon: 'happy-outline', color: '#059BE0' },
    { key: 'journal', title: 'Journal', sub: 'Encrypted Notes', icon: 'create-outline', color: '#07CCFC' },
    { key: 'sleep', title: 'Sleep', sub: 'Rest & Recovery', icon: 'moon-outline', color: '#58E2F9' },
    { key: 'workload', title: 'Workload', sub: 'NASA-TLX Load', icon: 'briefcase-outline', color: '#02549B' },
    { key: 'voice', title: 'Voice', sub: 'Audio Check-in', icon: 'mic-outline', color: '#012F5F' },
    { key: 'activity', title: 'Activity', sub: 'Movement Steps', icon: 'walk-outline', color: '#087F6E' },
  ];

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Non-clinical banner */}
      <View style={styles.disclaimerBanner}>
        <Ionicons name="information-circle-outline" size={16} color={SENSE_COLORS.electricBlue} />
        <Text style={styles.disclaimerText}>
          Non-clinical research prototype. For personalized well-being self-reflection only.
        </Text>
      </View>

      {/* Hero Stress Summary Card */}
      <LinearGradient
        colors={SENSE_COLORS.heroGradient}
        style={styles.heroCard}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
      >
        <View style={styles.heroTopRow}>
          <View style={styles.heroIconCircle}>
            <Ionicons name="pulse" size={20} color={SENSE_COLORS.cyan} />
          </View>
          <View style={{ flex: 1, marginLeft: 12 }}>
            <Text style={styles.heroOverline}>CURRENT STATE</Text>
            <Text style={styles.heroTitle}>Moderate Pattern</Text>
          </View>
          <View style={styles.deltaBadge}>
            <Ionicons name="arrow-up" size={12} color="#FFFFFF" />
            <Text style={styles.deltaText}>+12% vs base</Text>
          </View>
        </View>

        <Text style={styles.heroDesc}>
          Composite indicator elevated relative to your 14-day rolling baseline, primarily coinciding with reduced sleep duration.
        </Text>

        {/* Progress bar */}
        <View style={styles.progressContainer}>
          <View style={styles.progressLabels}>
            <Text style={styles.progressLabel}>Stress Index</Text>
            <Text style={styles.progressValue}>58 / 100</Text>
          </View>
          <View style={styles.progressBarBg}>
            <LinearGradient
              colors={SENSE_COLORS.progressGradient}
              style={[styles.progressBarFill, { width: '58%' }]}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 0 }}
            />
          </View>
        </View>
      </LinearGradient>

      {/* Quick Action Grid (3x2) */}
      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Input Modalities</Text>
        <Text style={styles.sectionBadge}>6 Voluntary</Text>
      </View>

      <View style={styles.gridContainer}>
        {quickActions.map((action) => (
          <TouchableOpacity
            key={action.key}
            style={styles.gridTile}
            onPress={() => onNavigate(action.key)}
            activeOpacity={0.75}
          >
            <View style={[styles.tileIconCircle, { backgroundColor: `${action.color}15` }]}>
              <Ionicons name={action.icon} size={22} color={action.color} />
            </View>
            <Text style={styles.tileTitle}>{action.title}</Text>
            <Text style={styles.tileSub}>{action.sub}</Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* Recent Insight Card */}
      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>Recent Observation</Text>
        <TouchableOpacity onPress={() => onNavigate('insights')}>
          <Text style={styles.viewAllText}>View Trends →</Text>
        </TouchableOpacity>
      </View>

      <TouchableOpacity
        style={styles.insightCard}
        onPress={() => onNavigate('insight_detail')}
        activeOpacity={0.8}
      >
        <View style={styles.insightTopRow}>
          <View style={styles.insightIconCircle}>
            <Ionicons name="bulb-outline" size={18} color={SENSE_COLORS.secondaryBlue} />
          </View>
          <View style={styles.provenanceBadge}>
            <Text style={styles.provenanceText}>Observed pattern</Text>
          </View>
          <Ionicons name="chevron-forward" size={18} color={SENSE_COLORS.textMuted} />
        </View>

        <Text style={styles.insightHeadline}>Sleep reduction preceded workload stress peak</Text>
        <Text style={styles.insightBody}>
          Over the past 5 days, sleep duration fell to 5.8h (vs personal baseline 7.2h). Perceived workload strain subsequently rose by 1.4 SD.
        </Text>

        <View style={styles.confidenceRow}>
          <View style={styles.confidenceDot} />
          <Text style={styles.confidenceText}>High baseline confidence (21 days evaluated)</Text>
        </View>
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
  disclaimerBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#EDF7FC',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: SENSE_RADII.md,
    marginBottom: SENSE_SPACING.md,
    borderWidth: 1,
    borderColor: '#D0E7F5',
  },
  disclaimerText: {
    fontSize: 11,
    color: SENSE_COLORS.textSecondary,
    marginLeft: 6,
    flex: 1,
  },
  heroCard: {
    borderRadius: SENSE_RADII.xl,
    padding: SENSE_SPACING.lg,
    marginBottom: SENSE_SPACING.lg,
    ...SENSE_SHADOWS.hero,
  },
  heroTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  heroIconCircle: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: 'rgba(255, 255, 255, 0.15)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroOverline: {
    fontSize: 10,
    fontWeight: '700',
    color: SENSE_COLORS.softCyan,
    letterSpacing: 1,
  },
  heroTitle: {
    fontSize: 20,
    fontWeight: '800',
    color: SENSE_COLORS.white,
  },
  deltaBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.20)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: SENSE_RADII.pill,
  },
  deltaText: {
    fontSize: 10,
    fontWeight: '700',
    color: '#FFFFFF',
    marginLeft: 3,
  },
  heroDesc: {
    fontSize: 12,
    color: '#D4E8F8',
    lineHeight: 18,
    marginTop: 6,
    marginBottom: 14,
  },
  progressContainer: {
    marginTop: 4,
  },
  progressLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 6,
  },
  progressLabel: {
    fontSize: 11,
    color: '#D4E8F8',
    fontWeight: '600',
  },
  progressValue: {
    fontSize: 11,
    color: SENSE_COLORS.cyan,
    fontWeight: '700',
  },
  progressBarBg: {
    height: 8,
    borderRadius: 4,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: 4,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SENSE_SPACING.md,
    marginTop: 4,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  sectionBadge: {
    fontSize: 11,
    fontWeight: '600',
    color: SENSE_COLORS.electricBlue,
    backgroundColor: SENSE_COLORS.surface,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: SENSE_RADII.pill,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
  },
  viewAllText: {
    fontSize: 12,
    fontWeight: '600',
    color: SENSE_COLORS.electricBlue,
  },
  gridContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginBottom: SENSE_SPACING.lg,
  },
  gridTile: {
    width: '48%',
    backgroundColor: SENSE_COLORS.surface,
    borderRadius: SENSE_RADII.lg,
    padding: SENSE_SPACING.md,
    marginBottom: SENSE_SPACING.md,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    ...SENSE_SHADOWS.card,
  },
  tileIconCircle: {
    width: 42,
    height: 42,
    borderRadius: 21,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 10,
  },
  tileTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
  },
  tileSub: {
    fontSize: 11,
    color: SENSE_COLORS.textMuted,
    marginTop: 2,
  },
  insightCard: {
    backgroundColor: SENSE_COLORS.surface,
    borderRadius: SENSE_RADII.lg,
    padding: SENSE_SPACING.base,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
    ...SENSE_SHADOWS.card,
  },
  insightTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  insightIconCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#E6F4FE',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 8,
  },
  provenanceBadge: {
    backgroundColor: '#E8F1F9',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: SENSE_RADII.pill,
    flex: 1,
  },
  provenanceText: {
    fontSize: 10,
    fontWeight: '700',
    color: SENSE_COLORS.secondaryBlue,
  },
  insightHeadline: {
    fontSize: 15,
    fontWeight: '700',
    color: SENSE_COLORS.textPrimary,
    marginBottom: 6,
  },
  insightBody: {
    fontSize: 12,
    color: SENSE_COLORS.textSecondary,
    lineHeight: 18,
    marginBottom: 10,
  },
  confidenceRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  confidenceDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: SENSE_COLORS.calm,
    marginRight: 6,
  },
  confidenceText: {
    fontSize: 11,
    color: SENSE_COLORS.textMuted,
  },
});

