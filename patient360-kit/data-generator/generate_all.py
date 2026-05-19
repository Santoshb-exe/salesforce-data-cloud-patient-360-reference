"""
Patient 360 Reference Implementation — Synthetic Data Generator

Generates fake multi-brand healthcare data with intentional edge cases for
testing Data Cloud ingestion, identity resolution, segmentation, and AI grounding.

USAGE:
    pip install faker pyyaml
    python generate_all.py

OUTPUT: CSVs in ../data/
    - medfirst_patients.csv, careplus_patients.csv, healthbridge_patients.csv
    - providers.csv
    - encounters.csv
    - engagement_events.csv
    - clinical_reference.csv
    - provider_performance.csv
    - consent_preferences.csv

EDGE CASES INTENTIONALLY INJECTED:
    - source_patient_id collisions across brands (different people, same ID)
    - cross-brand duplicates (same person, different brands)
    - pediatric patients with guardian contact info
    - twins (same DOB, same address)
    - family-shared emails
    - changed phones / last names across brands
    - name typos for fuzzy matching tests
"""

import csv
import random
import yaml
import os
from datetime import datetime, timedelta
from faker import Faker
from pathlib import Path


def load_config():
    config_path = Path(__file__).parent / "config.yaml"
    with open(config_path) as f:
        return yaml.safe_load(f)


def setup(config):
    random.seed(config["seed"])
    fake = Faker("en_US")
    Faker.seed(config["seed"])
    out_dir = Path(__file__).parent / config["output_dir"]
    out_dir.mkdir(parents=True, exist_ok=True)
    return fake, out_dir


# ---------------- PATIENTS ----------------

def make_patient(fake, source_brand, source_patient_id, force_age=None,
                  override=None):
    """Generate a single patient record. override dict can force specific fields."""
    first = fake.first_name()
    last = fake.last_name()

    # Age handling for pediatric/adult split
    if force_age is not None:
        dob = datetime.now() - timedelta(days=force_age * 365 + random.randint(0, 364))
    else:
        # 85% adults, 15% pediatric — overridden by force_age
        age = random.randint(18, 85) if random.random() > 0.15 else random.randint(0, 17)
        dob = datetime.now() - timedelta(days=age * 365 + random.randint(0, 364))

    is_pediatric = (datetime.now() - dob).days < 18 * 365

    rec = {
        "source_brand": source_brand,
        "source_patient_id": str(source_patient_id),
        "source_system": f"{source_brand}_EHR",
        "first_name": first,
        "last_name": last,
        "dob": dob.strftime("%Y-%m-%d"),
        "gender": random.choice(["M", "F", "O"]),
        "ssn_last4": f"{random.randint(0, 9999):04d}",  # FAKE
        "email": fake.email(),
        "phone": fake.phone_number()[:20],
        "address_line1": fake.street_address(),
        "city": fake.city(),
        "state": fake.state_abbr(),
        "postal_code": fake.zipcode(),
        "guardian_first_name": "",
        "guardian_last_name": "",
        "guardian_email": "",
        "guardian_phone": "",
        "created_at": fake.date_time_between(start_date="-3y").isoformat(),
        "updated_at": datetime.now().isoformat(),
    }

    if is_pediatric:
        rec["guardian_first_name"] = fake.first_name()
        rec["guardian_last_name"] = last  # same as patient
        rec["guardian_email"] = fake.email()
        rec["guardian_phone"] = fake.phone_number()[:20]

    if override:
        rec.update(override)
    return rec


