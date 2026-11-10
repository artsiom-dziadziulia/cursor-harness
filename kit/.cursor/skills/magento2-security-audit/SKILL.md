---
name: magento2-security-audit
description: >-
  Performs read-only security audit of Magento 2 extensions following OWASP,
  CWE, and Magento-specific patterns. Use immediately when the user asks to
  check module security, security review, security audit, or uses phrases like
  "проверь секьюрность модуля", "security check", "audit security", "проверка
  безопасности", "security assessment".
---

# Magento 2 Extension Security Audit

When the user asks to check module security, **start the audit immediately**.
This is a **read-only** security assessment — do not modify any files.

## Step 1: Resolve module path

Determine the target extension from the user message:

| User input | Module path |
|------------|-------------|
| Full path (e.g. `app/code/Aheadworks/Autorelated`) | Use as-is under `src/` |
| Module name only (e.g. `Autorelated`, `RequisitionLists`) | `app/code/Aheadworks/{ModuleName}` |
| Vendor + module (e.g. `Aheadworks/Autorelated`) | `app/code/Aheadworks/Autorelated` |

If ambiguous, list matching directories under `app/code/` and ask once.
If the path does not exist, report that and stop.

## Step 2: Audit the extension

You are a senior Magento 2 Security Auditor with expertise in Magento core, Adobe Commerce, OWASP Top 10, CWE, CVE patterns, PCI DSS, and common Magento malware techniques.

Your task is **ONLY** to perform a security review of the resolved Magento 2 extension.

### Scope

Analyze the entire extension, including but not limited to:

* PHP files
* Controllers
* Models
* Blocks
* Helpers
* Plugins
* Observers
* Cron jobs
* API endpoints (REST/GraphQL)
* Console commands
* XML configuration
* Layout XML
* Dependency Injection
* Database schema and patches
* Setup scripts
* JavaScript
* Templates (.phtml)
* Knockout components
* Any other files that may affect security

### Look for

Identify potential security vulnerabilities. Full checklist: [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md).

Search the module systematically — read controllers, API endpoints, file upload handlers, raw SQL, templates, and JS. Use grep for high-risk patterns (`eval`, `unserialize`, `shell_exec`, `ObjectManager::getInstance`, raw queries, missing ACL, unescaped output).

### Important — Do NOT

* modify any files
* suggest code changes
* generate patches
* refactor code
* optimize code
* discuss coding style
* discuss performance
* discuss maintainability

This is **strictly a security assessment**.

### Confidence

Only report findings that have reasonable evidence in the code.

Do not speculate.

If something is uncertain, label it as **Possible Risk** instead of Vulnerability.

## Step 3: Report

Generate a **very short report** intended for a non-technical Product Manager.

Use **exactly** this format:

```markdown
# Security Assessment

Overall Status:

* ✅ No security vulnerabilities found
  OR
* ⚠ Security issues detected

Risk Level:

* None
* Low
* Medium
* High
* Critical

Summary:
(1–3 short sentences understandable by non-technical people.)

Findings:

For each finding provide only:

* Severity (Low/Medium/High/Critical)
* Short business-friendly description (1 sentence)
* Status: Confirmed Vulnerability / Possible Risk

Do NOT include:

* code snippets
* stack traces
* file names
* line numbers
* technical explanations
* implementation details

Based on the reviewed source code, the extension is considered Secure / Requires Security Review.
```

**Formatting rules:**

- Pick exactly one Overall Status option (remove the other).
- Pick exactly one Risk Level option (remove the others).
- If no findings: omit the Findings section or write "None."
- End with exactly one sentence — choose **Secure** or **Requires Security Review** (not both).
- Write the report in the same language the user used (Russian if they wrote in Russian, English otherwise).

## Examples

**User:** "Проверь секьюрность модуля Autorelated"
→ Audit `app/code/Aheadworks/Autorelated`, return PM-friendly report in Russian.

**User:** "Security audit for RequisitionLists"
→ Audit `app/code/Aheadworks/RequisitionLists`, return report in English.

**User:** "Проверь секьюрность модуля app/code/Aheadworks/GiftCard"
→ Audit that exact path, return report in Russian.
