# OpenGov Customer Community — Deployment Guide

Step-by-step setup for the Customer Community layer on top of the deployed Apex and metadata. Allow ~3 hours end-to-end.

---

## Phase 1 — Enable Experience Cloud

Setup → Digital Experiences → Settings → check **Enable Digital Experiences** → pick a unique domain → Save. Wait ~2 minutes for provisioning.

---

## Phase 2 — Deploy Apex & LWC

```bash
sf project deploy start -d force-app -o DEVORG
sf apex test run -o DEVORG --code-coverage --result-format human --wait 10
```

Verify all tests pass and coverage is >75%.

---

## Phase 3 — Create the Community Site

1. Setup → All Sites → **New**
2. Template: **Customer Service**
3. Name: `Customer Hub`, URL: `customerhub`
4. Wait ~1 minute for provisioning

---

## Phase 4 — Create the Customer User

1. **Contact** on your demo Account:
   - First/Last Name, Email (valid), Account = Customer Account
2. On Contact → Actions menu → **Enable Customer User**
3. User form:
   - Profile: **Customer Community Plus User**
   - Username, Alias, Nickname filled
   - Locale: English (US), TimeZone, EmailEncoding: UTF-8
   - Check "Generate password and notify user"
   - Save

Save the credentials emailed to you — you'll log in as this user.

---

## Phase 5 — Permission Set: "Community Portal Access"

Setup → Permission Sets → **New**
- Label: `Community Portal Access`
- License: **Customer Community Plus**
- Save

Open the new Permission Set → **Object Settings**:

| Object | Permissions | Field-Level Security |
|---|---|---|
| Warranty Registrations | Read, Create, Edit | All 5 fields: Read + Edit |
| Asset | Read | Read on Name, Status, AccountId, ContactId, Product2Id, Quantity, Price, PurchaseDate |
| Task | Read | Read on Subject, Status, Priority, ActivityDate, Description, OwnerId, WhatId |
| Account | Read | Read on Name |

Then **Apex Class Access** → enable:
- `CommunityPortalController`
- `FlowErrorHandler`

Then assign the Permission Set to your Demo Customer user (User detail page → Permission Set Assignments → Edit).

---

## Phase 6 — Sharing Model

### Activity OWD (critical for Tasks)

Setup → Sharing Settings → find Activity → Edit
- **Default External Access**: `Controlled by Parent`
- Save

### Sharing Set

Setup → Digital Experiences → All Sites → Workspaces → Administration → Sharing Settings → **Sharing Sets** → New

| Object | User Field | Target |
|---|---|---|
| Account | Contact.Account | Account.Id |
| Asset | Contact.Account | AccountId |
| Warranty_Registration__c | Contact.Account | Account |
| Task | Contact.Account | What (Account) |

Save. Wait 1-2 minutes for recalculation.

---

## Phase 7 — Build the Community Pages

In Experience Builder, add four pages:

1. **Home** — drag `customerDashboard` component
2. **My Assets** — new standard page; drag `customerAssets`
3. **My Warranties** — new standard page; drag `customerWarranties`
4. **My Service Requests** — new standard page; drag `customerServiceRequests`

Configure the navigation menu (top-left settings):
- Home → /
- My Assets → /my-assets
- My Warranties → /my-warranties
- My Service Requests → /my-service-requests

Publish each page. Then **Publish** the site (top-right of Builder), then Activate (Setup → All Sites).

---

## Phase 8 — CPQ Product Rule (Hardware Description Required)

App Launcher → Product Rules → New
- Name: `Hardware Description Required`
- Type: Validation, Scope: Quote, Active

Save, then add **Error Conditions**:
- Quote Line · SBQQ__ProductFamily__c equals `Hardware`
- Quote Line · SBQQ__Description__c equals (blank)

Set Error Message: *"Hardware products require a description before the Quote can be saved."*

Associate with the Hardware Product via the Product → Rules tab.

---

## Phase 9 — Test in Incognito

1. Fresh incognito window → community URL → login as Demo Customer
2. **Home**: KPI tiles populated with your account's numbers
3. **My Assets**: assets listed (run the happy path first if list is empty)
4. **My Warranties**: click Register New Warranty → pick asset → submit → success toast appears
5. **My Warranties (again)**: try to register a duplicate Active warranty → red banner with cleaned addError message
6. **My Service Requests**: Kickoff Service Onboarding task visible

---

## Troubleshooting

| Symptom | Most Likely Cause |
|---|---|
| Empty "My Assets" page even though assets exist | Sharing Set missing for Asset, OR Asset.ContactId is null. |
| `INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY` on warranty save | Permission Set missing Warranty Read/Create, OR Asset.ContactId is null. |
| Empty "My Service Requests" page | Activity OWD External Access not set to Controlled by Parent, OR Task Read missing on Permission Set. |
| Warranty form rejects with "Please select an asset" | HTML/JS field-name mismatch — should be fixed; if recurring, check browser console. |
| Component doesn't appear in Experience Builder | `.js-meta.xml` missing `lightningCommunity__Page` and `lightningCommunity__Default` in targets. |
| Cleaned error still shows "FIELD_CUSTOM_VALIDATION_EXCEPTION" | FlowErrorHandler not in Permission Set's Apex Class Access. |

---

## What to Capture for the Demo

Before the panel session, take screenshots of:
- Dashboard with KPIs
- My Assets datatable populated
- Warranty registration form (filled)
- Warranty registration form with red banner showing cleaned addError message ← **the money shot**
- My Service Requests with auto-created task
- Apex Test Execution results showing >75% coverage
