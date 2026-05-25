# OpenGov Salesforce Developer Assessment

End-to-end B2B Quote-to-Asset automation with a Customer Community, built on Salesforce CPQ.

Submitted by **Harshal Ramdham**

---

## 📋 Quick Start for Reviewers

| Want to... | Open this |
|---|---|
| 📐 See the schema & assumptions | [docs/OpenGov_Schema_Design.pdf](docs/OpenGov_Schema_Design.pdf) |
| 📘 Read the full design | [docs/OpenGov_Solution_Design_Document.pdf](docs/OpenGov_Solution_Design_Document.pdf) |
| 🌐 See the Community work | [docs/OpenGov_Community_Addendum.pdf](docs/OpenGov_Community_Addendum.pdf) |
| 🛠 Deploy the solution | [docs/COMMUNITY_DEPLOYMENT_GUIDE.md](docs/COMMUNITY_DEPLOYMENT_GUIDE.md) |
| 🚀 Deploy via CLI | `sf project deploy start -d force-app -o YOUR_ORG` |
| ✅ Run all tests | `sf apex test run -o YOUR_ORG --code-coverage` |

---

## 🎯 What This Solution Does

When a Sales Rep contracts a CPQ Quote:

1. **Record-Triggered Flow** creates Assets for every Hardware line item
2. **Apex Trigger** auto-creates a "Kickoff Service Onboarding" Task when an Asset is marked Installed
3. **Customer Community** lets the customer view their Assets, register Warranties, and track Service Requests — scoped to their own Account
4. **Errors are cleaned** by a reusable Invocable Apex method, surfaced as polished messages across Chatter, Flow, and LWC
5. **Real-time toast notifications** (enhancement) — a Platform Event + headless LWC give the rep an instant visual confirmation of asset creation outcomes, without waiting to check Chatter

📐 **See the [Entity Relationship Diagram](docs/erd.png) for the full data model.**

---

## 📁 Repository Structure

```
force-app/main/default/
├── classes/        Apex classes + tests
├── triggers/       3-line dispatcher triggers
├── objects/        Warranty_Registration__c (custom object + fields + validation rule), Asset_Creation_Result__e (Platform Event)
├── flows/          Quote-to-Asset Record-Triggered Flow
├── lwc/            4 Lightning Web Components for the Community
└── permissionsets/ Customer Portal Access

docs/               Design docs, deployment guide, ERD
```

📂 **[Browse the code](force-app/main/default/)** · 📂 **[Browse the docs](docs/)**

---

## 🏗 Architecture Highlights

- **Trigger Handler + Service Layer pattern** — Triggers are 3-line dispatchers; all logic lives in service classes
- **Bulkified** — [`AssetServiceTest`](force-app/main/default/classes/AssetServiceTest.cls) proves SOQL stays under 10 queries for 200 records
- **Cross-surface code reuse** — The same [`FlowErrorHandler`](force-app/main/default/classes/FlowErrorHandler.cls) cleans errors for Flow Chatter posts, Apex DML exceptions, and LWC modal banners
- **Layered validation** — Validation Rule (declarative) + CPQ Product Rule + Apex `addError()` for cross-record checks via [`WarrantyRegistrationTriggerHandler`](force-app/main/default/classes/WarrantyRegistrationTriggerHandler.cls)
- **Server-to-UI bridge via Platform Events** — Record-Triggered Flow publishes `Asset_Creation_Result__e`; headless LWC subscribed to the event channel dispatches a real-time toast on the Quote page
  
---

## 🔑 Key Files at a Glance

### Apex (Service Layer)
- [`TriggerHandler.cls`](force-app/main/default/classes/TriggerHandler.cls) — Abstract base for all trigger handlers
- [`AssetService.cls`](force-app/main/default/classes/AssetService.cls) — Bulkified service for Kickoff Task creation
- [`FlowErrorHandler.cls`](force-app/main/default/classes/FlowErrorHandler.cls) — Invocable cleaner reused across Flow + LWC
- [`CommunityPortalController.cls`](force-app/main/default/classes/CommunityPortalController.cls) — Account-scoped Apex for community LWCs
- [`WarrantyRegistrationTriggerHandler.cls`](force-app/main/default/classes/WarrantyRegistrationTriggerHandler.cls) — `addError()` for cross-record validations

### Lightning Web Components
- [`customerDashboard`](force-app/main/default/lwc/customerDashboard/) — KPI tiles
- [`customerAssets`](force-app/main/default/lwc/customerAssets/) — Asset datatable
- [`customerWarranties`](force-app/main/default/lwc/customerWarranties/) — Registration form (the addError showcase)
- [`customerServiceRequests`](force-app/main/default/lwc/customerServiceRequests/) — Task list
- - [`assetCreationToast`](force-app/main/default/lwc/assetCreationToast/) — Headless toast listener for `Asset_Creation_Result__e`

### Configuration
- [`Warranty_Registration__c`](force-app/main/default/objects/Warranty_Registration__c/) — Custom object metadata
- [`Quote_Contracted_Create_Assets`](force-app/main/default/flows/) — Record-Triggered Flow
- [`Customer_Portal_Access`](force-app/main/default/permissionsets/) — Permission Set

