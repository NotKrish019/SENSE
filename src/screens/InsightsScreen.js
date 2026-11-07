import React, { useState } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Dimensions } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Svg, { Path, Rect, Circle, Defs, LinearGradient as SvgGradient, Stop, Text as SvgText, G } from 'react-native-svg';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

const { width } = Dimensions.get('window');
const chartWidth = Math.min(width - 48, 360);

export default function InsightsScreen({ onNavigate }) {
  const [period, setPeriod] = useState('14D');

  // Trend points for 14-day spline
  const points = [
    { x: 20, y: 80, label: 'D1' },
    { x: 70, y: 72, label: 'D4' },
    { x: 120, y: 85, label: 'D7' },
    { x: 180, y: 55, label: 'D10' },
    { x: 240, y: 40, label: 'D12' },
    { x: 300, y: 46, label: 'D14' },
  ];

  // SVG Cubic Bezier path
  const splinePath = 'M 20 80 C 45 76, 55 72, 70 72 C 95 72, 105 85, 120 85 C 150 85, 160 55, 180 55 C 210 55, 220 40, 240 40 C 270 40, 280 46, 300 46';
  const fillPath = `${splinePath} L 300 120 L 20 120 Z`;

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Header and Period Selector */}
      <View style={styles.topRow}>
        <View>
          <Text style={styles.title}>Longitudinal Trends</Text>
          <Text style={styles.subtitle}>Baseline deviation & factor attribution</Text>
        </View>

        <View style={styles.periodSelector}>
          {['7D', '14D', '30D'].map((p) => (
            <TouchableOpacity
              key={p}
              style={[styles.periodBtn, period === p && styles.periodBtnActive]}
              onPress={() => setPeriod(p)}
            >
              <Text style={[styles.periodText, period === p && styles.periodTextActive]}>{p}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Spline Trend Chart Card */}
      <View style={styles.card}>
        <View style={styles.cardHeaderRow}>
          <Text style={styles.cardTitle}>Personalized Stress Trajectory</Text>
          <View style={styles.badgeCalm}>
            <Text style={styles.badgeCalmText}>Rolling Baseline</Text>
          </View>
        </View>
        <Text style={styles.helperText}>
          Smooth spline comparing daily fused stress indicator against your baseline (z-score normalized).
        </Text>

        <View style={styles.chartWrap}>
          <Svg width={chartWidth} height={140} viewBox="0 0 320 140">
            <Defs>
              <SvgGradient id="splineGrad" x1="0" y1="0" x2="0" y2="1">
                <Stop offset="0" stopColor={SENSE_COLORS.cyan} stopOpacity="0.45" />
                <Stop offset="1" stopColor={SENSE_COLORS.cyan} stopOpacity="0.0" />
              </SvgGradient>
            </Defs>

            {/* Baseline threshold line (y=65) */}
            <Path d="M 15 65 L 305 65" stroke="#CBDCE8" strokeDasharray="4 4" strokeWidth="1" />
            <SvgText x="18" y="60" fontSize="9" fill={SENSE_COLORS.textMuted}>BASELINE</SvgText>

            {/* Gradient fill */}
            <Path d={fillPath} fill="url(#splineGrad)" />

            {/* Main curve */}
            <Path d={splinePath} fill="none" stroke={SENSE_COLORS.electricBlue} strokeWidth="3" />

            {/* Data points */}
            {points.map((pt, i) => (
              <G key={i}>
                <Circle cx={pt.x} cy={pt.y} r="4" fill={SENSE_COLORS.secondaryBlue} stroke="#FFFFFF" strokeWidth="2" />
                <SvgText x={pt.x - 6} y="135" fontSize="9" fill={SENSE_COLORS.textMuted}>{pt.label}</SvgText>
              </G>
            ))}
          </Svg>
        </View>
      </View>

      {/* Donut Sleep Gauge & Factor Breakdown */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Factor Contribution Breakdown</Text>
        <Text style={styles.helperText}>
          Estimated contribution of individual modalities to recent elevated stress patterns:
        </Text>

        <View style={styles.donutRow}>
          {/* Donut Chart */}
          <View style={styles.donutWrap}>
            <Svg width={100} height={100} viewBox="0 0 100 100">
              <Circle cx="50" cy="50" r="40" stroke="#E2EFF7" strokeWidth="12" fill="none" />
              {/* Sleep 42% */}
              <Circle
                cx="50"
                cy="50"
                r="40"
                stroke={SENSE_COLORS.electricBlue}
                strokeWidth="12"
                strokeDasharray="105 251"
                strokeDashoffset="0"
                strokeLinecap="round"
                fill="none"
              />
              {/* Workload 31% */}
              <Circle
                cx="50"
                cy="50"
                r="40"
                stroke={SENSE_COLORS.cyan}
                strokeWidth="12"
                strokeDasharray="78 251"
                strokeDashoffset="-105"
                strokeLinecap="round"
                fill="none"
              />
            </Svg>
            <View style={styles.donutCenter}>
              <Text style={styles.donutVal}>42%</Text>
              <Text style={styles.donutSub}>Sleep Lead</Text>
            </View>
          </View>

          {/* Factor List */}
          <View style={styles.factorCol}>
            <View style={styles.factorItem}>
              <View style={[styles.factorDot, { backgroundColor: SENSE_COLORS.electricBlue }]} />
              <Text style={styles.factorName}>Sleep Deprivation</Text>
              <Text style={styles.factorPct}>42%</Text>
            </View>
            <View style={styles.factorItem}>
              <View style={[styles.factorDot, { backgroundColor: SENSE_COLORS.cyan }]} />
              <Text style={styles.factorName}>Cognitive Workload</Text>
              <Text style={styles.factorPct}>31%</Text>
            </View>
            <View style={styles.factorItem}>
              <View style={[styles.factorDot, { backgroundColor: '#02549B' }]} />
              <Text style={styles.factorName}>Acoustic/Voice Shift</Text>
              <Text style={styles.factorPct}>15%</Text>
            </View>
            <View style={styles.factorItem}>
              <View style={[styles.factorDot, { backgroundColor: SENSE_COLORS.calm }]} />
              <Text style={styles.factorName}>Physical Activity Drop</Text>
              <Text style={styles.factorPct}>12%</Text>
            </View>
          </View>
        </View>

        {/* Explainability Button */}
        <TouchableOpacity
          style={styles.detailBtn}
          onPress={() => onNavigate('insight_detail')}
          activeOpacity={0.8}
        >
          <Text style={styles.detailBtnText}>View Explainability Breakdown →</Text>
        </TouchableOpacity>
      </View>

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
  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SENSE_SPACING.md,
  },
  title: {
    fontSize: 20,
    fontWeight: '800',
    color: SENSE_COLORS.textPrimary,
  },
  subtitle: {
    fontSize: 11,
    color: SENSE_COLORS.textSecondary,
    marginTop: 2,
  },
  periodSelector: {
    flexDirection: 'row',
    backgroundColor: SENSE_COLORS.surface,
    borderRadius: SENSE_RADII.pill,
    padding: 3,
    borderWidth: 1,
    borderColor: SENSE_COLORS.border,
  },
  periodBtn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: SENSE_RADII.pill,
  },
  periodBtnActive: {
    backgroundColor: SENSE_COLORS.secondaryBlue,
  },
  periodText: {
    fontSize: 10,
    fontWeight: '700',
    color: SENSE_COLORS.textMuted,
  },
  periodTextActive: {
    color: '#FFFFFF',
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
  badgeCalm: {
    backgroundColor: '#E6F4EA',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: SENSE_RADII.pill,
  },
  badgeCalmText: {
    fontSize: 10,
    fontWeight: '700',
    color: SENSE_COLORS.calm,
  },
  helperText: {
    fontSize: 11,
    color: SENSE_COLORS.textMuted,
    marginTop: 2,
    marginBottom: 10,
    lineHeight: 16,
  },
  chartWrap: {
    alignItems: 'center',
    justifyContent: 'center',
    marginVertical: 4,
  },
  donutRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
  },
  donutWrap: {
    position: 'relative',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 16,
  },
  donutCenter: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
  },
  donutVal: {
    fontSize: 16,
    fontWeight: '800',
    color: SENSE_COLORS.textPrimary,
  },
  donutSub: {
    fontSize: 8,
    fontWeight: '700',
    color: SENSE_COLORS.textMuted,
  },
  factorCol: {
    flex: 1,
  },
  factorItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 4,
  },
  factorDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 8,
  },
  factorName: {
    flex: 1,
    fontSize: 12,
    color: SENSE_COLORS.textPrimary,
  },
  factorPct: {
    fontSize: 12,
    fontWeight: '700',
    color: SENSE_COLORS.secondaryBlue,
  },
  detailBtn: {
    marginTop: 12,
    paddingVertical: 10,
    borderRadius: SENSE_RADII.md,
    backgroundColor: '#EDF5FA',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#D4E6F2',
  },
  detailBtnText: {
    fontSize: 12,
    fontWeight: '700',
    color: SENSE_COLORS.secondaryBlue,
  },
});

