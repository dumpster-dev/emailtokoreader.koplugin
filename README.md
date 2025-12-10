# Email to KOReader

Automatically download ebook attachments from your email directly to your KOReader device.

---

## Version
**2.0.0**  
[View Changelog](CHANGELOG.md)

---

## Features

- 📧 **Email Integration** — Fetch ebook attachments directly from your inbox
- 📚 **Multiple Formats Supported** — EPUB, PDF, MOBI, AZW3, FB2, DJVU, CBZ, TXT, and more
- 📁 **Multi-file Downloads** — Handle multiple attachments per email
- 📬 **Process 10 Emails** — Check up to 10 unread emails per run (newest first)
- 📏 **5MB Attachment Limit** — Automatic skip for oversized files with notification
- 🔍 **Email Filtering** — Filter by recipient address (e.g., `your-mail+koreader@gmail.com`)
- 🔄 **Auto-refresh** — Updates file browser automatically after download
- ⚙️ **In-App Configuration** — No manual file editing required
- 🐛 **Debug Mode** — Optional detailed logging for troubleshooting
- 🔐 **Gmail Support** — Works with Gmail app passwords

---

## Supported Formats*

| Category | Extensions |
|----------|------------|
| **Ebooks** | EPUB, MOBI, AZW, AZW3, FB2, PDB, PRC |
| **Documents** | PDF, DJVU, DOC, DOCX, RTF, TXT |
| **Comics** | CBZ |
| **Web** | HTML, HTM, CHM |

[*] Yet to test all the formats. Feel free to test and report any issues.

---

## Documentation

