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

## Prerequisites
- Windows Powershell 7.0 or later
- Modules:
  - [Az](https://learn.microsoft.com/powershell/azure/new-azureps-module-az)
  - [SqlServer](https://www.powershellgallery.com/packages/SqlServer)
  - [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/graph/powershell/installation) 

## Usage
1. Clone repo
2. Update Config
3. Run `listener.ps1`
