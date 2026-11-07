import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { SENSE_COLORS, SENSE_RADII, SENSE_SHADOWS, SENSE_SPACING } from '../theme/tokens';

export default function BottomNav({ activeTab, onSelectTab, onQuickCheckIn }) {
  const tabs = [
    { key: 'dashboard', label: 'Home', icon: 'home-outline', activeIcon: 'home' },
    { key: 'log_hub', label: 'Log', icon: 'grid-outline', activeIcon: 'grid' },
    { key: 'center_plus', isCenter: true },
    { key: 'insights', label: 'Insights', icon: 'stats-chart-outline', activeIcon: 'stats-chart' },
    { key: 'settings', label: 'Profile', icon: 'person-outline', activeIcon: 'person' },
  ];

  return (
    <View style={styles.container}>
      {tabs.map((tab, idx) => {
        if (tab.isCenter) {
          return (
            <View key="center_plus" style={styles.centerBtnContainer}>
              <TouchableOpacity
                onPress={onQuickCheckIn}
                activeOpacity={0.85}
                style={styles.centerBtnTouch}
              >
                <LinearGradient
                  colors={SENSE_COLORS.primaryGradient}
                  style={styles.centerGradient}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                >
                  <Ionicons name="add" size={28} color="#FFFFFF" />
                </LinearGradient>
              </TouchableOpacity>
            </View>
          );
        }

        const isActive = activeTab === tab.key;
        return (
          <TouchableOpacity
            key={tab.key}
            style={styles.tabItem}
            onPress={() => onSelectTab(tab.key)}
            activeOpacity={0.7}
          >
            <Ionicons
              name={isActive ? tab.activeIcon : tab.icon}
              size={22}
              color={isActive ? SENSE_COLORS.electricBlue : SENSE_COLORS.textMuted}
            />
            <Text
              style={[
                styles.tabLabel,
                { color: isActive ? SENSE_COLORS.navy : SENSE_COLORS.textMuted },
                isActive && { fontWeight: '700' },
              ]}
            >
              {tab.label}
            </Text>
            {isActive && <View style={styles.activeDot} />}
          </TouchableOpacity>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    height: 72,
    backgroundColor: SENSE_COLORS.white,
    borderTopWidth: 1,
    borderTopColor: SENSE_COLORS.border,
    alignItems: 'center',
    justifyContent: 'space-around',
    paddingHorizontal: SENSE_SPACING.base,
    position: 'relative',
    ...SENSE_SHADOWS.raised,
  },
  tabItem: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    height: '100%',
  },
  tabLabel: {
    fontSize: 10,
    marginTop: 3,
    color: SENSE_COLORS.textMuted,
  },
  activeDot: {
    width: 4,
    height: 4,
    borderRadius: 2,
    backgroundColor: SENSE_COLORS.electricBlue,
    marginTop: 2,
  },
  centerBtnContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    top: -14,
  },
  centerBtnTouch: {
    width: 52,
    height: 52,
    borderRadius: 26,
    ...SENSE_SHADOWS.glow,
  },
  centerGradient: {
    width: 52,
    height: 52,
    borderRadius: 26,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: '#FFFFFF',
  },
});

