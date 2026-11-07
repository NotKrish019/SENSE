"""
Comprehensive Test Suite for MindPulse Backend Architecture & End-to-End Pipeline.
Verifies SQLite storage, preprocessing, baseline calibration, late fusion,
crisis interception, and DPDP Act 2023 compliance.
"""

import json
import pytest
from datetime import datetime, timedelta

from backend.database import DatabaseManager
from backend.preprocessor import SignalPreprocessor
from backend.pipeline import MindPulsePipeline


@pytest.fixture
def mem_db():
    """Provides an isolated in-memory SQLite database for testing."""
    db = DatabaseManager(":memory:")
    yield db
    db.close()


@pytest.fixture
def pipeline(mem_db):
    """Provides an end-to-end pipeline backed by in-memory SQLite."""
    return MindPulsePipeline(mem_db)


class TestDatabaseManager:
    """Verifies SQLite relational schema creation, CRUD, and data rights."""

    def test_tables_created_successfully(self, mem_db):
        cursor = mem_db.conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [r[0] for r in cursor.fetchall()]

        assert "check_ins" in tables
        assert "sleep_records" in tables
        assert "workload_records" in tables
        assert "journal_entries" in tables
        assert "user_baselines" in tables
        assert "daily_inferences" in tables
        assert "consent_settings" in tables

    def test_insert_and_query_check_in(self, mem_db):
        mem_db.insert_check_in({
            "check_in_id": "c1",
            "user_id": "u1",
            "timestamp_utc": "2026-11-06T08:30:00Z",
            "session_type": "MORNING",
            "perceived_stress": 3,
            "mood_valence": 4,
            "mood_arousal": 3,
            "motivation_level": 4,
            "completion_latency_sec": 14.2,
        })
        history = mem_db.get_rolling_history("u1", before_date="2026-11-07")
        assert len(history["stress"]) == 1
        assert history["stress"][0] == 3.0

    def test_causal_rolling_history_strictly_excludes_future(self, mem_db):
        # Insert day 1, 2, and 3
        for day in [1, 2, 3]:
            mem_db.insert_check_in({
                "check_in_id": f"c_{day}",
                "user_id": "u1",
                "timestamp_utc": f"2026-11-0{day}T20:00:00Z",
                "session_type": "EVENING",
                "perceived_stress": day,
                "mood_valence": 3,
                "mood_arousal": 3,
                "completion_latency_sec": 12.0,
            })

        # Query history before 2026-11-03: must strictly return days 1 and 2
        history = mem_db.get_rolling_history("u1", before_date="2026-11-03")
        assert len(history["stress"]) == 2
        assert history["stress"] == [1.0, 2.0]

    def test_export_and_purge_user_data_dpdp(self, mem_db):
        mem_db.insert_check_in({
            "check_in_id": "c_exp",
            "user_id": "u_test",
            "timestamp_utc": "2026-11-06T12:00:00Z",
            "session_type": "ADHOC",
            "perceived_stress": 4,
            "mood_valence": 2,
            "mood_arousal": 2,
            "completion_latency_sec": 10.0,
        })

        # Test Export
        export_str = mem_db.export_user_data_json("u_test")
        dump = json.loads(export_str)
        assert dump["user_id"] == "u_test"
        assert len(dump["check_ins"]) == 1

        # Test Purge
        mem_db.purge_user_data("u_test")
        history_post_purge = mem_db.get_rolling_history("u_test", before_date="2026-12-01")
        assert len(history_post_purge["stress"]) == 0


