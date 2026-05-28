# Security Policy

## Supported Versions

This project is in active development and has not yet shipped a
tagged release. Only the latest commit on the `main` branch is
considered supported. Once the project ships a versioned release,
this section will be updated to list the supported version range.

| Version | Supported          |
| ------- | ------------------ |
| `main`  | :white_check_mark: |

## Reporting a Vulnerability

Please report suspected security vulnerabilities privately through
GitHub's "Report a vulnerability" form:

[Open a private vulnerability report](https://github.com/featgg/app/security/advisories/new)

Do not open a public issue, pull request, or discussion thread for a
suspected vulnerability before a fix is published.

If you cannot access the private reporting form, open a minimal
public issue stating only that you have a private security report
ready and asking the maintainer to contact you. Do not include
vulnerability details in that public issue.

### What to include in a report

A useful report contains, at minimum:

- The affected version (commit SHA on `main`, or release tag once
  releases exist).
- A description of the vulnerability and its impact.
- Steps to reproduce, including any required configuration.
- A suggested remediation if you have one.

### What to expect

Reports are handled by Nicolas Ferrada. As a solo maintainer, the
following timelines are best-effort commitments rather than guarantees:

- Acknowledgement of the report within five business days.
- Initial assessment (confirmed, needs-info, or out-of-scope) within
  fourteen calendar days of acknowledgement.
- A fix or a coordinated-disclosure plan within ninety calendar days
  of confirmation, in line with standard open-source coordinated
  disclosure practice.

### Coordinated disclosure

Please do not publicly discuss the vulnerability, including in blog
posts, conference talks, or social media, until a fix has been
published or the ninety-day window above has elapsed, whichever comes
first. If you need to deviate from this window for any reason,
mention it in the initial report so we can coordinate.

### Safe harbor

Good-faith security research conducted in accordance with this
policy is welcome. We will not pursue or support legal action against
researchers who:

- Make a good-faith effort to avoid privacy violations, destruction
  of data, and interruption or degradation of the service.
- Only interact with accounts they own or have explicit permission
  from the account holder to access.
- Report the vulnerability promptly through the private channel
  described above and do not disclose it publicly before coordinated
  disclosure.

This statement does not waive any rights of third parties, and it is
not a substitute for applicable law.

## Scope

In scope:

- Vulnerabilities in the source code of this repository
  (`featgg/app`), including the Flutter client and its
  build configuration.
- Vulnerabilities in the build or release pipeline defined in this
  repository (for example, the GitHub Actions workflows under
  `.github/workflows/`).

Out of scope:

- The backend service this client communicates with. It is a
  separate scope and is not covered by this policy.
- Third-party services or libraries this project depends on. Please
  report those directly to the upstream maintainers; advisories that
  affect this project will be tracked once a fix exists upstream.
- Vulnerabilities that require a rooted, jailbroken, or otherwise
  user-modified device, or that depend on sideloaded or repackaged
  builds of the application.
- Social engineering of maintainers, contributors, or users.
- Denial-of-service reports that depend on overwhelming client
  hardware or network resources.
