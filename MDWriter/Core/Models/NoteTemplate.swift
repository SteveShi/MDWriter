//
//  NoteTemplate.swift
//  MDWriter
//

import Foundation
import SwiftUI

/// Preset document templates for quick note initialization.
struct NoteTemplate: Identifiable, Sendable {
    let id: String
    let name: String
    let localizedNameKey: String
    let icon: String
    let defaultTitle: String
    let defaultContent: String

    var localizedKey: LocalizedStringKey {
        LocalizedStringKey(localizedNameKey)
    }

    static let allTemplates: [NoteTemplate] = [
        blank,
        meetingNotes,
        dailyLog,
        technicalRFC,
        weeklyReport,
        readingNotes
    ]

    static let blank = NoteTemplate(
        id: "blank",
        name: "Blank Note",
        localizedNameKey: "Blank Note",
        icon: "doc",
        defaultTitle: "New Note",
        defaultContent: ""
    )

    static let meetingNotes = NoteTemplate(
        id: "meeting_notes",
        name: "Meeting Notes",
        localizedNameKey: "Meeting Notes",
        icon: "person.2.fill",
        defaultTitle: "Meeting Notes",
        defaultContent: """
        # Meeting Notes

        **Date:** [Date]
        **Attendees:** @Name1, @Name2
        **Goal:** Align on ...

        ---

        ## 1. Agenda
        - Topic 1:
        - Topic 2:

        ## 2. Discussion Points
        - 

        ## 3. Decisions Made
        - [x] 

        ## 4. Action Items
        - [ ] Task 1 (Assignee: @Name, Due: YYYY-MM-DD)
        - [ ] Task 2
        """
    )

    static let dailyLog = NoteTemplate(
        id: "daily_log",
        name: "Daily Log",
        localizedNameKey: "Daily Log",
        icon: "calendar",
        defaultTitle: "Daily Log",
        defaultContent: """
        # Daily Log

        ## 🎯 Today's Focus (Top 3)
        1. 
        2. 
        3. 

        ## 📝 Work & Progress
        - 

        ## 💡 Insights & Reflections
        - 

        ## ⏳ Tomorrow's Plan
        - [ ] 
        """
    )

    static let technicalRFC = NoteTemplate(
        id: "technical_rfc",
        name: "Technical RFC / Design",
        localizedNameKey: "Technical RFC / Design",
        icon: "hammer.fill",
        defaultTitle: "RFC: [Project / Feature Name]",
        defaultContent: """
        # RFC: [Project / Feature Title]

        - **Author:** [Author Name]
        - **Status:** Draft / Review / Approved

        ---

        ## 1. Background & Problem Statement
        Why are we doing this? What problem are we trying to solve?

        ## 2. Proposed Architecture & Design
        Detailed architecture, data flow, models, and interfaces.

        ```swift
        // Core interfaces or data models
        ```

        ## 3. Alternative Approaches Considered
        - **Option A:** Pros / Cons
        - **Option B:**

        ## 4. Risks & Migration Plan
        - Potential breaking changes:
        - Rollout steps:
        """
    )

    static let weeklyReport = NoteTemplate(
        id: "weekly_report",
        name: "Weekly Summary",
        localizedNameKey: "Weekly Summary",
        icon: "chart.bar.doc.horizontal",
        defaultTitle: "Weekly Summary",
        defaultContent: """
        # Weekly Summary

        ## 🚀 Accomplishments This Week
        - 

        ## 📊 Key Metrics & Outcomes
        - 

        ## 🚧 Challenges & Blockers
        - 

        ## 🎯 Priorities for Next Week
        - [ ] 
        """
    )

    static let readingNotes = NoteTemplate(
        id: "reading_notes",
        name: "Reading Notes",
        localizedNameKey: "Reading Notes",
        icon: "book.fill",
        defaultTitle: "Reading Notes: [Book Title]",
        defaultContent: """
        # Reading Notes: [Book / Paper Title]

        - **Author:** [Author]
        - **Rating:** ⭐️⭐️⭐️⭐️⭐️
        - **Key Takeaway:** One-sentence summary.

        ---

        ## 💡 Core Ideas & Frameworks
        - 

        ## 📖 Notable Quotes
        > 

        ## 🧠 Personal Reflections & Actions
        - 
        """
    )
}
