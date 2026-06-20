You are a supply chain analyst. Extract supply chain relationships from the text below.

Company under investigation: {{company}}
Source URL: {{source_url}}

TEXT:
{{text}}

Return ONLY valid JSON, no other text. Extract every supplier, manufacturer, partner, or sourcing relationship mentioned.

```json
[
  {
    "subject": "Company A",
    "predicate": "SUPPLIES",
    "object": "Company B",
    "subject_country": "NL",
    "object_country": "CN",
    "raw_excerpt": "exact quote from text supporting this relationship"
  }
]
```

Predicate must be one of: SUPPLIES, MANUFACTURES, SOURCES_FROM, OWNS, PARTNERS_WITH, SHIPS_TO
If no relationships found, return empty array: []
Only include relationships where at least one entity is {{company}} or a direct supplier/customer of {{company}}.