class TestSignalPreprocessor:
    """Verifies feature extraction, sentiment analysis, and safety regex."""

    def test_crisis_keyword_interceptor(self):
        assert SignalPreprocessor.check_crisis_markers("I really want to kill myself") is True
        assert SignalPreprocessor.check_crisis_markers("I feel like I want to die") is True
        assert SignalPreprocessor.check_crisis_markers("I had a stressful deadline today") is False
        assert SignalPreprocessor.check_crisis_markers("") is False

    def test_journal_affective_parsing(self):
        res_pos = SignalPreprocessor.process_journal_text("Today was a great productive and calm day. I felt energized.")
        assert res_pos.sentiment_polarity > 0.5
        assert res_pos.first_person_pronoun_ratio > 0.0

        res_neg = SignalPreprocessor.process_journal_text("I feel completely overwhelmed, exhausted and drained by work.")
        assert res_neg.sentiment_polarity < -0.5
        assert res_neg.contains_crisis_markers is False

    def test_latency_quality_discount(self):
        # Extremely fast tapping (< 2.0s) should have discounted quality
        assert SignalPreprocessor.assess_checkin_quality(1.2) == 0.40
        assert SignalPreprocessor.assess_checkin_quality(15.0) == 1.00


class TestMindPulsePipeline:
    """Verifies end-to-end integration across multiple simulated longitudinal days."""

    def test_calibration_phase_progression(self, pipeline):
        # Days 1 to 5: Must be uncalibrated, with alerts suppressed
        for d in range(1, 6):
            date_str = f"2026-10-{d:02d}"
            res = pipeline.process_daily_intake(
                user_id="user_prog",
                date_epoch=date_str,
                check_in={"perceived_stress": 3, "completion_latency_sec": 12.0},
                sleep={"total_sleep_minutes": 450},
                workload={"mental_demand_rating": 3},
            )
            assert not res.is_calibrated
            assert res.calibration_day_count == d
            assert not res.is_alert_triggered
            assert "calibrating" in res.explanation_narrative.lower()

    def test_post_calibration_shift_detection(self, pipeline):
        user = "user_calib"
        # Seed 14 days of calm baseline data (sleep=8.0h, stress=2, workload=2)
        for d in range(1, 15):
            date_str = (datetime(2026, 9, 1) + timedelta(days=d)).strftime("%Y-%m-%d")
            pipeline.process_daily_intake(
                user_id=user,
                date_epoch=date_str,
                check_in={"perceived_stress": 2, "completion_latency_sec": 10.0},
                sleep={"total_sleep_minutes": 8 * 60},
                workload={"mental_demand_rating": 2},
            )

        # Day 15: Baseline is calibrated!
        res_calib = pipeline.process_daily_intake(
            user_id=user,
            date_epoch="2026-09-16",
            check_in={"perceived_stress": 2, "completion_latency_sec": 10.0},
            sleep={"total_sleep_minutes": 8 * 60},
            workload={"mental_demand_rating": 2},
        )
        assert res_calib.is_calibrated
        assert res_calib.calibration_day_count >= 14
        assert not res_calib.is_alert_triggered

        # Day 16: Severe acute stress (4h sleep, stress 5, workload 5)
        res_stress = pipeline.process_daily_intake(
            user_id=user,
            date_epoch="2026-09-17",
            check_in={"perceived_stress": 5, "completion_latency_sec": 15.0},
            sleep={"total_sleep_minutes": 4 * 60},
            workload={"mental_demand_rating": 5, "impending_deadlines_count": 3},
        )
        assert res_stress.is_calibrated
        assert res_stress.composite_stress_score > 0.65
        assert res_stress.primary_contributor != "none"

    def test_missing_modality_handling_in_pipeline(self, pipeline):
        # User only submits check-in, skipping sleep and workload
        res = pipeline.process_daily_intake(
            user_id="user_sparse",
            date_epoch="2026-11-06",
            check_in={"perceived_stress": 3, "completion_latency_sec": 14.0},
            sleep=None,
            workload=None,
            journal_text=None,
        )
        # Should not crash, epistemic uncertainty reflects missing modalities
        assert res.epistemic_uncertainty > 0.60
        assert res.composite_stress_score > 0.0

    def test_crisis_safety_interceptor_trigger_in_pipeline(self, pipeline):
        res = pipeline.process_daily_intake(
            user_id="user_crisis",
            date_epoch="2026-11-06",
            check_in={"perceived_stress": 5},
            journal_text="I don't see any hope and I want to kill myself tonight.",
        )
        assert res.crisis_safety_triggered is True

