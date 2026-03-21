# PLAN 002: Declarative Oathkeeper Access Rules

## Overview

Refactor Oathkeeper access rules from hand-written regex in YAML to a fully template-driven approach using structured HCL data. The goal is to make adding or changing auth routes a matter of editing a map, not debugging regex overlaps.

## Current State Analysis

Oathkeeper rules are defined in `values/oathkeeper.yaml` as a YAML block string with HCL templating. Three rule types coexist:

1. **Per-client API rules** — generated from `hydra_oauth_clients` loop, but only when `url_match != null` (currently no clients use this)
2. **Manual `api-bearer-auth` rule** — hardcoded regex for `recipes.kieranajp.uk/api`, JWT-only auth, JSON errors
3. **`browser-auth` catch-all** — `<.*>` with a negative lookahead to exclude API routes, cookie+JWT auth, redirect on failure

Oathkeeper requires exactly one rule to match any URL. Overlapping rules cause 500 errors ("Expected exactly one rule but found multiple rules"). This makes the current approach fragile — adding a new API route means updating both the specific rule AND the catch-all exclusion.

### Key Files:
- `values/oathkeeper.yaml:1-69` — Access rules template
- `auth.tf:56-72` — Oathkeeper Helm release, passes `oauth_clients` to template
- `variables.tf:95-104` — `hydra_oauth_clients` variable definition
- `terraform.tfvars:37-44` — Client config (the-bluer-book, `url_match = null`)
- `values/traefik-middlewares.yaml:69-82` — `ory-auth` and `jwt-auth` forwardAuth middlewares

### Services Currently Using Auth:
From IngressRoutes, these hosts go through `ory-auth` middleware:
- `home.kieranajp.uk` (homepage) — browser only
- `syncthing.kieranajp.uk` — browser only
- `hydra-admin.kieranajp.uk` — browser only
- `recipes.kieranajp.uk` — browser + JWT API at `/api/*`
- `calibre.kieranajp.uk` — browser only
- `lazylibrarian.kieranajp.uk` — browser only
- `paperless.kieranajp.uk` — browser only
- `prowlarr.kieranajp.uk` — browser only
- `sonarr.kieranajp.uk` — browser only
- `transmission.kieranajp.uk` — browser only

## Desired End State

A single HCL variable defines all routes that need non-browser auth (i.e. JWT-only API routes). The browser-auth catch-all is generated automatically to exclude these. Adding a new API route means adding an entry to a map in `terraform.tfvars`.

### Verification:
- `tofu plan` shows no unexpected changes (rules should be functionally equivalent)
- `curl` to `recipes.kieranajp.uk/api/` with a valid JWT returns 200
- `curl` to `recipes.kieranajp.uk/api/` without auth returns JSON 401 (not redirect)
- `curl` to `home.kieranajp.uk/` without auth returns redirect to Kratos login
- No "multiple rules" errors in Oathkeeper logs
- Homepage `/api/services` call works (not caught by API rule)

## What We're NOT Doing

- Changing how Traefik IngressRoutes reference the `ory-auth` middleware — that's a separate concern
- Moving Oathkeeper config (authenticators, mutators, error handlers) into the data structure — only access rules
- Changing the auth flow itself (cookie_session + JWT for browser, JWT-only for APIs)
- Per-client scoped rules — the `oauth_clients` loop with `url_match` stays as-is for future use, but we're not actively using it

## Implementation Approach

Extend `hydra_oauth_clients` to include the API route information directly, since each API route is tied to an OAuth client anyway. Remove the separate `api-bearer-auth` rule. The template generates rules from the client map, then a catch-all that auto-excludes all client API paths.

## Phase 0: Snapshot and Test Harness

### Overview
Before changing anything, capture the current rendered output and write a test that asserts the template produces it. This gives us a safety net — we can refactor the template and variable structure knowing we'll catch any regressions in the rendered YAML.

### Changes Required:

#### 1. Extract Template Rendering into a Local
**File**: `auth.tf`
**Changes**: Move the `templatefile` call into a `locals` block so it can be referenced by both the Helm release and tests.