def generate_patients(fake, config, out_dir):
    """Generate brand-specific patient CSVs with deliberate edge cases."""
    all_patients = {}  # brand -> list

    # Pool of "real people" we'll plant as duplicates across brands
    duplicate_seeds = []
    for _ in range(config["cross_brand_duplicates"]):
        first = fake.first_name()
        last = fake.last_name()
        age = random.randint(20, 75)
        dob = datetime.now() - timedelta(days=age * 365 + random.randint(0, 364))
        duplicate_seeds.append({
            "first_name": first,
            "last_name": last,
            "dob": dob.strftime("%Y-%m-%d"),
            "ssn_last4": f"{random.randint(0, 9999):04d}",
            "email": fake.email(),
            "phone": fake.phone_number()[:20],
            "address_line1": fake.street_address(),
            "city": fake.city(),
            "state": fake.state_abbr(),
            "postal_code": fake.zipcode(),
        })

    # Generate per-brand patients
    next_pid = 10000
    for brand_cfg in config["brands"]:
        brand = brand_cfg["name"]
        patients = []
        for _ in range(brand_cfg["patient_count"]):
            patients.append(make_patient(fake, brand, next_pid))
            next_pid += 1
        all_patients[brand] = patients

    # INJECT ID COLLISIONS: same source_patient_id used in different brands
    # for DIFFERENT people. Forces global key strategy.
    collision_ids = random.sample(range(20000, 30000), config["collision_count"])
    for pid in collision_ids:
        for brand_cfg in config["brands"]:
            brand = brand_cfg["name"]
            # Different fake people sharing the same source ID across brands
            all_patients[brand].append(make_patient(fake, brand, pid))

    # INJECT CROSS-BRAND DUPLICATES: same person, different brand patient IDs
    for seed in duplicate_seeds:
        # Pick 2 or 3 brands this person appears in
        brands_for_this_person = random.sample(
            [b["name"] for b in config["brands"]], random.choice([2, 3]))
        for brand in brands_for_this_person:
            override = dict(seed)
            # Slight perturbations to test fuzzy matching
            r = random.random()
            if r < 0.3:
                # Typo in last name
                ln = override["last_name"]
                if len(ln) > 2:
                    idx = random.randint(0, len(ln) - 1)
                    override["last_name"] = ln[:idx] + ln[idx] + ln[idx:]
            elif r < 0.5:
                # Changed email at this brand
                override["email"] = fake.email()
            elif r < 0.7:
                # Changed phone
                override["phone"] = fake.phone_number()[:20]
            all_patients[brand].append(make_patient(
                fake, brand, next_pid, override=override))
            next_pid += 1

    # INJECT TWINS: same address, same dob, different first names
    for _ in range(config["edge_cases"]["twins_same_address"]):
        brand = random.choice([b["name"] for b in config["brands"]])
        last = fake.last_name()
        dob = datetime.now() - timedelta(days=random.randint(2000, 10000))
        addr = {
            "address_line1": fake.street_address(),
            "city": fake.city(),
            "state": fake.state_abbr(),
            "postal_code": fake.zipcode(),
        }
        for _ in range(2):  # 2 twins
            override = {
                "first_name": fake.first_name(),
                "last_name": last,
                "dob": dob.strftime("%Y-%m-%d"),
                **addr,
            }
            all_patients[brand].append(make_patient(
                fake, brand, next_pid, override=override))
            next_pid += 1

    # INJECT FAMILY SHARED EMAIL: multiple family members on same email
    for _ in range(config["edge_cases"]["family_shared_email"]):
        brand = random.choice([b["name"] for b in config["brands"]])
        shared_email = fake.email()
        last = fake.last_name()
        family_size = random.choice([2, 3, 4])
        for _ in range(family_size):
            override = {
                "last_name": last,
                "email": shared_email,
            }
            all_patients[brand].append(make_patient(
                fake, brand, next_pid, override=override))
            next_pid += 1

    # Write per-brand CSVs
    for brand, records in all_patients.items():
        random.shuffle(records)
        fname = out_dir / f"{brand.lower()}_patients.csv"
        with open(fname, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=records[0].keys())
            writer.writeheader()
            writer.writerows(records)
        print(f"  wrote {fname.name}: {len(records)} patients")

    return all_patients


# ---------------- PROVIDERS ----------------