- [Installation Guide](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Size limit](#size-limits)
- [Changelog](CHANGELOG.md)

---

## Installation

### Step 1: Download the Plugin

Download the latest release from the [Releases page](https://github.com/dumpster-dev/emailtokoreader.koplugin/releases) or clone this repository. 

### Step 2: Copy to KOReader Plugins Folder

Copy the entire `emailtokoreader.koplugin` folder to your device's KOReader plugins directory: 

| Device | Path |
|--------|------|
| **Kindle** | `/mnt/us/koreader/plugins/` |
| **Kobo** | `/.adds/koreader/plugins/` |
| **Android** | `/sdcard/koreader/plugins/` |
| **PocketBook** | `/applications/koreader/plugins/` |
| **reMarkable** | `~/.local/share/koreader/plugins/` |

### Step 3: Restart KOReader

Close and reopen KOReader.  The plugin will appear in **Tools → Email to KOReader**. 

### Folder Structure

After installation, your plugins folder should look like: 
```
plugins/
└── emailtokoreader.koplugin/
    ├── manifest.lua
    ├── main.lua
    ├── config.lua
    ├── CHANGELOG.md
    ├── README.md
    └── LICENSE
```

---

## Configuration

### Step 1: Get Gmail App Password

> ⚠️ **Important**:  You cannot use your regular Gmail password. You must create an App Password.

1. Go to your [Google Account Security Settings](https://myaccount.google.com/security)
2.  Ensure **2-Step Verification** is enabled
3. Go to [App Passwords](https://myaccount.google.com/apppasswords)
4. App name:  KOreader
5. Click **Create**
6. Note the 16-character password (e.g., `abcd efgh ijkl mnop`)

### Step 2: Configure the Plugin

1. Open KOReader
2. Go to **Tools → Email to KOReader → Configure Settings**
3. Fill in the fields: 

| Field | Value |
|-------|-------|
| **Email Address** | `your-email@gmail.com` |
| **App Password** | The 16-character password from Step 1 |
| **IMAP Server** | `imap.gmail.com` (default) |
| **IMAP Port** | `993` (default) |
| **Download Path** | Where to save files (e.g., `/mnt/us/documents/`) |
| **Allowed Email** | Optional filter (e.g., `your-email+koreader@gmail. com`) |

4.  Tap **Save**

### Step 3: Test Connection

Go to **Tools → Email to KOReader → Test Connection** to verify your settings.

### Other Email Providers

| Provider | IMAP Server | Port |
|----------|-------------|------|
| Gmail | `imap.gmail.com` | 993 |
| Outlook/Hotmail | `outlook.office365.com` | 993 |
| Yahoo | `imap.mail.yahoo.com` | 993 |
| iCloud | `imap.mail.me.com` | 993 |
| ProtonMail | Requires ProtonMail Bridge | 1143 |

> Note: Other providers may also require app-specific passwords. 

---

## Usage

### Sending Books to Your Device

1. **Compose an email** to yourself (or to your filtered address)
2. **Attach** your ebook file(s) — up to 5MB each
3. **Send** the email

### Downloading Books

1. Open KOReader
2. Go to **Tools → Email to KOReader → Check Inbox**
3. Wait for the download to complete (usually 2-3 minutes)
4. Your files appear in the configured download folder

### Email Filtering (Recommended)

Use Gmail's plus-addressing to filter which emails the plugin processes:

1. Set **Allowed Email** to: `your-email+koreader@gmail.com`
2. Send books to: `your-email+koreader@gmail.com`

This way: 
- ✅ Emails to `your-email+koreader@gmail.com` are processed
- ❌ Other emails are skipped
- All emails still arrive in your regular inbox

**Why 5MB?** - Processing time is too high for large attachments and the allm crashes.

### Result Messages

After checking inbox, you'll see: 

```
Downloaded 2 file(s):
- My_Book.epub
- Another_Book.pdf

(3 skipped by filter)
(1 skipped:  >5MB)
```

---

## Troubleshooting

### Enable Debug Mode

1. Go to **Tools → Email to KOReader → Toggle Debug Mode**
2. Run **Check Inbox** again
3. Check your download folder for `debug_*.txt` files
4. These files contain the raw email headers for diagnosis

### Common Issues

#### "Login failed"
- ❌ **Wrong password**: Use Gmail App Password, NOT your regular password
- ❌ **2FA not enabled**: App Passwords require 2-Step Verification
- ❌ **IMAP disabled**: Enable IMAP in Gmail Settings → See all settings → Forwarding and POP/IMAP

#### "No new files found"
- ❌ **Email already read**: Only unread emails are processed
- ❌ **Wrong filter**: Check your "Allowed Email" setting matches the To:  address
- ❌ **Unsupported format**: Only supported file types are downloaded
- ❌ **No attachment**: Email must have file attachments

#### "Connection failed" / "Timeout"
- ❌ **No internet**:  Ensure WiFi is connected
- ❌ **Wrong server**:  Verify IMAP server address
- ❌ **Firewall**: Some networks block IMAP ports

#### "File too large"
- ❌ **Over 5MB**: Attachments must be under 5MB
- 💡 **Solution**: Compress the file or use a different transfer method

#### Files Not Appearing
- Check the **Download Path** in settings
- Go to **Tools → Email to KOReader → View Download Path** to see where files are saved
- Manually navigate to that folder in the file browser

### Reset Configuration

If settings are corrupted, delete the config file:
- Location: `plugins/emailtokoreader.koplugin/config.lua`
- Delete this file and restart KOReader
- Reconfigure your settings

---

## Size Limits

| Limit | Value |
|-------|-------|
| **Max attachment size** | 5MB |
| **Max emails per check** | 10 |
| **Max base64 size** | ~7MB |

Emails with attachments over 5MB are automatically skipped and reported in the results.
---

## ⚠️ Filename Recommendations

For best compatibility, use **simple filenames**:

| ✅ Do | ❌ Don't |
|-------|----------|
| `My_Book.epub` | `My Book:  A "Story".epub` |
| `Author-Title.pdf` | `Книга—Автор.pdf` |
| ASCII characters | Special characters, emojis |

---

## Troubleshooting

### Enable Debug Mode
1. **Tools → Email to KOReader → Toggle Debug Mode**
2. Run **Check Inbox**
3. Check download folder for `debug_*.txt` files

### Common Issues

| Problem | Solution |
|---------|----------|
| Login failed | Use Gmail App Password, not regular password |
| No files found | Check email is unread; verify recipient filter |
| File too large | Attachments must be under 5MB |

## License

MIT License - See [LICENSE](LICENSE) file

---

## Credits

V2.0.0 author: **dumpster-dev**  
Original author: **marinov752**