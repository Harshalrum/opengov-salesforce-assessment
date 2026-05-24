# OpenGov Salesforce Developer Assessment

End-to-end B2B Quote-to-Asset automation with a Customer Community, built on Salesforce CPQ.

Submitted by **Harshal Ramdham**

---

## 📋 Quick Start for Reviewers

| Want to... | Open this |
|---|---|
| 🎥 Watch a 3-min walkthrough | [Loom Video](https://www.loom.com/YOUR-LINK-HERE) |
| 📐 See the schema & assumptions | [docs/OpenGov_Schema_Design.pdf](docs/OpenGov_Schema_Design.pdf) |
| 📘 Read the full design | [docs/OpenGov_Solution_Design_Document.pdf](docs/OpenGov_Solution_Design_Document.pdf) |
| 🌐 See the Community work | [docs/OpenGov_Community_Addendum.pdf](docs/OpenGov_Community_Addendum.pdf) |
| 🛠 Deploy the solution | [docs/COMMUNITY_DEPLOYMENT_GUIDE.md](docs/COMMUNITY_DEPLOYMENT_GUIDE.md) |
| 🎬 Follow the demo flow | [docs/DEMO_SCRIPT.md](docs/DEMO_SCRIPT.md) |
| 🚀 Deploy via CLI | `sf project deploy start -d force-app -o YOUR_ORG` |
| ✅ Run all tests | `sf apex test run -o YOUR_ORG --code-coverage` |

---

## 🎯 What This Solution Does

When a Sales Rep contracts a CPQ Quote:

1. **Record-Triggered Flow** creates Assets for every Hardware line item
2. **Apex Trigger** auto-creates a "Kickoff Service Onboarding" Task when an Asset is marked Installed
3. **Customer Community** lets the customer view their Assets, register Warranties, and track Service Requests — scoped to their own Account
4. **Errors are cleaned** by a reusable Invocable Apex method, surfaced as polished messages across Chatter, Flow, and LWC

📐 **See the [Entity Relationship Diagram](docs/erd.png) for the full data model.**

---

## 📁 Repository Structure

```
force-app/main/default/
├── classes/        Apex classes + tests
├── triggers/       3-line dispatcher triggers
├── objects/        Warranty_Registration__c (custom object + fields + validation rule)
├── flows/          Quote-to-Asset Record-Triggered Flow
├── lwc/            4 Lightning Web Components for the Community
└── permissionsets/ Community Warranty Access

docs/               Design docs, deployment guide, demo script, ERD
```

📂 **[Browse the code](force-app/main/default/)** · 📂 **[Browse the docs](docs/)**

---

## 🏗 Architecture Highlights

- **Trigger Handler + Service Layer pattern** — Triggers are 3-line dispatchers; all logic lives in service classes
- **Bulkified** — [`AssetServiceTest`](force-app/main/default/classes/AssetServiceTest.cls) proves SOQL stays under 10 queries for 200 records
- **Cross-surface code reuse** — The same [`FlowErrorHandler`](force-app/main/default/classes/FlowErrorHandler.cls) cleans errors for Flow Chatter posts, Apex DML exceptions, and LWC modal banners
- **Layered validation** — Validation Rule (declarative) + CPQ Product Rule + Apex `addError()` for cross-record checks via [`WarrantyRegistrationTriggerHandler`](force-app/main/default/classes/WarrantyRegistrationTriggerHandler.cls)

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
- **Custom logging object** — Designed in §9.2 of the [design document](docs/OpenGov_Solution_Design_Document.pdf); uses `System.debug()` for assessment scope
- **CI/CD pipeline** — Documented in §9.3 of the [design document](docs/OpenGov_Solution_Design_Document.pdf); out of build scope

See the **Future State Recommendations** section of the [design document](docs/OpenGov_Solution_Design_Document.pdf) for the full roadmap.

---

## 📬 Contact

For questions about this submission, please reach out via the email address on my application.
