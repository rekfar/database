-- Credentials and sign-in state (ADR-0010 T9: ASP.NET Core Identity).
-- Deliberately separate from `app` so the authentication mechanism can change
-- (OAuth, FR-ACC-1) without touching domain data.
CREATE SCHEMA auth;
