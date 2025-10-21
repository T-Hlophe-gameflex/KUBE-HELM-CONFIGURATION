def cloudflare_naming(name, env=None, num=None, service=None, pattern="new"):
    """
    Apply Cloudflare naming conventions:
    - Legacy: $domain-{env}{num}
    - New: {env}{num}-{service}
    - Mixed: {service}-{env}{num}
    - Special: {name}-{service} (APIs)
    - Direct: {name} (utility)
    """
    if pattern == "legacy":
        return f"{name}-{env or ''}{num or ''}"
    elif pattern == "new":
        return f"{env or ''}{num or ''}-{service or name}"
    elif pattern == "mixed":
        return f"{service or name}-{env or ''}{num or ''}"
    elif pattern == "special":
        return f"{name}-{service or ''}"
    elif pattern == "direct":
        return name
    else:
        return name

def filters():
    return {
        'cloudflare_naming': cloudflare_naming
    }
