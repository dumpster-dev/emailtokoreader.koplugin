# Changelog

All notable changes to the Email to KOReader plugin will be documented in this file.

## [2.0.0] - 2025-12-10

### Added
- **Size limit enforcement**:  Attachments larger than 5MB are automatically skipped with notification
- **Size skip reporting**: Shows count of emails skipped due to size limit in results
- **Pre-flight size check**: Checks attachment size before downloading to save time and bandwidth
- **Expanded format support**: Added FB2, DJVU, DOC, DOCX, RTF, HTML, HTM, CHM, PDB, PRC (test pending)
- **Header unfolding**: Full RFC 2822 compliant header parsing for multi-line headers
- **Improved filename decoding**: Handles RFC 2047 encoded filenames split across multiple lines
- **Email recipient filtering**: Filter emails by To/CC address (e.g., `your-email+koreader@gmail.com`)
- **Debug file size limiting**: Debug files capped at 100KB to prevent storage issues
- **Process up to 10 emails**:  Increased from 3 to 10 unread emails per check (newest first)

### Fixed
- **Critical**: Fixed parsing of multi-line MIME headers (filenames split across lines with tabs)
- **Critical**: Fixed RFC 2047 encoded-word concatenation (adjacent encoded words now properly joined)
- **Critical**: Fixed IMAP FETCH response parsing (properly skips protocol wrapper lines)
- Trailing parenthesis removal from IMAP responses
- Filename extraction from Content-Type and Content-Disposition headers
- Boundary detection in nested multipart messages
- Nested MIME boundary handling for complex email structures
- Attachment detection in emails with multiple MIME parts

### Changed
- Version bumped to 2.0.0
- Maximum attachment size:  **5MB** (increased from 3.5MB, with proper enforcement)
- Socket timeout increased to 30 seconds for reliability
- Improved logging throughout for easier debugging
- Results now show separate counts for filter skips and size skips
- Processes newest emails first (reversed order)

---

## Supported Formats (v2.0.0)

| Category | Extensions |
|----------|------------|
| **Ebooks** | EPUB, MOBI, AZW, AZW3, FB2, PDB, PRC |
| **Documents** | PDF, DJVU, DOC, DOCX, RTF, TXT |
| **Comics** | CBZ |
| **Web** | HTML, HTM, CHM |

## Size Limits

- **Maximum attachment size: 5MB**
- Emails with larger attachments are skipped and reported in results

---

## Important:  Attachment Filenames

For best compatibility, **keep attachment filenames simple**:

### ✅ Recommended
- Use ASCII characters only (A-Z, a-z, 0-9)
- Use underscores `_` or hyphens `-` instead of spaces
- Keep filenames short (under 100 characters)
- Example: `My_Book_Title.epub`

### ❌ Avoid
- Special characters: `< > : " / \ | ?  *`
- Non-ASCII characters (accented letters, Cyrillic, Chinese, etc.)
- Very long filenames
- Emojis or special Unicode symbols

---

## [1.1.1] - Previous

### Features
- Basic IMAP/SSL connection to Gmail
- Download EPUB attachments from email
- Multi-file downloads per email
- Up to 3 unread emails per check
- File support up to 3.5MB
- Auto-refresh file browser
- In-app configuration
- Debug mode
- Gmail app password support

---