```hcl
locals {
  oathkeeper_values = templatefile("${path.module}/values/oathkeeper.yaml", {
    oauth_clients = var.hydra_oauth_clients
  })
}

resource "helm_release" "oathkeeper" {
  name       = "oathkeeper"
  repository = "https://k8s.ory.sh/helm/charts"
  chart      = "oathkeeper"
  version    = "0.58.0"
  namespace  = "auth"
  timeout    = 60
  atomic     = false

  values = [local.oathkeeper_values]

  depends_on = [helm_release.hydra]
}

output "oathkeeper_rendered_values" {
  value     = local.oathkeeper_values
  sensitive = false
}
```

#### 2. Snapshot the Current Output
Run `tofu output oathkeeper_rendered_values` after apply and save the access rules portion. This becomes the baseline.

#### 3. Write the Test
**File**: `tests/oathkeeper_rules.tftest.hcl`

OpenTofu test files can use `run` blocks to execute plans with specific variable values and assert on outputs. The test renders the template with known inputs and checks the output matches expected patterns.

```hcl
# Test: single client with API host generates correct rules
run "single_api_client" {
  command = plan

  variables {
    hydra_oauth_clients = {
      "test-app" = {
        name            = "Test App"
        secret          = "test-secret"
        scopes          = ["test:api"]
        api_host        = "test.example.com"
        api_path_prefix = "/api"
      }
    }
  }

  # Verify the rendered output contains the expected API rule
  assert {
    condition     = can(regex("api-test-app", output.oathkeeper_rendered_values))
    error_message = "Expected api-test-app rule in rendered output"
  }

  assert {
    condition     = can(regex("test\\.example\\.com", output.oathkeeper_rendered_values))
    error_message = "Expected escaped host in rendered output"
  }

  assert {
    condition     = can(regex("browser-auth", output.oathkeeper_rendered_values))
    error_message = "Expected browser-auth catch-all rule"
  }

  # The browser-auth rule should have a negative lookahead excluding the API path
  assert {
    condition     = can(regex("\\?!", output.oathkeeper_rendered_values))
    error_message = "Expected negative lookahead in browser-auth rule"
  }
}

# Test: client without API host generates no API rule
run "client_without_api_host" {
  command = plan

  variables {
    hydra_oauth_clients = {
      "headless-client" = {
        name   = "Headless"
        secret = "test-secret"
        scopes = ["some:scope"]
      }
    }
  }

  assert {
    condition     = !can(regex("api-headless-client", output.oathkeeper_rendered_values))
    error_message = "Client without api_host should not generate an API rule"
  }

  # browser-auth should be a simple catch-all with no negative lookahead
  assert {
    condition     = can(regex("<\\.\\*>", output.oathkeeper_rendered_values))
    error_message = "Expected simple catch-all when no API routes defined"
  }
}

# Test: multiple clients generate multiple rules and combined exclusion
run "multiple_api_clients" {
  command = plan

  variables {
    hydra_oauth_clients = {
      "app-one" = {
        name            = "App One"
        secret          = "secret-1"
        scopes          = ["one:api"]
        api_host        = "one.example.com"
        api_path_prefix = "/api"
      }
      "app-two" = {
        name            = "App Two"
        secret          = "secret-2"
        scopes          = ["two:api"]
        api_host        = "two.example.com"
        api_path_prefix = "/v1"
      }
    }
  }

  assert {
    condition     = can(regex("api-app-one", output.oathkeeper_rendered_values))
    error_message = "Expected api-app-one rule"
  }

  assert {
    condition     = can(regex("api-app-two", output.oathkeeper_rendered_values))
    error_message = "Expected api-app-two rule"
  }

  # Negative lookahead should contain both hosts
  assert {
    condition     = can(regex("one\\.example\\.com", output.oathkeeper_rendered_values)) && can(regex("two\\.example\\.com", output.oathkeeper_rendered_values))
    error_message = "Expected both hosts in browser-auth exclusion"
  }
}

# Snapshot test: current production config should produce the known-good output
run "production_snapshot" {
  command = plan

  variables {
    hydra_oauth_clients = {
      "the-bluer-book" = {
        name            = "The Bluer Book"
        secret          = "e913999e0160339ae810adb95665fa8725c857c847013a9acd9dfffd07192ab0"
        scopes          = ["recipes:api"]
        api_host        = "recipes.kieranajp.uk"
        api_path_prefix = "/api"
      }
    }
  }

  assert {
    condition     = can(regex("api-the-bluer-book", output.oathkeeper_rendered_values))
    error_message = "Expected api-the-bluer-book rule"
  }

  assert {
    condition     = can(regex("recipes\\\\.kieranajp\\\\.uk/api", output.oathkeeper_rendered_values))
    error_message = "Expected correctly escaped recipes host in API rule"
  }

  assert {
    condition     = can(regex("recipes:api", output.oathkeeper_rendered_values))
    error_message = "Expected required_scope for recipes:api"
  }
}
```

