import httpx
from PIL import Image
import io
import base64
import os
from groq import Groq

# Get API key from environment
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

client = Groq(api_key=GROQ_API_KEY)

def encode_image_to_base64(image_bytes: bytes) -> str:
    return base64.b64encode(image_bytes).decode("utf-8")

async def analyze_damage_photo(image_url: str):
    async with httpx.AsyncClient() as http:
        response = await http.get(image_url, follow_redirects=True)
        image_data = response.content

    try:
        image = Image.open(io.BytesIO(image_data)).convert("RGB")
        buf = io.BytesIO()
        image.save(buf, format="JPEG")
        image_bytes = buf.getvalue()
        base64_image = encode_image_to_base64(image_bytes)
    except Exception as e:
        print(f"Image load error: {e}")
        return {
            "DAMAGE_TYPE": "crack",
            "SEVERITY": "moderate",
            "MATERIAL": "stone",
            "AFFECTED_AREA": "medium",
            "DESCRIPTION": "Unable to analyze image clearly"
        }

    prompt = """
    Analyze this damaged statue photo and return ONLY this exact format:
    
    DAMAGE_TYPE: (crack/erosion/breakage/vandalism/rust/clay_damage)
    SEVERITY: (minor/moderate/severe)
    MATERIAL: (stone/metal/clay/concrete)
    AFFECTED_AREA: (small/medium/large)
    DESCRIPTION: (one line description of the damage)
    """

    response = client.chat.completions.create(
        model="meta-llama/llama-4-scout-17b-16e-instruct",
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{base64_image}"
                        }
                    },
                    {
                        "type": "text",
                        "text": prompt
                    }
                ]
            }
        ],
        max_tokens=200
    )
    return parse_vision_response(response.choices[0].message.content)

async def analyze_damage_photo_bytes(image_bytes: bytes):
    try:
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        buf = io.BytesIO()
        image.save(buf, format="JPEG")
        image_bytes = buf.getvalue()
        base64_image = encode_image_to_base64(image_bytes)
    except Exception as e:
        print(f"Image load error: {e}")
        return {
            "DAMAGE_TYPE": "crack",
            "SEVERITY": "moderate",
            "MATERIAL": "stone",
            "AFFECTED_AREA": "medium",
            "DESCRIPTION": "Unable to analyze image clearly"
        }

    prompt = """
    Analyze this damaged statue photo and return ONLY this exact format:
    
    DAMAGE_TYPE: (crack/erosion/breakage/vandalism/rust/clay_damage)
    SEVERITY: (minor/moderate/severe)
    MATERIAL: (stone/metal/clay/concrete)
    AFFECTED_AREA: (small/medium/large)
    DESCRIPTION: (one line description of the damage)
    """

    response = client.chat.completions.create(
        model="meta-llama/llama-4-scout-17b-16e-instruct",
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{base64_image}"
                        }
                    },
                    {
                        "type": "text",
                        "text": prompt
                    }
                ]
            }
        ],
        max_tokens=200
    )
    return parse_vision_response(response.choices[0].message.content)

def parse_vision_response(text: str):
    result = {}
    for line in text.strip().split("\n"):
        if ":" in line:
            key, value = line.split(":", 1)
            result[key.strip()] = value.strip()
    return result

async def standardize_work_description(description: str, vision_result: dict):
    prompt = f"""
    Based on this statue damage information:
    - Photo Analysis: {vision_result}
    - User Work Description: {description}
    
    Return ONLY a clean comma separated list of work types needed from these options:
    roofing_concrete, roofing_shed, flooring_tiles, flooring_cement, fencing,
    chemical_washing, lighting_installation, painting_general, lingam_painting,
    avudai_painting, nandhi_painting, shed_painting, floor_painting,
    compound_wall, compound_wall_painting, lingam_renovation,
    temple_bell_installation, carpentry_shelf, carpentry_door,
    drainage_construction, platform_construction, crack_filling,
    waterproofing, statue_base_repair, general_repair
    
    Example output: crack_filling, chemical_washing, lighting_installation
    
    Only return work types that are clearly needed based on the description and photo analysis.
    """
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        max_tokens=100
    )
    works = [w.strip() for w in response.choices[0].message.content.strip().split(",")]
    return works

async def generate_work_summary(vision_result: dict, work_types: list, budget_breakdown: dict, district: str):
    prompt = f"""
    Generate a professional preservation work summary report for an admin to approve.
    
    Details:
    - District: {district}
    - Damage Type: {vision_result.get('DAMAGE_TYPE')}
    - Severity: {vision_result.get('SEVERITY')}
    - Material: {vision_result.get('MATERIAL')}
    - Works Required: {', '.join(work_types)}
    - Budget Breakdown: {budget_breakdown}
    
    Write a clear 3-4 line professional summary of:
    1. What damage was found
    2. What work needs to be done
    3. Why this budget is justified
    """
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        max_tokens=300
    )
    return response.choices[0].message.content.strip()