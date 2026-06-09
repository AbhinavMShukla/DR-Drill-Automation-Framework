# DR Drill Automation Framework

PowerShell-based Disaster Recovery (DR) Drill Automation Framework for lifecycle validation, dashboard generation, DNS verification, and audit-ready PDF reporting.

<img src="evidence/sample.jpg" width="800">
---

## Overview

DR Drill Automation Framework is a lab-based automation project designed to simulate and automate the reporting lifecycle of a Disaster Recovery (DR) exercise.

The framework processes DR lifecycle activities, validates operational checkpoints, generates executive dashboards, and produces consolidated closeout reports in HTML and PDF formats.

This project was developed for learning, automation design, and reporting standardization purposes using dummy infrastructure data.

---

## Key Features

- Pre-Drill validation tracking
- Failover execution reporting
- DNS verification and reconciliation
- Rollback execution validation
- Post-Rollback status verification
- Executive dashboard generation
- HTML report generation
- PDF report export
- Consolidated closeout reporting
- Audit-friendly documentation

---

## DR Lifecycle Coverage

```text
Pre-Drill
    ↓
Failover Execution
    ↓
Failover DNS Verification
    ↓
Rollback Execution
    ↓
Post-Rollback DNS Validation
    ↓
Master Closeout Report
```

---

## Architecture

```text
CSV Input Files
        ↓
PowerShell Processing Engine
        ↓
Validation & Reconciliation Logic
        ↓
Dashboard Generation
        ↓
HTML Reporting
        ↓
PDF Export
        ↓
Master Closeout Report
```

---

## Technologies Used

- PowerShell
- HTML
- CSS
- CSV Processing
- PDF Reporting
- Automation Framework Design

---

## Repository Structure

```text
DR-Drill-Automation-Framework
│
├── Scripts
│   └── Process_DR_Drill.ps1
│
├── Docs
│   ├── Technical_Design_Document.pdf
│   └── User_Guide.pdf
│
├── Sample-Input
│   └── Sample_DR_Data.csv
│
├── Sample-Output
│   ├── Dashboard.png
│   └── Closeout_Report.pdf
│
├── Images
│   └── Architecture.png
│
├── README.md
├── LICENSE
└── CHANGELOG.md
```

---

## Sample Outputs

### Executive Dashboard

_Add dashboard screenshot here_

### Closeout Report

_Add PDF report screenshot here_

### Lifecycle Summary

_Add lifecycle summary screenshot here_

---

## Business Value

This framework demonstrates how Disaster Recovery reporting activities can be automated to:

- Reduce manual effort
- Improve reporting consistency
- Increase audit readiness
- Standardize DR documentation
- Accelerate DR drill closeout activities

---

## Use Cases

- Disaster Recovery Exercises
- DR Validation Reporting
- DNS Verification Tracking
- Audit Documentation
- Operational Readiness Reviews
- Reporting Automation Demonstrations

---

## Future Enhancements

- Active Directory integration
- Live DNS validation
- Email notifications
- Historical trend analysis
- Multi-environment support
- Interactive dashboards

---

## Disclaimer

This project was created in a personal lab environment.

All server names, IP addresses, DNS records, hostnames, and infrastructure components used within the project are fictional and intended solely for educational, testing, and demonstration purposes.

No production or customer environments were used.

---

## Author

**Abhinav Shukla**

Server Administrator | PowerShell Automation Enthusiast | Wintel Infrastructure Professional

LinkedIn: https://www.linkedin.com/in/abhinavmshukla

GitHub: https://github.com/AbhinavMShukla

---

## Version

Current Release: **v1.1**

Initial Release Date: **June 2026**
