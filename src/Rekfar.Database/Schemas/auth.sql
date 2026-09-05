-- Accounts and sign-in state (ADR-0010 T9: ASP.NET Core Identity). No credential is
-- stored here: sign-in is a one-time code emailed to the user (ADR-0017).
-- Deliberately separate from `app` so the authentication mechanism can change
-- (social OAuth or passkeys later, FR-ACC-1) without touching domain data.
CREATE SCHEMA auth;
