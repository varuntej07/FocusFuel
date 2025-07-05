function isMoreReputableSource(source1, source2) {
    // Tiered reputation system - higher score = more reputable
    const sourceRatings = {
        // Tier 1: Premium tech publications (Score: 10)
        'Ars Technica': 10,
        'IEEE Spectrum': 10,
        'MIT Technology Review': 10,
        'Nature': 10,
        'Science': 10,

        // Tier 2: Major tech news sites (Score: 9)
        'TechCrunch': 9,
        'The Verge': 9,
        'Wired': 9,
        'Engadget': 9,
        'AnandTech': 9,
        'Tom\'s Hardware': 9,

        // Tier 3: Mainstream news with strong tech coverage (Score: 8)
        'Reuters': 8,
        'AP': 8,
        'BBC': 8,
        'The New York Times': 8,
        'The Washington Post': 8,
        'The Guardian': 8,
        'NPR': 8,
        'PBS': 8,
        'Wall Street Journal': 8,
        'Financial Times': 8,

        // Tier 4: Business/tech publications (Score: 7)
        'Bloomberg': 7,
        'Forbes': 7,
        'Business Insider': 7,
        'Fast Company': 7,
        'Harvard Business Review': 7,
        'VentureBeat': 7,
        'ZDNet': 7,
        'PCMag': 7,

        // Tier 5: Popular tech sites (Score: 6)
        'CNN': 6,
        'CNET': 6,
        'TechRepublic': 6,
        'Computerworld': 6,
        'InformationWeek': 6,
        'PCWorld': 6,

        // Tier 6: Industry-specific sites (Score: 5)
        'TechTarget': 5,
        'DevClass': 5,
        'InfoWorld': 5,
        'eWeek': 5,
        'Network World': 5,

        // Tier 7: Newer/niche tech publications (Score: 4)
        'The Information': 4,
        'Protocol': 4,
        'Axios': 4,
        'Recode': 4,

        // Tier 8: Company blogs/official sources (Score: 3)
        'Google': 3,
        'Microsoft': 3,
        'Apple': 3,
        'Amazon': 3,
        'Meta': 3,
        'OpenAI': 3,

        // Default for unknown sources
        'Unknown': 1
    };

    // Get reputation scores (default to 1 if not found)
    const score1 = sourceRatings[source1] || 1;
    const score2 = sourceRatings[source2] || 1;

    return score1 > score2;
}

module.exports = { isMoreReputableSource };