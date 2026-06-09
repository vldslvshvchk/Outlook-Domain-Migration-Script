# Outlook Email Domain Migration Script

A PowerShell script for bulk Outlook profile migration after an email domain change.

The script updates Outlook profile settings for **all local Windows user profiles**, including profiles that are not currently logged in, by loading their `NTUSER.DAT` registry hives.

## Features

- Supports Outlook 2010, 2013, 2016, 2019, and Microsoft 365
- Processes all local user profiles on the computer
- Automatically loads and unloads offline user registry hives
- Updates both display names and internal Outlook account settings
- Handles both string and binary MAPI properties
- Works with custom Outlook profile names
- Requires no Outlook profile recreation

## What Gets Updated

The script replaces the old email domain with the new one in:

| Property | Description |
|-----------|-----------|
| Account Name | Outlook account name |
| Email | Email address |
| 001f6620 | SMTP address (Unicode) |
| 001e6620 | SMTP address (Binary/ANSI) |
| 001f3001 | Display name |

## Supported Registry Locations

The script scans the following Outlook profile locations:

```text
Windows Messaging Subsystem\Profiles
Office\14.0\Outlook\Profiles
Office\15.0\Outlook\Profiles
Office\16.0\Outlook\Profiles
```

## Requirements

- Windows 10 / 11
- Windows Server 2016 or newer
- PowerShell 5.1 or later
- Administrator privileges

## Usage

Edit the following variables at the beginning of the script:

```powershell
$oldDomain = "@olddomain.com"
$newDomain = "@newdomain.com"
```

Run PowerShell as Administrator and execute:

```powershell
.\Outlook-Domain-Migration.ps1
```

## Example

Before:

```text
user@olddomain.com
```

After:

```text
user@newdomain.com
```

## Notes

The script only updates Outlook profile settings.

It does **not** modify:

- Existing email messages
- Exchange Server configuration
- Microsoft 365 configuration
- Active Directory attributes
- Email aliases
- Mailbox settings

### Outlook Replies to Old Emails

After a domain migration, users may notice that when replying to older emails sent to the previous address, Outlook automatically includes the old address in the recipient list.

Example:

```text
user@olddomain.com
```

This behavior is caused by recipient information stored inside the original email message and is **not** related to the Outlook profile configuration.

New emails received on the new domain will not exhibit this behavior.

## Safety Recommendations

Before running in production:

1. Test on a small number of workstations.
2. Verify mailbox migration is complete.
3. Ensure Outlook is closed.
4. Create a backup of user profiles if required by your organization.

## License

MIT License

## Disclaimer

This script is provided as-is without warranty of any kind. Always test in a non-production environment before deploying at scale.