def generate_providers(fake, config, out_dir):
    specialties = [
        "Internal Medicine", "Family Practice", "Pediatrics", "Cardiology",
        "Endocrinology", "Pulmonology", "Oncology", "Psychiatry",
        "Obstetrics & Gynecology", "Dermatology"
    ]
    providers = []
    pid = 1000
    for brand_cfg in config["brands"]:
        brand = brand_cfg["name"]
        for _ in range(config["providers_per_brand"]):
            providers.append({
                "provider_id": f"PRV-{pid}",
                "provider_npi_fake": f"{random.randint(1000000000, 9999999999)}",
                "provider_name": f"Dr. {fake.first_name()} {fake.last_name()}",
                "specialty": random.choice(specialties),
                "brand": brand,
                "location": f"{fake.city()}, {fake.state_abbr()}",
                "panel_size": random.randint(500, 3000),
                "capacity_per_week": random.randint(20, 80),
                "active_flag": random.choice([True, True, True, False]),
            })
            pid += 1

    fname = out_dir / "providers.csv"
    with open(fname, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=providers[0].keys())
        writer.writeheader()
        writer.writerows(providers)
    print(f"  wrote {fname.name}: {len(providers)} providers")
    return providers


# ---------------- ENCOUNTERS ----------------

ICD10_SAMPLES = [
    ("E11.9", "Type 2 diabetes mellitus without complications"),
    ("I10", "Essential hypertension"),
    ("J45.909", "Unspecified asthma"),
    ("F41.1", "Generalized anxiety disorder"),
    ("M54.5", "Low back pain"),
    ("R51", "Headache"),
    ("Z00.00", "Encounter for general adult medical exam"),
    ("Z23", "Encounter for immunization"),
    ("J06.9", "Acute upper respiratory infection"),
    ("E78.5", "Hyperlipidemia, unspecified"),
]
CPT_SAMPLES = [
    ("99213", "Office visit, established patient, 20-29 min"),
    ("99214", "Office visit, established patient, 30-39 min"),
    ("99392", "Preventive medicine reevaluation age 1-4"),
    ("99395", "Preventive medicine reevaluation age 18-39"),
    ("99396", "Preventive medicine reevaluation age 40-64"),
    ("90471", "Immunization administration"),
    ("80053", "Comprehensive metabolic panel"),
    ("83036", "Hemoglobin A1c"),
]


def generate_encounters(fake, all_patients, providers, out_dir):
    encounters = []
    eid = 100000
    for brand, patients in all_patients.items():
        brand_providers = [p for p in providers if p["brand"] == brand]
        for p in patients:
            # 0-5 encounters per patient over last 2 years
            for _ in range(random.randint(0, 5)):
                icd_code, icd_desc = random.choice(ICD10_SAMPLES)
                cpt_code, cpt_desc = random.choice(CPT_SAMPLES)
                enc_date = fake.date_between(start_date="-2y", end_date="today")
                encounters.append({
                    "encounter_id": f"ENC-{eid}",
                    "source_brand": brand,
                    "source_patient_id": p["source_patient_id"],
                    "provider_id": random.choice(brand_providers)["provider_id"],
                    "encounter_date": enc_date.isoformat(),
                    "encounter_type": random.choice(
                        ["Office Visit", "Telehealth", "Annual Wellness", "Follow-up"]),
                    "visit_status": random.choice(
                        ["Completed", "Completed", "Completed", "No-Show", "Cancelled"]),
                    "diagnosis_code": icd_code,
                    "procedure_code": cpt_code,
                    "follow_up_required": random.choice([True, False]),
                    "created_at": enc_date.isoformat(),
                    "updated_at": enc_date.isoformat(),
                })
                eid += 1

    fname = out_dir / "encounters.csv"
    with open(fname, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=encounters[0].keys())
        writer.writeheader()
        writer.writerows(encounters)
    print(f"  wrote {fname.name}: {len(encounters)} encounters")
    return encounters


# ---------------- ENGAGEMENT EVENTS ----------------

