import base64
import hashlib
import hmac
import json
import os
import secrets
import time
from urllib.parse import urlencode, urlparse

import httpx
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse, RedirectResponse

app = FastAPI(docs_url=None, redoc_url=None)

PROVIDERS = {"youtube", "instagram", "tiktok"}
STATE_TTL_SECONDS = 300


def setting(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise HTTPException(500, f"Server setting {name} is missing.")
    return value


def b64(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode().rstrip("=")


def state_value(provider: str, redirect_uri: str) -> str:
    verifier = secrets.token_urlsafe(48)
    payload = {
        "provider": provider,
        "redirect_uri": redirect_uri,
        "verifier": verifier,
        "expires": int(time.time()) + STATE_TTL_SECONDS,
        "nonce": secrets.token_urlsafe(24),
    }
    body = b64(json.dumps(payload, separators=(",", ":")).encode())
    signature = hmac.new(setting("OAUTH_STATE_SECRET").encode(), body.encode(), hashlib.sha256).digest()
    return f"{body}.{b64(signature)}"


def decode_state(value: str, provider: str) -> dict:
    try:
        body, signature = value.split(".", 1)
        expected = hmac.new(setting("OAUTH_STATE_SECRET").encode(), body.encode(), hashlib.sha256).digest()
        if not hmac.compare_digest(signature, b64(expected)):
            raise ValueError
        payload = json.loads(base64.urlsafe_b64decode(body + "=" * (-len(body) % 4)))
        if payload["provider"] != provider or int(payload["expires"]) < time.time():
            raise ValueError
        validate_redirect(payload["redirect_uri"])
        return payload
    except (ValueError, KeyError, TypeError, json.JSONDecodeError):
        raise HTTPException(400, "Invalid or expired OAuth state.")


def validate_provider(provider: str) -> None:
    if provider not in PROVIDERS:
        raise HTTPException(404, "Unsupported OAuth provider.")


def validate_redirect(redirect_uri: str) -> str:
    parsed = urlparse(redirect_uri)
    if (
        parsed.scheme != "http"
        or parsed.hostname != "127.0.0.1"
        or parsed.port != int(os.getenv("OAUTH_CALLBACK_PORT", "8080"))
        or parsed.path != "/callback"
        or parsed.query
        or parsed.fragment
    ):
        raise HTTPException(400, "Only the configured loopback callback is allowed.")
    return redirect_uri


def provider_config(provider: str, verifier: str) -> tuple[str, str, dict[str, str]]:
    callback = f"{setting('OAUTH_CALLBACK_BASE_URL').rstrip('/')}/api/callback/{provider}"
    challenge = b64(hashlib.sha256(verifier.encode()).digest())
    if provider == "youtube":
        return (
            "https://accounts.google.com/o/oauth2/v2/auth",
            "https://oauth2.googleapis.com/token",
            {
                "client_id": setting("YOUTUBE_CLIENT_ID"),
                "response_type": "code",
                "redirect_uri": callback,
                "scope": "https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.readonly",
                "access_type": "offline",
                "prompt": "consent",
                "code_challenge": challenge,
                "code_challenge_method": "S256",
            },
        )
    if provider == "instagram":
        return (
            "https://www.instagram.com/oauth/authorize",
            "https://api.instagram.com/oauth/access_token",
            {
                "client_id": setting("INSTAGRAM_CLIENT_ID"),
                "response_type": "code",
                "redirect_uri": callback,
                "scope": "instagram_business_basic,instagram_business_content_publish",
            },
        )
    return (
        "https://www.tiktok.com/v2/auth/authorize/",
        "https://open.tiktokapis.com/v2/oauth/token/",
        {
            "client_key": setting("TIKTOK_CLIENT_KEY"),
            "response_type": "code",
            "redirect_uri": callback,
            "scope": "user.info.basic,video.publish,video.upload",
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        },
    )


def client_secret(provider: str) -> str:
    return setting({"youtube": "YOUTUBE_CLIENT_SECRET", "instagram": "INSTAGRAM_CLIENT_SECRET", "tiktok": "TIKTOK_CLIENT_SECRET"}[provider])


async def exchange(provider: str, code: str, state: dict) -> dict:
    _, token_url, parameters = provider_config(provider, state["verifier"])
    body = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": parameters["redirect_uri"],
        "client_secret": client_secret(provider),
    }
    if provider == "tiktok":
        body["client_key"] = parameters["client_key"]
        body["code_verifier"] = state["verifier"]
    else:
        body["client_id"] = parameters["client_id"]
        if provider == "youtube":
            body["code_verifier"] = state["verifier"]
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(token_url, data=body)
    if response.status_code >= 300:
        raise HTTPException(502, "Provider rejected the authorization code.")
    tokens = response.json()
    if not isinstance(tokens.get("access_token"), str):
        raise HTTPException(502, "Provider returned no access token.")
    return tokens


async def profile(provider: str, tokens: dict) -> dict:
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    urls = {
        "youtube": "https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true",
        "instagram": "https://graph.instagram.com/v22.0/me?fields=id,username",
        "tiktok": "https://open.tiktokapis.com/v2/user/info/?fields=open_id,display_name",
    }
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.get(urls[provider], headers=headers)
    if response.status_code >= 300:
        raise HTTPException(502, "Provider account lookup failed.")
    data = response.json()
    if provider == "youtube":
        item = (data.get("items") or [{}])[0]
        return {"provider_account_id": item.get("id"), "label": item.get("snippet", {}).get("title", "YouTube channel")}
    if provider == "instagram":
        return {"provider_account_id": data.get("id"), "label": data.get("username", "Instagram account")}
    user = data.get("data", {}).get("user", {})
    return {"provider_account_id": user.get("open_id"), "label": user.get("display_name", "TikTok account")}


@app.get("/api/start/{provider}")
async def start(provider: str, redirect_uri: str = Query(...)):
    validate_provider(provider)
    validate_redirect(redirect_uri)
    state = state_value(provider, redirect_uri)
    payload = decode_state(state, provider)
    endpoint, _, parameters = provider_config(provider, payload["verifier"])
    parameters["state"] = state
    return JSONResponse({"authorization_url": f"{endpoint}?{urlencode(parameters)}"}, headers={"Cache-Control": "no-store"})


@app.get("/api/callback/{provider}")
async def callback(provider: str, code: str | None = None, state: str | None = None, error: str | None = None):
    validate_provider(provider)
    if not state:
        raise HTTPException(400, "OAuth state is missing.")
    signed = decode_state(state, provider)
    query = {"provider": provider}
    try:
        if error or not code:
            query["error"] = "authorization_failed"
        else:
            tokens = await exchange(provider, code, signed)
            account = await profile(provider, tokens)
            query.update({"access_token": tokens["access_token"], "provider_account_id": str(account.get("provider_account_id") or ""), "label": str(account.get("label") or provider)})
            if isinstance(tokens.get("refresh_token"), str):
                query["refresh_token"] = tokens["refresh_token"]
    except HTTPException:
        query["error"] = "authorization_failed"
    return RedirectResponse(f"{signed['redirect_uri']}?{urlencode(query)}", status_code=302, headers={"Cache-Control": "no-store"})
