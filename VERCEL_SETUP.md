# Vercel OAuth Bridge

Deploy this repository as a Vercel project. The FastAPI entrypoint is `api/index.py`.

Set these Vercel environment variables for Preview and Production:

```text
OAUTH_STATE_SECRET
OAUTH_CALLBACK_BASE_URL
OAUTH_CALLBACK_PORT=8080
YOUTUBE_CLIENT_ID
YOUTUBE_CLIENT_SECRET
INSTAGRAM_CLIENT_ID
INSTAGRAM_CLIENT_SECRET
TIKTOK_CLIENT_KEY
TIKTOK_CLIENT_SECRET
```

Set `OAUTH_CALLBACK_BASE_URL` to the deployed origin, without a trailing slash.
Register these provider callback URLs:

```text
https://your-origin.vercel.app/api/callback/youtube
https://your-origin.vercel.app/api/callback/instagram
https://your-origin.vercel.app/api/callback/tiktok
```

Build the desktop app with:

```text
flutter pub get
flutter build windows --dart-define=OAUTH_API_BASE_URL=https://your-origin.vercel.app
flutter build linux --dart-define=OAUTH_API_BASE_URL=https://your-origin.vercel.app
```

The bridge stores no users, OAuth state, or provider tokens. It signs state with
`OAUTH_STATE_SECRET`, exchanges the provider code, and redirects the result to
the desktop loopback listener. The desktop app stores tokens using
`flutter_secure_storage`.

Do not log callback URLs: access and refresh tokens are returned in the callback
query string by design for this stateless bridge.
