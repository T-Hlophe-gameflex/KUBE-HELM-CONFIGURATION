"""Ansible filter plugin: cloudflare_name

Provides naming-convention helpers used by the platform workflow to transform
and sanitize DNS record names across domains.

Functions:
- sanitize_label(s): lowercase, replace spaces/invalid chars with '-', trim to 63 chars
- normalize_name(original_name, domain, env, service, pattern): transform a source
  record name to a target name according to supported patterns.

Usage in playbook:
  - debug: msg="{{ 'MyService' | sanitize_label }}"
  - debug: msg="{{ original_name | normalize_name('efutechnologies.co.za','prod','svc', 'new') }}"
"""

import re

MAX_LABEL_LEN = 63


def sanitize_label(s):
    if s is None:
        return ''
    # Convert to str, lowercase
    s = str(s).strip()
    s = s.lower()
    # Replace spaces and invalid chars with hyphen
    s = re.sub(r"[^a-z0-9-]", "-", s)
    # Collapse multiple hyphens
    s = re.sub(r"-+", "-", s)
    # Trim hyphens from ends
    s = s.strip('-')
    # Truncate to MAX_LABEL_LEN
    if len(s) > MAX_LABEL_LEN:
        s = s[:MAX_LABEL_LEN]
        # remove trailing dash after truncation
        s = s.rstrip('-')
    return s


def normalize_name(original_name, domain, env, service, pattern='new'):
    """Normalize/transform a name according to patterns.

    Patterns supported:
      - 'legacy': $domain-{env}{num} (best attempt)
      - 'new': {env}{num}-{service}
      - 'mixed': {service}-{env}{num}
      - 'special': {name}-{service}
      - 'direct': {function_name}

    For patterns that require extracting an env/num from the original name,
    this function will attempt simple heuristics. The caller should validate
    the result as needed.
    """
    orig = original_name or ''
    env = (env or '').strip()
    service = (service or '').strip()
    domain = (domain or '').strip()

    # sanitize inputs first
    base = sanitize_label(orig)
    svc = sanitize_label(service)
    env_lbl = sanitize_label(env)

    # heuristic: if orig contains digits at end, capture trailing number
    m = re.search(r"(.*?)(\d+)$", orig)
    num = ''
    if m:
        base = sanitize_label(m.group(1))
        num = m.group(2)

    if pattern == 'legacy':
        # fallback to domain-{env}{num}
        parts = []
        if domain:
            # use the leftmost label of domain
            parts.append(domain.split('.')[0])
        if env_lbl:
            parts.append(env_lbl + (num or ''))
        name = '-'.join([p for p in parts if p])
    elif pattern == 'new':
        # {env}{num}-{service}
        prefix = env_lbl + (num or '')
        name = prefix + ('-' + svc if svc else '')
    elif pattern == 'mixed':
        # {service}-{env}{num}
        name = svc + ('-' + env_lbl + (num or '')) if svc else env_lbl + (num or '')
    elif pattern == 'special':
        # {name}-{service}
        name = base + ('-' + svc if svc else '')
    elif pattern == 'direct':
        # direct function name (use base)
        name = base
    else:
        # default to special
        name = base + ('-' + svc if svc else '')

    # sanitize final name and ensure length
    name = sanitize_label(name)

    return name


class FilterModule(object):
    """Ansible filter plugin entrypoint"""

    def filters(self):
        return {
            'sanitize_label': sanitize_label,
            'normalize_name': normalize_name,
        }
