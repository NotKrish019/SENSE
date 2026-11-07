"""
MindPulse Core System Pipeline.
Orchestrates ingestion, preprocessing, local storage, personal baseline calibration,
temporal change detection, multimodal late fusion, and crisis interception.
"""

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import uuid
import numpy as np

from backend.database import DatabaseManager
from backend.preprocessor import SignalPreprocessor
from ml.baseline.engine import PersonalBaselineEngine, BaselineConfig
from ml.fusion.late_fusion import DynamicLateFusionEngine, FusionConfig, FusionOutput


@dataclass
class PipelineInferenceResult:
    user_id: str
    date_epoch: str
    is_calibrated: bool
    calibration_day_count: int
    composite_stress_score: float
    is_alert_triggered: bool
    epistemic_uncertainty: float
    primary_contributor: str
    factor_attributions: Dict[str, float]
    explanation_narrative: str
    crisis_safety_triggered: bool


class MindPulsePipeline:
    """End-to-end processing pipeline orchestrating storage, ML engines, and safety."""

    def __init__(self, db: Optional[DatabaseManager] = None):
        self.db = db or DatabaseManager()
        self.baseline_engine = PersonalBaselineEngine(BaselineConfig(window_size=14, min_calibration_points=7))
        self.fusion_engine = DynamicLateFusionEngine(FusionConfig())
        self.preprocessor = SignalPreprocessor()

    def process_daily_intake(
        self,
        user_id: str,
        date_epoch: str,
        check_in: Optional[Dict[str, Any]] = None,
        sleep: Optional[Dict[str, Any]] = None,
        workload: Optional[Dict[str, Any]] = None,
        journal_text: Optional[str] = None,
    ) -> PipelineInferenceResult:
        """
        Processes a daily intake packet, saves all records to the local database,
        computes within-person standardized deviations against history, evaluates
        multimodal late fusion, and returns a verified inference result.
        """
        crisis_triggered = False

        # 1. Process and store M1: Structured Check-in
        checkin_quality = 1.0
        if check_in:
            cid = check_in.get("check_in_id") or str(uuid.uuid4())
            latency = check_in.get("completion_latency_sec", 15.0)
            checkin_quality = self.preprocessor.assess_checkin_quality(latency)
            self.db.insert_check_in({
                "check_in_id": cid,
                "user_id": user_id,
                "timestamp_utc": check_in.get("timestamp_utc", f"{date_epoch}T20:00:00Z"),
                "session_type": check_in.get("session_type", "EVENING"),
                "perceived_stress": int(check_in["perceived_stress"]),
                "mood_valence": int(check_in.get("mood_valence", 3)),
                "mood_arousal": int(check_in.get("mood_arousal", 3)),
                "motivation_level": check_in.get("motivation_level"),
                "completion_latency_sec": latency,
            })

        # 2. Process and store M3: Sleep
        curr_sleep_hours = None
        if sleep:
            sid = sleep.get("sleep_id") or str(uuid.uuid4())
            total_mins = int(sleep["total_sleep_minutes"])
            curr_sleep_hours = self.preprocessor.process_sleep(total_mins)
            self.db.insert_sleep({
                "sleep_id": sid,
                "user_id": user_id,
                "date_epoch": date_epoch,
                "bedtime_utc": sleep.get("bedtime_utc", f"{date_epoch}T23:30:00Z"),
                "wake_time_utc": sleep.get("wake_time_utc", f"{date_epoch}T07:15:00Z"),
                "total_sleep_minutes": total_mins,
                "sleep_quality_rating": sleep.get("sleep_quality_rating", 3),
                "source_type": sleep.get("source_type", "MANUAL_LOG"),
            })

        # 3. Process and store M4: Workload
        curr_workload_intensity = None
        if workload:
            wid = workload.get("workload_id") or str(uuid.uuid4())
            curr_workload_intensity = self.preprocessor.process_workload(
                mental_demand=int(workload["mental_demand_rating"]),
                effort=int(workload.get("effort_rating", 3)),
                deadlines=int(workload.get("impending_deadlines_count", 0)),
            )
            self.db.insert_workload({
                "workload_id": wid,
                "user_id": user_id,
                "date_epoch": date_epoch,
                "mental_demand_rating": int(workload["mental_demand_rating"]),
                "effort_rating": int(workload.get("effort_rating", 3)),
                "tasks_completed_count": workload.get("tasks_completed_count"),
                "impending_deadlines_count": workload.get("impending_deadlines_count"),
            })

        # 4. Process and store M2: Text Journal with Safety Interceptor
        curr_sentiment = None
        if journal_text is not None and journal_text.strip():
            text_result = self.preprocessor.process_journal_text(journal_text)
            if text_result.contains_crisis_markers:
                crisis_triggered = True

            curr_sentiment = text_result.sentiment_polarity
            jid = str(uuid.uuid4())
            self.db.insert_journal({
                "journal_id": jid,
                "user_id": user_id,
                "timestamp_utc": f"{date_epoch}T21:00:00Z",
                "raw_text_encrypted": journal_text.strip(),
                "word_count": text_result.word_count,
                "sentiment_polarity": text_result.sentiment_polarity,
                "sentiment_subjectivity": text_result.sentiment_subjectivity,
                "first_person_pronoun_ratio": text_result.first_person_pronoun_ratio,
                "cognitive_tentative_ratio": text_result.cognitive_tentative_ratio,
            })

        # 5. Fetch rolling historical buffer strictly prior to date_epoch (causal lookback)
        history = self.db.get_rolling_history(user_id=user_id, before_date=date_epoch, lookback_days=14)
        calibration_days = self.db.get_calibration_days_count(user_id)
        is_calibrated = (calibration_days >= 14)

        # 6. Calculate Within-Person Baseline & Deviations (z-scores)
        z_scores: Dict[str, Optional[float]] = {
            "check_in": None,
            "sleep": None,
            "workload": None,
            "journal": None,
            "voice": None,
            "activity": None,
        }

        # Check-in deviation
        stress_mean, stress_std = None, None
        if check_in and len(history["stress"]) >= 3:
            stress_hist = np.array(history["stress"])
            stress_mean = float(np.median(stress_hist))
            stress_std = float(self.baseline_engine.compute_mad(stress_hist))
            z_scores["check_in"] = (check_in["perceived_stress"] - stress_mean) / max(stress_std, 1e-4)

        # Sleep deviation
        sleep_mean, sleep_std = None, None
        if curr_sleep_hours is not None and len(history["sleep"]) >= 3:
            sleep_hist = np.array(history["sleep"])
            sleep_mean = float(np.median(sleep_hist))
            sleep_std = float(self.baseline_engine.compute_mad(sleep_hist))
            z_scores["sleep"] = (curr_sleep_hours - sleep_mean) / max(sleep_std, 1e-4)

        # Workload deviation
        workload_mean, workload_std = None, None
        if curr_workload_intensity is not None and len(history["workload"]) >= 3:
            workload_hist = np.array(history["workload"])
            workload_mean = float(np.median(workload_hist))
            workload_std = float(self.baseline_engine.compute_mad(workload_hist))
            z_scores["workload"] = (curr_workload_intensity - workload_mean) / max(workload_std, 1e-4)

        # Journal sentiment deviation
        if curr_sentiment is not None and len(history["sentiment"]) >= 3:
            sent_hist = np.array(history["sentiment"])
            sent_mean = float(np.median(sent_hist))
            sent_std = float(self.baseline_engine.compute_mad(sent_hist))
            z_scores["journal"] = (curr_sentiment - sent_mean) / max(sent_std, 1e-4)

        # Store updated baseline state
        bid = str(uuid.uuid4())
        self.db.insert_baseline({
            "baseline_id": bid,
            "user_id": user_id,
            "date_epoch": date_epoch,
            "calibration_day_count": calibration_days,
            "is_calibrated": is_calibrated,
            "sleep_mean_hours": sleep_mean,
            "sleep_std_hours": sleep_std,
            "stress_mean_rating": stress_mean,
            "stress_std_rating": stress_std,
            "workload_mean_rating": workload_mean,
            "workload_std_rating": workload_std,
        })

        # 7. Execute Dynamic Late Decision Fusion
        qualities = {"check_in": checkin_quality}
        fusion_out = self.fusion_engine.fuse_epoch(z_scores, qualities)

        # If still in calibration phase (< 14 days), suppress alerts to avoid false alarms
        effective_alert = fusion_out.is_alert_triggered and is_calibrated
        narrative = fusion_out.explanation_narrative
        if not is_calibrated:
            narrative = (
                f"Personal baseline is calibrating (Day {calibration_days} of 14). "
                f"Alerts are suppressed while we model your typical rest and workload equilibrium."
            )

        # 8. Store Daily Inference
        iid = str(uuid.uuid4())
        self.db.insert_inference({
            "inference_id": iid,
            "user_id": user_id,
            "date_epoch": date_epoch,
            "composite_deviation_score": fusion_out.composite_stress_score,
            "shift_alert_triggered": effective_alert,
            "primary_contributing_modality": fusion_out.primary_contributor,
            "factor_attributions": fusion_out.factor_attributions,
            "explanation_narrative": narrative,
            "epistemic_uncertainty": fusion_out.epistemic_uncertainty,
        })

        return PipelineInferenceResult(
            user_id=user_id,
            date_epoch=date_epoch,
            is_calibrated=is_calibrated,
            calibration_day_count=calibration_days,
            composite_stress_score=fusion_out.composite_stress_score,
            is_alert_triggered=effective_alert,
            epistemic_uncertainty=fusion_out.epistemic_uncertainty,
            primary_contributor=fusion_out.primary_contributor,
            factor_attributions=fusion_out.factor_attributions,
            explanation_narrative=narrative,
            crisis_safety_triggered=crisis_triggered,
        )

