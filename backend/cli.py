"""
MindPulse Interactive CLI & Pipeline Verification Tool.
Provides command-line execution for longitudinal simulation, daily logging,
crisis interceptor testing, and DPDP Act 2023 data export/erasure.
"""

import argparse
import json
import sys
from datetime import datetime, timedelta
import numpy as np

from backend.database import DatabaseManager
from backend.pipeline import MindPulsePipeline


def cmd_run_simulation(args: argparse.Namespace) -> None:
    """Runs a multi-day simulation populating SQLite and verifying baseline adaptation."""
    days = args.days
    user_id = args.user_id
    db_path = args.db_path

    print(f"\n=======================================================")
    print(f"  MindPulse System Simulation: {days} Days for '{user_id}'")
    print(f"  Database Target: {db_path}")
    print(f"=======================================================\n")

    db = DatabaseManager(db_path)
    pipeline = MindPulsePipeline(db)

    # Clean previous records for clean simulation run
    db.purge_user_data(user_id)

    rng = np.random.default_rng(42)
    start_date = datetime(2026, 10, 1)

    print(f"{'Day':<5} | {'Date':<10} | {'Stress':<6} | {'Sleep':<6} | {'Workload':<8} | {'Calibrated?':<11} | {'Comp Score':<10} | {'Alert?':<6} | Contributor")
    print("-" * 92)

    for d in range(1, days + 1):
        curr_date = (start_date + timedelta(days=d - 1)).strftime("%Y-%m-%d")

        # Baseline values
        stress = int(np.clip(np.round(rng.normal(2.5, 0.6)), 1, 5))
        sleep_mins = int(np.clip(np.round(rng.normal(7.5 * 60, 45)), 4 * 60, 10 * 60))
        mental_demand = int(np.clip(np.round(rng.normal(2.5, 0.7)), 1, 5))
        deadlines = 0

        # Scenario 1: Acute 1-day spike on Day 18
        if d == 18:
            stress = 5
            sleep_mins = 4 * 60
            mental_demand = 5
            deadlines = 3

        # Scenario 2: Sustained allostatic drift on Days 23-27
        if 23 <= d <= 27:
            stress = 4
            sleep_mins = 5 * 60 + 15
            mental_demand = 4
            deadlines = 2

        res = pipeline.process_daily_intake(
            user_id=user_id,
            date_epoch=curr_date,
            check_in={
                "perceived_stress": stress,
                "mood_valence": max(1, 6 - stress),
                "mood_arousal": 3,
                "completion_latency_sec": 12.5,
            },
            sleep={
                "total_sleep_minutes": sleep_mins,
                "sleep_quality_rating": 3 if sleep_mins > 6 * 60 else 2,
            },
            workload={
                "mental_demand_rating": mental_demand,
                "effort_rating": mental_demand,
                "impending_deadlines_count": deadlines,
            },
            journal_text="Productive day overall." if stress <= 3 else "Feeling quite drained and exhausted today.",
        )

        calib_str = "YES" if res.is_calibrated else f"NO ({res.calibration_day_count}/14)"
        alert_str = "ALERT!" if res.is_alert_triggered else "No"
        sleep_hrs_str = f"{sleep_mins / 60.0:.1f}h"

        print(f"{d:<5} | {curr_date:<10} | {stress:<6} | {sleep_hrs_str:<6} | {mental_demand:<8} | {calib_str:<11} | {res.composite_stress_score:<10.3f} | {alert_str:<6} | {res.primary_contributor}")

    print("\nSimulation complete. Querying latest narrative from database...")
    latest = db.get_latest_inference(user_id)
    if latest:
        print(f"\n[Latest Narrative for {latest['date_epoch']}]:")
        print(f"\"{latest['explanation_narrative']}\"")
        print(f"Factor Attributions: {latest['factor_attributions']}")
    print("\nTo inspect full JSON export, run: python -m backend.cli export-data")


def cmd_test_crisis(args: argparse.Namespace) -> None:
    """Tests the regex crisis keyword interceptor."""
    db = DatabaseManager(":memory:")
    pipeline = MindPulsePipeline(db)

    test_phrases = [
        ("I had a very busy and stressful day at the office.", False),
        ("My sleep was terrible and my workload is high.", False),
        ("I feel like I want to die, nothing matters anymore.", True),
        ("I don't see any hope and I want to kill myself.", True),
        ("I'm feeling calm and refreshed after taking a walk.", False),
    ]

    print("\n=== Running Crisis Safety Interceptor Verification ===")
    all_passed = True
    for text, expected in test_phrases:
        result = pipeline.process_daily_intake(
            user_id="test_safety_user",
            date_epoch="2026-11-06",
            journal_text=text,
        )
        passed = (result.crisis_safety_triggered == expected)
        status = "[PASS]" if passed else "[FAIL]"
        if not passed:
            all_passed = False
        print(f"{status} Text: \"{text[:45]}...\" -> Intercepted: {result.crisis_safety_triggered} (Expected: {expected})")

    print("\nCrisis Interceptor Status:", "100% VERIFIED" if all_passed else "FAILURES DETECTED")


def cmd_export_data(args: argparse.Namespace) -> None:
    """Exports user data as JSON fulfilling DPDP Act 2023 portability."""
    db = DatabaseManager(args.db_path)
    data = db.export_user_data_json(args.user_id)
    print(data)


def cmd_purge_data(args: argparse.Namespace) -> None:
    """Permanently wipes all user data fulfilling DPDP Act 2023 right to erasure."""
    db = DatabaseManager(args.db_path)
    db.purge_user_data(args.user_id)
    print(f"Successfully purged all personal records for '{args.user_id}' from {args.db_path}.")


def main() -> None:
    parser = argparse.ArgumentParser(description="MindPulse Backend System CLI")
    subparsers = parser.add_subparsers(dest="command")

    # run-simulation
    p_sim = subparsers.add_parser("run-simulation", help="Run multi-day simulation")
    p_sim.add_argument("--days", type=int, default=30, help="Number of days to simulate (default: 30)")
    p_sim.add_argument("--user-id", type=str, default="user_001", help="Participant ID")
    p_sim.add_argument("--db-path", type=str, default="data/mindpulse_local.db", help="SQLite database path")
    p_sim.set_defaults(func=cmd_run_simulation)

    # test-crisis
    p_crisis = subparsers.add_parser("test-crisis", help="Verify crisis keyword interceptor")
    p_crisis.set_defaults(func=cmd_test_crisis)

    # export-data
    p_export = subparsers.add_parser("export-data", help="Export user records as JSON")
    p_export.add_argument("--user-id", type=str, default="user_001")
    p_export.add_argument("--db-path", type=str, default="data/mindpulse_local.db")
    p_export.set_defaults(func=cmd_export_data)

    # purge-data
    p_purge = subparsers.add_parser("purge-data", help="Purge all user records under DPDP Act 2023")
    p_purge.add_argument("--user-id", type=str, default="user_001")
    p_purge.add_argument("--db-path", type=str, default="data/mindpulse_local.db")
    p_purge.set_defaults(func=cmd_purge_data)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    args.func(args)


if __name__ == "__main__":
    main()

