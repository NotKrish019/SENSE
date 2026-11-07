"""
Feature Preprocessor & Signal Extraction Layer for MindPulse.
Standardizes raw daily logs, extracts lexical/affective markers,
and performs deterministic on-device safety keyword scanning.
"""

import re
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple


# Lexicon for lightweight, on-device affective sentiment parsing
POSITIVE_LEXICON = {
    "good", "great", "calm", "peaceful", "happy", "relaxed", "productive",
    "accomplished", "rested", "energized", "clear", "grateful", "confident",
    "balanced", "smooth", "content", "joy", "supported", "refreshed"
}

NEGATIVE_LEXICON = {
    "stressed", "tired", "exhausted", "overwhelmed", "anxious", "worried",
    "frustrated", "angry", "sad", "drained", "hectic", "chaotic", "furious",
    "struggling", "depressed", "nervous", "tense", "burnout", "hopeless"
}

TENTATIVE_LEXICON = {
    "maybe", "perhaps", "guess", "unsure", "wonder", "suppose", "doubt",
    "possibly", "hesitant", "confused", "uncertain"
}

FIRST_PERSON_PRONOUNS = {"i", "me", "my", "mine", "myself"}

CRISIS_REGEX = re.compile(
    r"\b(suicide|kill myself|end my life|want to die|hang myself|slit my wrist|take all my pills|no reason to live)\b",
    re.IGNORECASE
)


@dataclass
class PreprocessedTextResult:
    word_count: int
    sentiment_polarity: float
    sentiment_subjectivity: float
    first_person_pronoun_ratio: float
    cognitive_tentative_ratio: float
    contains_crisis_markers: bool


class SignalPreprocessor:
    """Standardizes inputs and extracts numerical features across modalities."""

    @staticmethod
    def check_crisis_markers(text: str) -> bool:
        """Deterministic safety regex interceptor for acute distress expressions."""
        if not text or not text.strip():
            return False
        return bool(CRISIS_REGEX.search(text))

    @classmethod
    def process_journal_text(cls, text: str) -> PreprocessedTextResult:
        """Extracts word count, sentiment polarity, pronoun density, and crisis markers."""
        clean_text = text.strip()
        if not clean_text:
            return PreprocessedTextResult(0, 0.0, 0.0, 0.0, 0.0, False)

        has_crisis = cls.check_crisis_markers(clean_text)
        tokens = re.findall(r"\b[a-z']+\b", clean_text.lower())
        total_tokens = len(tokens)

        if total_tokens == 0:
            return PreprocessedTextResult(0, 0.0, 0.0, 0.0, 0.0, has_crisis)

        pos_count = sum(1 for t in tokens if t in POSITIVE_LEXICON)
        neg_count = sum(1 for t in tokens if t in NEGATIVE_LEXICON)
        pronoun_count = sum(1 for t in tokens if t in FIRST_PERSON_PRONOUNS)
        tentative_count = sum(1 for t in tokens if t in TENTATIVE_LEXICON)

        # Polarity in [-1.0, 1.0]
        total_affect = pos_count + neg_count
        if total_affect > 0:
            polarity = (pos_count - neg_count) / float(total_affect)
            subjectivity = total_affect / float(total_tokens)
        else:
            polarity = 0.0
            subjectivity = 0.0

        return PreprocessedTextResult(
            word_count=total_tokens,
            sentiment_polarity=max(-1.0, min(1.0, polarity)),
            sentiment_subjectivity=max(0.0, min(1.0, subjectivity)),
            first_person_pronoun_ratio=pronoun_count / float(total_tokens),
            cognitive_tentative_ratio=tentative_count / float(total_tokens),
            contains_crisis_markers=has_crisis,
        )

    @staticmethod
    def process_sleep(total_sleep_minutes: int) -> float:
        """Converts sleep minutes to total sleep hours, bounded between 2.0 and 16.0."""
        hours = total_sleep_minutes / 60.0
        return max(2.0, min(16.0, hours))

    @staticmethod
    def process_workload(mental_demand: int, effort: int, deadlines: int = 0) -> float:
        """
        Combines NASA-TLX mental demand and effort with deadline urgency.
        Returns workload intensity scalar.
        """
        demand_clamped = max(1, min(5, mental_demand))
        effort_clamped = max(1, min(5, effort))
        deadlines_clamped = max(0, min(10, deadlines))

        # Weighted index
        return 0.5 * demand_clamped + 0.5 * effort_clamped + 0.2 * min(deadlines_clamped, 5)

    @staticmethod
    def assess_checkin_quality(completion_latency_sec: float) -> float:
        """
        Validates check-in response duration sanity.
        If completion latency < 2.0s (likely hurried tapping), lowers reliability weight.
        """
        if completion_latency_sec < 2.0:
            return 0.40  # Discount rapid random taps
        if completion_latency_sec < 4.0:
            return 0.75
        return 1.00

