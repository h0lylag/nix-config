
# Appended by the Nix package. v1 is retired and only the relay still runs:
# PRISM_BEAT_KEEP names the beat entries to keep; empty keeps them all.
PRISM_BEAT_KEEP = config("PRISM_BEAT_KEEP", default="", cast=Csv())
if PRISM_BEAT_KEEP:
    _unknown = set(PRISM_BEAT_KEEP) - set(CELERY_BEAT_SCHEDULE)
    if _unknown:
        raise ValueError(f"PRISM_BEAT_KEEP names unknown beat entries: {sorted(_unknown)}")
    CELERY_BEAT_SCHEDULE = {
        name: entry for name, entry in CELERY_BEAT_SCHEDULE.items() if name in PRISM_BEAT_KEEP
    }
