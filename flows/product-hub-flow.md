# Product Hub — Lifecycle Flows

> Auto-updated as requirements are defined. Each section covers a lifecycle stage with decision points and persona actions.

---

## 1. Register & Login

```mermaid
flowchart TD
    A([User visits Product Hub]) --> B{Email domain\nwhitelisted?}
    B -- No --> C[Show: Access Restricted\nContact your Admin]
    B -- Yes --> D[Send OTP to email]
    D --> E{OTP valid?}
    E -- No / Expired --> D
    E -- Yes --> F{First time\nregistering?}
    F -- Yes --> G[Profile Setup\nFull Name · Alias · Role · Department · Avatar]
    G --> H[Auto-generate Avatar via LLM Image API]
    H --> I{Admin account?}
    F -- No --> I
    I -- Yes --> J[Hardcoded password fallback available]
    I -- No --> K[Land on Dashboard — Read-only state]
    J --> K
    K --> L{Assigned to\na Group?}
    L -- No --> M[All pages visible but blank\nRequest Access button on each page]
    L -- Yes --> N[Access granted per Group permissions]
    M --> O[Submit Access Request + Reason]
    O --> P[Admin reviews & assigns to Group]
    P --> N

    style C fill:#fee2e2,stroke:#ef4444,color:#000
    style N fill:#dcfce7,stroke:#22c55e,color:#000
    style M fill:#fef9c3,stroke:#eab308,color:#000
```

---

## 2. Submission & PRD Builder

```mermaid
flowchart TD
    A([Authenticated User]) --> B[Select Request Type\nNew Idea · Change Request · Bug]
    B --> C[Fill in: Title · Brief · Attachment]
    C --> D[Saved as v1\nStatus: Request Review]
    D --> E[PRD Builder opens — 3-panel workspace]

    subgraph PRD_BUILDER["PRD Builder Workspace"]
        direction LR
        F[Left Panel\nOriginal Request v1\nEditable Brief] 
        G[Middle Panel\nLLM PRD Generator Agent\nSpecKit + Custom Skills]
        H[Right Panel\nWorking Folder\nLive PRD Artifact]
        F <--> G
        G --> H
    end

    E --> PRD_BUILDER

    G --> I{Agent asks\nclarifying questions\nCustom Skills}
    I --> J[Requestor answers\nin conversation]
    J --> K{Submission Score\npassing?}

    K -- No --> L[Agent highlights\nfailing sections]
    L --> J

    K -- Yes --> M{Requestor\nhappy with PRD?}
    M -- No --> J
    M -- Yes --> N[Finalise Submission]
    N --> O[Status: Submitted\nVersion locked]
    O --> P[Requestor receives\nRequest Tracking Link]

    style O fill:#dcfce7,stroke:#22c55e,color:#000
    style L fill:#fee2e2,stroke:#ef4444,color:#000
```

---

## 3. Product Processing & Evaluation

```mermaid
flowchart TD
    A([PRD in Review Queue]) --> B[Any PM or Head of Product\nperforms initial evaluation]
    B --> C[Scorecard completed\n+ Written Rationale]
    C --> D{Decision}

    D -- Reject --> E[Status: Rejected\nRequestor notified\nwith rationale]
    D -- Request Revisions --> F[Status: Revisions Requested\nReturns to PRD Builder\nwith reviewer comments]
    F --> G([Requestor iterates in PRD Builder])

    D -- Approve --> H{Single or\nmulti-domain impact?}

    H -- Single Domain --> I[Assign to Domain PM\nStatus: In Research]
    H -- Multi-Domain --> J[Split into Streams\nOne per affected domain]
    J --> K[Each stream assigned\nto its Domain PM]
    K --> L[Streams visible together\non Requestor tracking link]
    I --> M([Proceed to Research & Analysis])
    L --> M

    style E fill:#fee2e2,stroke:#ef4444,color:#000
    style F fill:#fef9c3,stroke:#eab308,color:#000
    style I fill:#dcfce7,stroke:#22c55e,color:#000
    style K fill:#dcfce7,stroke:#22c55e,color:#000
```

---

## Request Status State Machine

```mermaid
stateDiagram-v2
    [*] --> Draft : Requestor starts submission
    Draft --> RequestReview : Submission finalised + score passes
    RequestReview --> InRevision : Reviewer requests changes
    InRevision --> RequestReview : Requestor resubmits
    RequestReview --> Rejected : Reviewer rejects
    RequestReview --> InResearch : Reviewer approves + assigns domain
    InResearch --> RICEScoring : Research complete
    RICEScoring --> InBacklog : RICE scored
    InBacklog --> OnRoadmap : Prioritised onto roadmap
    OnRoadmap --> InHandover : Tech handover assembled
    InHandover --> InDevelopment : Handed to engineering
    InDevelopment --> ReadyForUAT : Engineering marks ready
    ReadyForUAT --> UATInProgress : UAT begins
    UATInProgress --> ReadyForRelease : UAT passed
    UATInProgress --> InDevelopment : UAT failed — back to engineering
    ReadyForRelease --> Released : Release notes published
    Released --> [*]
    Rejected --> [*]
```
