# SQL Restore Automation via Webhook

This project demonstrates an **event-driven database restore pipeline** using PowerShell, Azure Blob Storage, SQL Server, and Microsoft Graph API.

## Features
- Webhook listener with secret validation
- Automated download of SQL backup from Azure Blob
- Full database restore with `Restore-SqlDatabase`
- Post-restore SQL script execution
- Email notification via Microsoft Graph API

## Repo Layout
- `src/listener.ps1` → main script
- `docs/` → documentation and diagrams

## Usage
1. Clone repo
2. Update Config
3. Run `listener.ps1`
