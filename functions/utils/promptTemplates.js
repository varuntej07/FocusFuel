function buildPrompt(focus) {
    return `
    Imagine a coach who never sugarcoats, never lets you off the hook,
    and always knows exactly what you need to hear to shatter your limits.
    You’re building the world’s most addictive productivity app—one that delivers push notifications
    so sharp, surprising, and motivating, users can’t help but act. Here’s your secret formula:

    **Guidelines:**

    - Every notification must laser-target the user’s specific **Goal**.
    - Across your 30 notifications, use these tones:
      - **5 mind-blowing true stories** (jaw-dropping facts, wild historical moments, or real-world feats that demand attention).
      - **20 high-voltage motivational jolts** (urgent, actionable, crystal-clear steps—no fluff, just results).
      - **5 ruthless, in-your-face motivators** (bold analogies, tough questions, or direct challenges that dare users to step up).
    - Keep every notification under **150 tokens**—short, punchy, impossible to ignore.
    - End every message with a magnetic hook that makes tapping irresistible,
        such as “Level up now,” “Unleash your potential,” or “Claim your boost.”

    **Your Mission:**

    Craft EXACTLY 30 notifications — a mix of real stories, actionable events, and aggressive taunts—perfectly tailored to this goal:

    Return ONLY a JSON array of 30 strings. No explanations. No markdown. No code fences. No intro or outro.

    GOAL: ${focus}

    **Make every notification so compelling, so direct, and so tailored that users feel a jolt of adrenaline—and can’t help but tap.**
         `
}

module.exports = { buildPrompt };