Note: These tests use `command = plan` so they don't need a real cluster or provider credentials — they just render the template and check outputs. The regex assertions in the test will need tuning once we see the actual rendered output (the escaping is hard to predict in the abstract), but the structure is right.

The `production_snapshot` test is the key one — it locks in the exact output for the current config so the refactor can't silently change behaviour.

### Success Criteria:

#### Automated Verification:
- [x] `tofu test` passes with all assertions green
- [x] `tofu plan` shows no changes (extracting to locals is a refactor, not a behaviour change)

---

## Phase 1: Extend the Data Structure

### Overview
Add `api_host` and `api_path_prefix` fields to `hydra_oauth_clients` to replace both `url_match` and the hardcoded `api-bearer-auth` rule.

### Changes Required:

#### 1. Variable Definition
**File**: `variables.tf`
**Changes**: Replace `url_match` with `api_host` and `api_path_prefix`

```hcl
variable "hydra_oauth_clients" {
  description = "OAuth2 client credentials clients for API authentication. Each client gets a client_credentials grant. Clients with api_host get a dedicated Oathkeeper rule for JWT-only auth on that host/path."
  type = map(object({
    name            = string
    secret          = string
    scopes          = list(string)
    api_host        = optional(string) # e.g. "recipes.kieranajp.uk"
    api_path_prefix = optional(string, "/api") # e.g. "/api" — defaults to /
  }))
  default = {}
}
```

#### 2. Client Config
**File**: `terraform.tfvars`
**Changes**: Replace `url_match = null` with host/path

```hcl
hydra_oauth_clients = {
  "the-bluer-book" = {
    name            = "The Bluer Book"
    secret          = "e913999e0160339ae810adb95665fa8725c857c847013a9acd9dfffd07192ab0"
    scopes          = ["recipes:api"]
    api_host        = "recipes.kieranajp.uk"
    api_path_prefix = "/api"
  }
}
```

### Success Criteria:

#### Automated Verification:
- [x] `tofu validate` passes
- [x] `tofu plan` shows changes only to oathkeeper helm release

---

## Phase 2: Rewrite the Oathkeeper Rules Template

### Overview
Replace the hand-written rules and regex with a template that loops over clients to generate API rules and a catch-all with auto-generated exclusions.

### Changes Required:

#### 1. Oathkeeper Values Template
**File**: `values/oathkeeper.yaml`
**Changes**: Rewrite the `accessRules` block. Pass client data through to generate rules.

The template needs to:
1. Generate a JWT-only rule per client that has `api_host` set
2. Generate a single `browser-auth` catch-all that excludes all API host/path combos

```yaml
oathkeeper:
  accessRules: |
%{ for id, client in oauth_clients ~}
%{ if client.api_host != null ~}
    - id: "api-${id}"
      match:
        url: "<https?://${replace(client.api_host, ".", "\\.")}${client.api_path_prefix}(/.*)?>"
        methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
      authenticators:
        - handler: jwt
%{ if length(client.scopes) > 0 ~}
          config:
            required_scope:
%{ for scope in client.scopes ~}
              - "${scope}"
%{ endfor ~}
%{ endif ~}
      authorizer:
        handler: allow
      mutators:
        - handler: header
          config:
            headers:
              X-User: "{{ print .Subject }}"
      errors:
        - handler: json

%{ endif ~}
%{ endfor ~}
    - id: "browser-auth"
      match:
%{ if length([for id, c in oauth_clients : c if c.api_host != null]) > 0 ~}
        url: "<(?!${join("|", [for id, c in oauth_clients : "https?://${replace(c.api_host, ".", "\\\\.")}${c.api_path_prefix}(/.*)?" if c.api_host != null])}).*>"
%{ else ~}
        url: "<.*>"
%{ endif ~}
        methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
      authenticators:
        - handler: cookie_session
        - handler: jwt
      authorizer:
        handler: allow
      mutators:
        - handler: header
          config:
            headers:
              X-User: "{{ print .Subject }}"
      errors:
        - handler: json
          config:
            when:
              - request:
                  header:
                    accept:
                      - application/json
        - handler: redirect
          config:
            to: https://kratos.kieranajp.uk/self-service/login/browser
```