def generate_engagement_events(fake, all_patients, config, out_dir):
    events = []
    event_id = 1000000
    channels = ["Email", "SMS", "Push", "Web"]
    event_types = ["Sent", "Opened", "Clicked", "Bounced", "Converted", "Unsubscribed"]
    campaigns = [
        "Q1 Annual Wellness Drive",
        "Diabetes Management Outreach",
        "Pediatric Vaccination Reminder",
        "Cardiac Care Check-in",
        "Flu Shot Campaign 2026",
        "Provider Re-engagement",
    ]

    for brand, patients in all_patients.items():
        for p in patients:
            n_events = random.randint(0, config["engagement_events_per_patient_avg"] * 2)
            for _ in range(n_events):
                opened = random.random() > 0.4
                clicked = opened and random.random() > 0.6
                converted = clicked and random.random() > 0.7
                events.append({
                    "event_id": f"EVT-{event_id}",
                    "source_brand": brand,
                    "source_patient_id": p["source_patient_id"],
                    "event_type": random.choice(event_types),
                    "event_channel": random.choice(channels),
                    "event_timestamp": fake.date_time_between(start_date="-180d").isoformat(),
                    "campaign_name": random.choice(campaigns),
                    "clicked_flag": clicked,
                    "opened_flag": opened,
                    "converted_flag": converted,
                })
                event_id += 1

    fname = out_dir / "engagement_events.csv"
    with open(fname, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=events[0].keys())
        writer.writeheader()
        writer.writerows(events)
    print(f"  wrote {fname.name}: {len(events)} engagement events")


# ---------------- CLINICAL REFERENCE ----------------

