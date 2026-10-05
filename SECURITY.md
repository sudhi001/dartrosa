# Security policy

## Supported versions

DartRosa is pre-1.0. Security fixes go into the latest published release
of each package; older releases are not patched.

## Reporting a vulnerability

Please report vulnerabilities privately, not in public issues:

- **GitHub:** open a private report from the repository's
  [Security tab](https://github.com/sudhi001/dartrosa/security/advisories/new)
  ("Report a vulnerability"), or
- **Email:** [support@sudhi.in](mailto:support@sudhi.in).

Include the affected package and version, a description of the problem,
and steps or a form that reproduces it. You can expect an acknowledgement
within a week. Please give us a reasonable time to fix the issue before
disclosing it publicly; we credit reporters in the release notes unless
you ask us not to.

## Scope

In scope: the packages in this repository, especially form parsing and
XPath evaluation of untrusted forms, the submission encryption in
`dartrosa_encryption`, and the OpenRosa client in `dartrosa_openrosa`.

Out of scope: `packages/dartrosa_encryption/tool/golden/test_private_key.pem`
is a published, test-only key used to generate test fixtures; it protects
nothing. Issues in JavaRosa or ODK Collect themselves should be reported to
those projects.