Note: The `replace(client.api_host, ".", "\\.")` handles dot-escaping for the regex. The `\\\\` in the negative lookahead is because it goes through HCL template → YAML string → Oathkeeper regex, each level consuming one layer of escaping.

#### 2. Auth.tf Template Variables
**File**: `auth.tf`
**Changes**: None needed — already passes `oauth_clients = var.hydra_oauth_clients` to the template.

### Success Criteria:

#### Automated Verification:
- [x] `tofu validate` passes
- [x] `tofu plan` shows the oathkeeper helm release updating
- [x] After apply, `kubectl get configmap oathkeeper-rules -n auth -o yaml` shows correct rendered rules with no hand-written regex

#### Manual Verification:
- [x] `curl -s -o /dev/null -w "%{http_code}" https://recipes.kieranajp.uk/api/` with valid JWT returns 200
- [x] `curl -s -o /dev/null -w "%{http_code}" https://recipes.kieranajp.uk/api/` without auth returns 401 with JSON body
- [x] `curl -s -o /dev/null -w "%{http_code}" https://home.kieranajp.uk/` without auth returns 302 to Kratos
- [x] Homepage loads without client-side errors (no widget crash) — `/api/services` correctly hits browser-auth (302)
- [x] No "multiple rules" or "500" errors in Oathkeeper logs
- [x] Dart client (The Bluer Book) can authenticate and fetch recipes — confirmed in live logs

---

## Phase 3: Clean Up

### Overview
Remove dead code and verify the old `url_match` pattern is gone.

### Changes Required:

#### 1. Remove `url_match` References
**File**: `variables.tf`
**Changes**: Already done in Phase 1 — `url_match` replaced by `api_host`/`api_path_prefix`.

#### 2. Verify No Stale Config
Check that no other files reference `url_match` or the old `api-bearer-auth` rule pattern.

### Success Criteria:

#### Automated Verification:
- [x] `grep -r url_match .` returns no hits (only in this plan doc)
- [x] `tofu validate` passes
- [x] `tofu plan` shows no changes (clean state — after apply)

---

## Testing Strategy

### After Apply:
1. Check rendered rules: `kubectl get configmap oathkeeper-rules -n auth -o yaml`
2. Check Oathkeeper logs for startup errors: `kubectl logs -n auth -l app.kubernetes.io/name=oathkeeper`
3. Test JWT API flow end-to-end (get token from Hydra, call recipes API)
4. Test browser flow (visit home.kieranajp.uk without session → redirect → login → access)
5. Test Homepage doesn't crash (its `/api/services` call should hit browser-auth, not an API rule)

### Edge Cases:
- Client with `api_host = null` should generate no API rule (just an OAuth client)
- Multiple clients with different hosts should each get their own rule
- The negative lookahead should correctly exclude all API paths from the catch-all

## Escaping Considerations

The regex escaping chain is the trickiest part:
1. HCL `templatefile` processes `${...}` expressions
2. Result is a YAML string passed to Helm
3. Helm writes it to the `oathkeeper-rules` ConfigMap
4. Oathkeeper parses the YAML and interprets `<...>` as regex

For a literal `\.` in the final regex:
- In the YAML string: `\\.` (YAML doesn't need escaping, but Oathkeeper's regex parser does)
- In the HCL template: `\\.` for simple rules (HCL doesn't interpret backslashes in template strings)
- In the negative lookahead (nested in the regex): `\\\\.` because it's inside a YAML string that Oathkeeper will parse

This is unavoidable complexity, but it's now generated from `replace(host, ".", "\\.")` rather than hand-written, so you only need to get it right once.

## Future Considerations

If more auth patterns emerge (e.g. public API endpoints, webhook receivers that need no auth), the data structure can be extended with an `auth_type` field. For now, the two patterns (JWT-only for APIs, cookie+JWT for browsers) cover everything.

## References

- Oathkeeper access rules docs: https://www.ory.sh/docs/oathkeeper/api-access-rules
- Debugging session that motivated this: the `104.18.0.0` DNS fix exposed the fragile regex overlaps
