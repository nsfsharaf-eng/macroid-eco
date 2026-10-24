# Security and Privacy Policy

Macdroid Mirror is committed to ensuring transparent, secure, and privacy-preserving Android device interaction on macOS.

## Core Security Commitments

1. **No Authorization Bypass**:
   Macdroid Mirror never attempts to circumvent or weaken the official Android USB debugging authorization protocol. Every connection requires explicit user confirmation of the RSA key fingerprint on the physical phone screen.

2. **No Root Requirement**:
   Macdroid Mirror does not require or recommend rooting Android devices. All communication operates strictly through standard, unprivileged ADB interfaces.

3. **No Background Screen Recording or Surveillance**:
   Mirroring sessions are launched only upon direct user request and display an explicit mirroring window. No hidden background recording or interception is performed.

4. **Zero Telemetry and Remote Network Transmission**:
   Macdroid Mirror contains no analytics tracking, no cloud telemetry, and no network transmission of phone identifiers, contents, or screenshots. All data remains exclusively on your local Mac and USB cable.

5. **Safe Process Invocation**:
   Subprocesses (ADB and scrcpy) are executed directly via `Foundation.Process` with individual, discrete argument arrays. Shell string interpolation (`/bin/sh -c ...`) is strictly prohibited, preventing command-injection attacks.

6. **Clean Process Lifecycle**:
   When Macdroid Mirror is closed or a session is stopped, all child processes are terminated cleanly via `SIGTERM` / `SIGKILL` to prevent orphan background processes.

## Reporting Security Vulnerabilities

If you discover a security vulnerability in Macdroid Mirror:
1. Please do **NOT** open a public issue.
2. Email the maintainers directly with a detailed description and proof of concept.
3. Maintainers will respond within 48 hours to confirm the issue and coordinate a remediation release.
