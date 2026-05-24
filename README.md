# OpenGov Salesforce Developer Assessment

End-to-end B2B Quote-to-Asset automation with a Customer Community, built on Salesforce CPQ.

Submitted by **[Your Name]** · [Submission Date]

---

## Quick Start for Reviewers

| Want to... | Open this |
|---|---|
| Watch a 3-min walkthrough | [Loom link here] |
| Read the design | `docs/OpenGov_Solution_Design_Document.pdf` |
| See the Community work | `docs/OpenGov_Community_Addendum.pdf` |
| Deploy to your org | `sf project deploy start -d force-app -o YOUR_ORG` |
| Run all tests | `sf apex test run -o YOUR_ORG --code-coverage` |

---

## What This Solution Does

When a Sales Rep contracts a CPQ Quote:

1. **Record-Triggered Flow** creates Assets for every Hardware line item
2. **Apex Trigger** auto-creates a "Kickoff Service Onboarding" Task when an Asset is set to Installed
3. **Customer Community** lets the customer view their Assets, register Warranties, and track Service Requests — all scoped to their own Account
4. **Errors are cleaned** by a reusable Invocable Apex method, surfaced to the user as polished messages across Chatter, Flow, and LWC

---

## Repository Structure

```
force-app/main/default/
├── classes/        Apex classes + tests
├── triggers/       3-line dispatcher triggers
├── objects/        Warranty_Registration__c (custom object + fields + validation rule)
├── flows/          Quote-to-Asset Record-Triggered Flow
└── lwc/            4 Lightning Web Components for the Community

docs/               Design docs, deployment guide, demo script, screenshots
```

---

## Architecture Highlights

- **Trigger Handler + Service Layer pattern** — Triggers are 3-line dispatchers; all logic lives in service classes
- **Bulkified** — `AssetServiceTest` proves SOQL stays under 10 queries for 200 records
- **Cross-surface code reuse** — The same `FlowErrorHandler` cleans errors for Flow Chatter posts, Apex DML exceptions, and LWC modal banners
- **Layered validation** — Validation Rule (declarative) + CPQ Product Rule + Apex `addError()` for cross-record checks

---

## Manual Setup Steps

Some configuration is point-and-click and can't live in source control. See `docs/COMMUNITY_DEPLOYMENT_GUIDE.md` for full click-paths.

1. Enable Digital Experiences and create the Community site
2. Create the CPQ Product Rule "Hardware Description Required"
3. Create the Permission Set "Community Warranty Access"
4. Configure the Sharing Set for Asset, Warranty_Registration__c, and Task
5. Set Activity OWD External Access to "Controlled by Parent"

---

## Test Coverage

| Class | Tests | Coverage |
|---|---|---|
| FlowErrorHandler | 9 | XX% |
| AssetService | 5 | XX% |
| WarrantyRegistrationTriggerHandler | 4 | XX% |
| CommunityPortalController | 16 | XX% |

---

## What's NOT Included (and Why)

- **Customer-facing Quote configurator** — Customers don't configure their own quotes; that's a sales rep workflow
- **Custom logging object** — Designed in §11.2 of the design doc; uses `System.debug()` for assessment scope
- **CI/CD pipeline** — Documented in §11.3 of the design doc; out of build scope

See the **Future State Recommendations** section of the design document for the full roadmap.