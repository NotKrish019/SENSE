import React, { useState } from 'react';
import { StyleSheet, View, SafeAreaView, Platform, StatusBar as RNStatusBar } from 'react-native';
import { StatusBar } from 'expo-status-bar';

import { SENSE_COLORS } from './src/theme/tokens';
import Header from './src/components/Header';
import BottomNav from './src/components/BottomNav';
import CrisisModal from './src/components/CrisisModal';

// Screens
import DashboardScreen from './src/screens/DashboardScreen';
import CheckInScreen from './src/screens/CheckInScreen';
import JournalScreen from './src/screens/JournalScreen';
import SleepScreen from './src/screens/SleepScreen';
import WorkloadScreen from './src/screens/WorkloadScreen';
import VoiceScreen from './src/screens/VoiceScreen';
import ActivityScreen from './src/screens/ActivityScreen';
import InsightsScreen from './src/screens/InsightsScreen';
import InsightDetailScreen from './src/screens/InsightDetailScreen';
import SettingsScreen from './src/screens/SettingsScreen';
import LogHubScreen from './src/screens/LogHubScreen';
import OnboardingScreen from './src/screens/OnboardingScreen';

export default function App() {
  const [currentScreen, setCurrentScreen] = useState('dashboard');
  const [screenHistory, setScreenHistory] = useState(['dashboard']);
  const [crisisVisible, setCrisisVisible] = useState(false);

  const navigateTo = (screen) => {
    setScreenHistory((prev) => [...prev, screen]);
    setCurrentScreen(screen);
  };

  const goBack = () => {
    if (screenHistory.length > 1) {
      const nextHistory = [...screenHistory];
      nextHistory.pop();
      const prevScreen = nextHistory[nextHistory.length - 1];
      setScreenHistory(nextHistory);
      setCurrentScreen(prevScreen);
    } else {
      setCurrentScreen('dashboard');
    }
  };

  const renderScreen = () => {
    switch (currentScreen) {
      case 'onboarding':
        return <OnboardingScreen onFinish={() => setCurrentScreen('dashboard')} />;
      case 'dashboard':
        return <DashboardScreen onNavigate={navigateTo} />;
      case 'check_in':
        return <CheckInScreen onBack={goBack} />;
      case 'journal':
        return <JournalScreen onBack={goBack} onOpenCrisis={() => setCrisisVisible(true)} />;
      case 'sleep':
        return <SleepScreen onBack={goBack} />;
      case 'workload':
        return <WorkloadScreen onBack={goBack} />;
      case 'voice':
        return <VoiceScreen onBack={goBack} />;
      case 'activity':
        return <ActivityScreen onBack={goBack} />;
      case 'insights':
        return <InsightsScreen onNavigate={navigateTo} />;
      case 'insight_detail':
        return <InsightDetailScreen onBack={goBack} onOpenCrisis={() => setCrisisVisible(true)} />;
      case 'log_hub':
        return <LogHubScreen onNavigate={navigateTo} />;
      case 'settings':
        return <SettingsScreen onOpenCrisis={() => setCrisisVisible(true)} />;
      default:
        return <DashboardScreen onNavigate={navigateTo} />;
    }
  };

  const isPrimaryScreen = ['dashboard', 'log_hub', 'insights', 'settings'].includes(currentScreen);

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="dark" backgroundColor={SENSE_COLORS.background} />
      
      {currentScreen !== 'onboarding' && (
        <Header
          currentScreen={currentScreen}
          onOpenCrisis={() => setCrisisVisible(true)}
          onBack={goBack}
        />
      )}

      <View style={styles.body}>
        {renderScreen()}
      </View>

      {isPrimaryScreen && (
        <BottomNav
          activeTab={currentScreen}
          onSelectTab={(tab) => {
            setScreenHistory([tab]);
            setCurrentScreen(tab);
          }}
          onQuickCheckIn={() => navigateTo('check_in')}
        />
      )}

      <CrisisModal
        visible={crisisVisible}
        onClose={() => setCrisisVisible(false)}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: SENSE_COLORS.background,
    paddingTop: Platform.OS === 'android' ? RNStatusBar.currentHeight : 0,
  },
  body: {
    flex: 1,
  },
});

