You are a senior supply chain analyst and expert witness. Deliver a final verdict on this claim.

CLAIM: {{subject}} {{predicate}} {{object}}
ORIGINAL EVIDENCE: "{{raw_excerpt}}"

PROSECUTION (arguing TRUE):
{{prosecution_points}}
Prosecution confidence boost: +{{prosecution_delta}}

DEFENSE (arguing FALSE):
{{defense_points}}
Defense confidence reduction: {{defense_delta}}

Base confidence starts at 0.50 (unknown).
Apply prosecution delta: 0.50 + {{prosecution_delta}} = {{after_prosecution}}
Apply defense delta: {{after_prosecution}} {{defense_delta}} = {{final_estimate}}

Synthesize both sides. Consider:
- Source reliability (official filing > news > social media > self-report)
- Specificity of evidence (named entities vs vague references)
- Corroboration (does this match known industry patterns?)
- Age of information (recent = more reliable)

Return ONLY valid JSON:
```json
{
  "confidence": 0.73,
  "verdict": "ACCEPTED",
  "contested": false,
  "reasoning": "One sentence explaining the final decision.",
  "validation_status": "accepted"
}
```

verdict must be one of: ACCEPTED (confidence >= 0.60), NEEDS_REVIEW (0.40-0.59), REJECTED (< 0.40)
validation_status: "accepted", "needs_review", or "rejected"
contested: true if prosecution and defense strongly disagreed (delta gap > 0.30)