---

## 🛠 Manual Setup Steps

Some configuration is point-and-click and can't live in source control. See the **[Deployment Guide](docs/COMMUNITY_DEPLOYMENT_GUIDE.md)** for full click-paths.

1. Enable Digital Experiences and create the Community site
2. Create the CPQ Product Rule "Hardware Description Required"
3. Configure the Sharing Set for Asset, Warranty_Registration__c, and Task
4. Set Activity OWD External Access to "Controlled by Parent"
5. Assign the Permission Set to your Community User
6. Place the `assetCreationToast` LWC on the Quote Lightning Record Page (Lightning App Builder → drag onto page → Save & Activate)
   
---

## 🧪 Test Coverage

| Class | Tests | Coverage |
|---|---|---|
| [`FlowErrorHandler`](force-app/main/default/classes/FlowErrorHandlerTest.cls) | 9 | 97% |
| [`AssetService`](force-app/main/default/classes/AssetServiceTest.cls) | 5 | 92% |
| [`WarrantyRegistrationTriggerHandler`](force-app/main/default/classes/WarrantyRegistrationTriggerTest.cls) | 4 | 90% |
| [`CommunityPortalController`](force-app/main/default/classes/CommunityPortalControllerTest.cls) | 16 | 97% |

---

## 🚫 What's NOT Included (and Why)

- **Customer-facing Quote configurator** — Customers don't configure their own quotes; that's a sales rep workflow
- **Custom logging object** — Designed in Section 9.2 of the [design document](docs/OpenGov_Solution_Design_Document.pdf); uses `System.debug()` for assessment scope
- **CI/CD pipeline** — Documented in Section 9.3 of the [design document](docs/OpenGov_Solution_Design_Document.pdf); out of build scope

See the **Future State Recommendations** section of the [design document](docs/OpenGov_Solution_Design_Document.pdf) for the full roadmap.

---

---
 
## 🤖 Acknowledgement: How I Used AI Assistance
 
In the spirit of transparency and modern engineering practice, I want to be explicit about how AI tooling supported this assessment. **All code design, architectural decisions, schema choices, business logic, and the working implementation are mine.** AI was used in three specific support areas where it adds genuine value to engineering work:
 
### 1. Documentation drafting and editing
 
I used AI to help draft and polish the documentation deliverables — the Design Document, the Community Addendum, the Deployment Guide, and the Demo Script. The technical content, architectural decisions, schema design, and trade-off rationale in those documents are mine; AI helped translate my notes into well-structured, professional prose, suggested table-based formats for comparison sections, and caught grammar/clarity issues during editing passes. This is the same way I'd use a technical writer or editor on a real project — the substance is mine, the polish is collaborative.
 
### 2. Apex code commenting and documentation
 
After writing each Apex class, I used AI to help expand inline comments and JavaDoc-style class headers. The code logic, design patterns, and method signatures are mine; AI helped ensure every class had a consistent comment style explaining *why* not just *what*. For example, when I wrote `FlowErrorHandler` with its regex patterns, AI suggested adding rationale comments next to each regex explaining what kind of fault text it matches and why the order of operations matters. The patterns themselves and the cleaning logic are mine; the documentation around them is collaborative. This is the same workflow used by teams who run automated documentation generators against their codebase — the difference is I had a conversation about each comment rather than running a single-pass tool.
 
### 3. Test class scaffolding from working Apex
 
After my production Apex was working correctly, I used AI to help me scaffold the corresponding test classes. I described the scenarios I wanted to cover (happy path, edge cases, bulk behavior, security guards) and AI generated the initial test method skeletons with `@TestSetup` data and assertion structure. I then reviewed every test, adjusted assertions to match my exact business intent, added scenarios AI hadn't suggested, and debugged failures iteratively. The test strategy — what to assert, what scenarios matter, what counts as good coverage — is mine; AI accelerated the rote mechanical work of writing `System.assertEquals(...)` boilerplate. The bulkification test specifically (the one that asserts `Limits.getQueries() < 10`) was my own contribution; that's the kind of hard-numeric assertion AI doesn't typically suggest unprompted.
 
### What AI did NOT do
 
To be unambiguous: I personally designed, wrote, debugged, and own:
 
- The Apex business logic in `AssetService`, `WarrantyRegistrationTriggerHandler`, `CommunityPortalController`, and the trigger framework
- The regex patterns and cleaning logic in `FlowErrorHandler`
- The LWC components (HTML, JavaScript, and component composition)
- The Record-Triggered Flow design, including the Platform Event publishing strategy and the fault path architecture
- The custom object schema, sharing model decisions, and Master-Detail vs Lookup choices
- The Platform Event design (when to fire it, what fields it should carry, how the LWC subscriber processes it)
- All debugging — including the multi-day work to diagnose Community sharing issues, the Asset ContactId fix, and the Task `without sharing` helper
I include this section because I believe transparency about AI assistance is the professional norm now. Used well, AI accelerates the documentation and scaffolding work that engineers traditionally spend significant time on, letting more focus go to design decisions, debugging, and architecture. That's how I used it here.
 
---

## 📬 Contact

For questions about this submission, please reach out via the email address on my application.
