# MindPulse (SENSE) — Safety Requirements & Crisis Protocols
## Clinical Safety Boundaries, Crisis Interception & Distress Safeguards

---

## 1. Non-Clinical Safety Stance

MindPulse operates under a strict, non-negotiable **Non-Clinical Safety Mandate**:
- MindPulse is **NOT** a medical diagnostic instrument, psychiatric therapy tool, or emergency triage service.
- The system must explicitly present a persistent, non-dismissible safety disclaimer on initial launch and within the application settings:
  > *"MindPulse is a personal digital well-being research tool designed to help you track lifestyle patterns. It does not provide medical diagnoses, psychiatric evaluation, or clinical treatment. If you are experiencing acute distress, thoughts of self-harm, or a mental health emergency, please contact professional healthcare services or emergency helplines immediately."*

---

## 2. Independent Crisis Safety Gateway

The Crisis Safety Panel is an independent, permanently visible UI element accessible from the top navigation bar of every application screen. It operates completely out-of-band from the ML inference engine:

```text
┌────────────────────────────────────────────────────────┐
│ [!] IMMEDIATE CRISIS & EMOTIONAL SUPPORT RESOURCES     │
├────────────────────────────────────────────────────────┤
│ If you or someone you know is struggling or in crisis, │
│ free, confidential, 24/7 support is available:         │
│                                                        │
│ [ Call Tele-MANAS (Govt. of India) ]                   │
│   Dial: 14416 or 1800-891-4416                         │
│                                                        │
│ [ Call KIRAN Mental Health Helpline ]                  │
│   Dial: 1800-599-0019                                  │
│                                                        │
│ [ Call Vandrevala Foundation Helpline ]                │
│   Dial: +91 9999 666 555                               │
│                                                        │
│ [ Call AASRA Suicide Prevention ]                      │
│   Dial: +91 98204 66726                                │
│                                                        │
│ [ International Resources (Befrienders Worldwide) ]    │
│   Visit: https://www.befrienders.org                   │
└────────────────────────────────────────────────────────┘
```

---

## 3. On-Device Crisis Keyword Interceptor

While MindPulse does not use AI to triage mental health crises, the voluntary text journal editor (M2) includes a deterministic, client-side safety interceptor.

### 3.1 Interceptor Logic
When the user types or saves a journal entry, a lightweight, on-device regex scanner scans for overt expressions of acute self-harm, suicidal ideation, or desperate distress:
```regex
\b(suicide|kill myself|end my life|want to die|hang myself|slit my wrist|take all my pills|no reason to live)\b
```

### 3.2 Action Protocol
1. **Immediate Supportive Dialog:** If an acute distress phrase is detected, the app immediately displays an empathetic modal sheet:
   > *"We noticed you might be going through an overwhelming moment. You don't have to carry this alone. Please reach out to someone who can support you right now."*
2. **Direct Dialer:** The dialog provides direct, single-tap dialer buttons for **Tele-MANAS** and **KIRAN**.
3. **No Coercive Blocking or Spying:** The user can still save their journal if they choose; the application does not report the text to external authorities, police, employers, or research staff, avoiding punitive or stigmatizing surveillance.

---

## 4. Mitigation of the "Nocebo" Effect & False-Alarm Anxiety

Over-alerting users to every minor stress fluctuation can induce health anxiety and hyper-vigilance (the *Nocebo* effect). MindPulse enforces three specific mitigation controls:

1. **Conservative Multi-Day Persistence:** Alerts are never triggered on a single high-stress day. An alert requires a statistically significant deviation ($z > 2.0$) sustained across at least $\ge 3$ consecutive days.
2. **Neutral, Supportive Tone:** Inferences avoid alarming red badges or clinical language (*"Severe Stress Detected!"*). Instead, the system uses calming, empowering, psychoeducational language (*"Your recorded rest and workload have been out of rhythm over the past few days. Here are some gentle ways to restore balance."*).
3. **User-Controlled Sensitivity:** Users can adjust alert threshold sensitivity (Low, Medium, Conservative) in settings to match their personal comfort level.

