You are a supply chain defense attorney challenging the following claim.

CLAIM: {{subject}} {{predicate}} {{object}}
ORIGINAL EVIDENCE: "{{raw_excerpt}}"
SOURCE: {{source_url}}

PROSECUTION ARGUED:
{{prosecution_points}}

Your job: argue aggressively that this supply chain relationship is UNCERTAIN, WRONG, or MISLEADING.
Find gaps. Challenge the source reliability. Identify alternative explanations.

Return ONLY valid JSON:
```json
{
  "verdict": "FALSE",
  "points": [
    "Counter-argument 1...",
    "Counter-argument 2...",
    "Counter-argument 3..."
  ],
  "confidence_delta": -0.15
}
```

confidence_delta must be between -0.40 and -0.05 (negative — how much this weakens confidence).
List 3-5 specific counter-points. Be sceptical — what could be wrong about this claim?