def generate_clinical_reference(out_dir):
    """The marketer-friendly abstraction layer over ICD-10/CPT codes."""
    rows = [
        # ICD-10 chronic
        ("ICD10", "E11.9", "Type 2 diabetes mellitus without complications",
         "Diabetes", "Chronic Care", "High", "Quarterly"),
        ("ICD10", "E11.65", "Type 2 diabetes with hyperglycemia",
         "Diabetes", "Chronic Care", "High", "Quarterly"),
        ("ICD10", "I10", "Essential hypertension",
         "Cardiac", "Chronic Care", "Medium", "Quarterly"),
        ("ICD10", "I25.10", "Atherosclerotic heart disease",
         "Cardiac", "Chronic Care", "High", "Quarterly"),
        ("ICD10", "J45.909", "Unspecified asthma",
         "Chronic Respiratory", "Chronic Care", "Medium", "Quarterly"),
        ("ICD10", "J44.9", "COPD unspecified",
         "Chronic Respiratory", "Chronic Care", "High", "Quarterly"),
        ("ICD10", "F41.1", "Generalized anxiety disorder",
         "Mental Health", "Behavioral Health", "Medium", "Monthly"),
        ("ICD10", "F32.9", "Major depressive disorder",
         "Mental Health", "Behavioral Health", "High", "Monthly"),
        ("ICD10", "E78.5", "Hyperlipidemia",
         "Cardiac", "Chronic Care", "Medium", "Semi-Annual"),
        # ICD-10 wellness
        ("ICD10", "Z00.00", "Adult general medical exam",
         "Annual Wellness", "Preventive Care", "Low", "Annual"),
        ("ICD10", "Z00.121", "Child routine exam abnormal",
         "Pediatric Wellness", "Preventive Care", "Low", "Annual"),
        ("ICD10", "Z00.129", "Child routine exam normal",
         "Pediatric Wellness", "Preventive Care", "Low", "Annual"),
        ("ICD10", "Z23", "Immunization",
         "Pediatric Wellness", "Preventive Care", "Low", "Annual"),
        # CPT
        ("CPT", "99213", "Office visit established patient",
         "General Care", "Care Coordination", "Low", "As Needed"),
        ("CPT", "99392", "Pediatric preventive reevaluation 1-4",
         "Pediatric Wellness", "Preventive Care", "Low", "Annual"),
        ("CPT", "99395", "Adult preventive reevaluation 18-39",
         "Annual Wellness", "Preventive Care", "Low", "Annual"),
        ("CPT", "99396", "Adult preventive reevaluation 40-64",
         "Annual Wellness", "Preventive Care", "Low", "Annual"),
        ("CPT", "83036", "Hemoglobin A1c",
         "Diabetes", "Chronic Care", "High", "Quarterly"),
        ("CPT", "80053", "Comprehensive metabolic panel",
         "Chronic Care", "Care Coordination", "Medium", "Semi-Annual"),
        ("CPT", "G0438", "Annual wellness visit, initial",
         "Annual Wellness", "Preventive Care", "Low", "Annual"),
        ("CPT", "G0439", "Annual wellness visit, subsequent",
         "Annual Wellness", "Preventive Care", "Low", "Annual"),
    ]
    fields = ["code_type", "raw_code", "raw_description",
              "friendly_category", "marketing_category",
              "risk_tier", "recommended_outreach_frequency"]
    fname = out_dir / "clinical_reference.csv"
    with open(fname, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(fields)
        writer.writerows(rows)
    print(f"  wrote {fname.name}: {len(rows)} reference codes")


# ---------------- PROVIDER PERFORMANCE ----------------

def generate_provider_performance(providers, out_dir):
    rows = []
    months = [(datetime.now() - timedelta(days=30 * i)).strftime("%Y-%m")
              for i in range(6)]
    for p in providers:
        for month in months:
            rows.append({
                "provider_id": p["provider_id"],
                "measurement_month": month,
                "rvu_score": round(random.uniform(2.0, 5.5), 2),
                "capacity_utilization_pct": round(random.uniform(40, 100), 1),
                "open_appointment_slots": random.randint(0, 30),
                "patient_satisfaction_score": round(random.uniform(3.0, 5.0), 2),
                "no_show_rate": round(random.uniform(0.02, 0.20), 3),
            })
    fname = out_dir / "provider_performance.csv"
    with open(fname, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(f"  wrote {fname.name}: {len(rows)} performance records")


# ---------------- CONSENT ----------------

def generate_consent(all_patients, out_dir):
    rows = []
    for brand, patients in all_patients.items():
        for p in patients:
            rows.append({
                "source_brand": brand,
                "source_patient_id": p["source_patient_id"],
                "email_opt_in": random.choice([True, True, True, False]),
                "sms_opt_in": random.choice([True, True, False]),
                "phone_opt_in": random.choice([True, False]),
                "marketing_opt_in": random.choice([True, True, False]),
                "research_opt_in": random.choice([True, False, False]),
                "last_updated": datetime.now().isoformat(),
            })
    fname = out_dir / "consent_preferences.csv"
    with open(fname, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(f"  wrote {fname.name}: {len(rows)} consent records")


# ---------------- MAIN ----------------

def main():
    print("Patient 360 Reference Implementation — Synthetic Data Generator")
    print("=" * 64)
    config = load_config()
    fake, out_dir = setup(config)
    print(f"Output: {out_dir.resolve()}\n")

    print("[1/7] Generating patients...")
    all_patients = generate_patients(fake, config, out_dir)

    print("\n[2/7] Generating providers...")
    providers = generate_providers(fake, config, out_dir)

    print("\n[3/7] Generating encounters...")
    generate_encounters(fake, all_patients, providers, out_dir)

    print("\n[4/7] Generating engagement events...")
    generate_engagement_events(fake, all_patients, config, out_dir)

    print("\n[5/7] Generating clinical reference...")
    generate_clinical_reference(out_dir)

    print("\n[6/7] Generating provider performance...")
    generate_provider_performance(providers, out_dir)

    print("\n[7/7] Generating consent preferences...")
    generate_consent(all_patients, out_dir)

    print("\nDone. Inspect CSVs under:", out_dir.resolve())
    print("\nNote: All data is synthetic. No PHI. Safe for public GitHub.")


if __name__ == "__main__":
    main()
