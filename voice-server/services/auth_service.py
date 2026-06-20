import os
import jwt
import requests
from fastapi import HTTPException, status

# ចំណាំ៖ បើ Laravel ប្រើ Secret Key សម្រាប់ផ្ដិតមេដៃ JWT យើងអាចយកមកដាក់ទីនេះបាន
# ឬវិធីងាយស្រួលបំផុតគឺឱ្យ FastAPI ហៅទៅ API របស់ Laravel ដើម្បីផ្ទៀងផ្ទាត់ (Token Introspection)
LARAVEL_AUTH_URL = os.getenv("LARAVEL_AUTH_URL", "http://localhost:8000/api/user") # កែតម្រូវតាម URL របស់ Laravel API អ្នក

def verify_jwt_token(token: str):
    """
    ផ្ទៀងផ្ទាត់ JWT Token ជាមួយ Laravel API
    """
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing token")
        
    try:
        # វិធីទី១៖ ហៅទៅកាន់ Laravel API ដើម្បី Check ថា Token ត្រឹមត្រូវ និងមិនទាន់ Expired
        headers = {"Authorization": f"Bearer {token}"}
        response = requests.get(LARAVEL_AUTH_URL, headers=headers, timeout=5)
        
        if response.status_code == 200:
            user_data = response.json()
            return {
                "id": user_data.get("id"),
                "name": user_data.get("name"),
                "email": user_data.get("email")
            }
        else:
            return None
            
    except requests.RequestException as e:
        print(f"[AUTH ERROR] Cannot connect to Laravel API: {e}")
        return None