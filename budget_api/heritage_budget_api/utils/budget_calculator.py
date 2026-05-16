import json
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load_district_rates():
    with open(os.path.join(BASE_DIR, "knowledge_base", "district_rates.json")) as f:
        return json.load(f)

def load_work_types():
    with open(os.path.join(BASE_DIR, "knowledge_base", "work_types.json")) as f:
        return json.load(f)

# Maps work type name to its rate key in district_rates.json
WORK_RATE_MAP = {
    "roofing_concrete":        ("roofing_concrete_per_sqft",          "per_sqft"),
    "roofing_shed":            ("roofing_shed_per_sqft",               "per_sqft"),
    "flooring_tiles":          ("flooring_tiles_per_sqft",             "per_sqft"),
    "flooring_cement":         ("flooring_cement_per_sqft",            "per_sqft"),
    "fencing":                 ("fencing_per_meter",                   "per_meter"),
    "chemical_washing":        ("chemical_washing_per_sqft",           "per_sqft"),
    "lighting_installation":   ("lighting_installation_per_unit",      "per_unit"),
    "painting_general":        ("painting_general_per_sqft",           "per_sqft"),
    "lingam_painting":         ("lingam_painting_per_unit",            "per_unit"),
    "avudai_painting":         ("avudai_painting_per_unit",            "per_unit"),
    "nandhi_painting":         ("nandhi_painting_per_unit",            "per_unit"),
    "shed_painting":           ("shed_painting_per_sqft",              "per_sqft"),
    "floor_painting":          ("floor_painting_per_sqft",             "per_sqft"),
    "compound_wall":           ("compound_wall_per_meter",             "per_meter"),
    "compound_wall_painting":  ("compound_wall_painting_per_sqft",     "per_sqft"),
    "lingam_renovation":       ("lingam_renovation_per_unit",          "per_unit"),
    "temple_bell_installation":("temple_bell_installation_per_unit",   "per_unit"),
    "carpentry_shelf":         ("carpentry_shelf_per_unit",            "per_unit"),
    "carpentry_door":          ("carpentry_door_per_unit",             "per_unit"),
    "drainage_construction":   ("drainage_construction_per_meter",     "per_meter"),
    "platform_construction":   ("platform_construction_per_sqft",      "per_sqft"),
    "crack_filling":           ("crack_filling_per_sqft",              "per_sqft"),
    "waterproofing":           ("waterproofing_per_sqft",              "per_sqft"),
    "statue_base_repair":      ("statue_base_repair_per_sqft",         "per_sqft"),
    "general_repair":          ("general_repair_per_sqft",             "per_sqft"),
}

def calculate_budget(district: str, work_types: list, sqft: float):
    district_rates = load_district_rates()
    work_details = load_work_types()

    # Fallback to Thanjavur if district not found
    if district not in district_rates:
        print(f"⚠️ District '{district}' not found, using Thanjavur rates")
        district = "Thanjavur"

    rates = district_rates[district]
    breakdown = {}
    total = 0
    total_labor_days = 0

    for work in work_types:
        work = work.strip().lower()

        if work not in WORK_RATE_MAP:
            print(f"⚠️ Unknown work type '{work}', using general_repair")
            work = "general_repair"

        rate_key, unit_type = WORK_RATE_MAP[work]

        if rate_key not in rates:
            continue

        rate = rates[rate_key]
        labor_days = work_details.get(work, {}).get("labor_days", 2)
        display_name = work.replace("_", " ").title()

        # Calculate cost based on unit type
        if unit_type == "per_sqft":
            cost = sqft * rate
            calculation = f"{sqft} sqft × ₹{rate}"
        elif unit_type == "per_meter":
            cost = sqft * rate
            calculation = f"{sqft} meters × ₹{rate}"
        elif unit_type == "per_unit":
            cost = rate
            calculation = f"1 unit × ₹{rate}"
        else:
            cost = sqft * rate
            calculation = f"{sqft} × ₹{rate}"

        breakdown[display_name] = {
            "calculation": calculation,
            "cost": round(cost)
        }
        total += cost
        total_labor_days += labor_days

    # Add labor cost
    labor_cost = total_labor_days * rates["labor_per_day"]
    breakdown["Labor"] = {
        "calculation": f"{total_labor_days} days × ₹{rates['labor_per_day']}",
        "cost": round(labor_cost)
    }
    total += labor_cost

    # Add transport cost
    breakdown["Transport"] = {
        "calculation": "Flat rate for district",
        "cost": rates["transport_flat"]
    }
    total += rates["transport_flat"]

    return {
        "district": district,
        "sqft": sqft,
        "breakdown": breakdown,
        "total_sanction": round(total)
    }