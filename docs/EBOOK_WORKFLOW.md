# Ebook to Kindle Workflow

Complete automated workflow for ebook acquisition, management, and Kindle delivery using LazyLibrarian and Calibre-Web-Automated.

## Architecture

```
LazyLibrarian (acquisition)
    ↓
Download to /downloads (NFS)
    ↓
Process & copy to /cwa-ingest (NFS, via custom script)
    ↓
Calibre-Web-Automated (auto-import)
    ↓
Library at /calibre-library (NFS)
    ↓
Send to Kindle (email)
```

## Components

### LazyLibrarian
- **Purpose**: Automated ebook acquisition (Readarr replacement)
- **URL**: `https://lazylibrarian.kieranajp.uk`
- **Port**: 5299
- **Storage**:
  - Config: 2Gi local-path PVC
  - Books: NFS mount at `/books`
  - Downloads: NFS mount at `/downloads`
  - CWA Ingest: NFS mount at `/cwa-ingest` (shared with CWA)

### Calibre-Web-Automated
- **Purpose**: Ebook library management + Send to Kindle
- **URL**: `https://calibre.kieranajp.uk`
- **Port**: 8083
- **Storage**:
  - Config: 5Gi local-path PVC
  - Ingest: NFS mount at `/cwa-book-ingest` (shared with LazyLibrarian)
  - Library: NFS mount at `/calibre-library`
- **Features**:
  - Auto-import from ingest folder
  - Automatic EPUB fixing for Kindle compatibility
  - Format conversion (EPUB, MOBI, AZW3, PDF)
  - One-click Send to Kindle via email

## Setup Instructions

### 1. NFS Configuration

Add to your `terraform.tfvars`:

```hcl
nfs = {
  server         = "your-nfs-server"
  tv_path        = "/path/to/tv"
  books_path     = "/path/to/books"    # Add this line
  downloads_path = "/path/to/downloads"
  puid           = 1000
  pgid           = 1000
}
```

### 2. Deploy with Terraform

```bash
cd terraform
tofu plan
tofu apply
```

### 3. LazyLibrarian Configuration

1. Access `https://lazylibrarian.kieranajp.uk` (via Ory auth)
2. Configure indexers and download clients
3. Set eBook library path: `/books`
4. Set download directory: `/downloads`
5. In Settings → Processing → Post Processing:
   - Enable "Copy to directory"
   - Set directory: `/cwa-ingest`
   - OR use Custom Script: `/scripts/copy-to-calibre.sh`

### 4. Calibre-Web-Automated Configuration

1. Access `https://calibre.kieranajp.uk` (via Ory auth)
2. Initial setup will auto-create Calibre library at `/calibre-library`
3. Configure SMTP settings for Kindle email:
   - Admin → Settings → E-mail Server Settings
   - Configure your SMTP server details
4. Add Kindle email in user profile:
   - Settings → Send to Kindle Email
   - Add your `@kindle.com` email address

### 5. Amazon Kindle Setup

1. Go to Amazon's Manage Your Content and Devices
2. Navigate to Preferences → Personal Document Settings
3. Add the sending email address to "Approved Personal Document E-mail List"
4. Note your Send-to-Kindle email (e.g., `username@kindle.com`)

## Workflow

### Automatic Workflow

1. LazyLibrarian searches for new ebooks
2. Downloads to `/downloads` (NFS)
3. Processes and copies to `/cwa-ingest` (NFS)
4. CWA auto-detects new files in ingest folder
5. Imports into Calibre library at `/calibre-library`
6. Auto-fixes EPUB for Kindle compatibility
7. Book available in CWA web interface

### Manual Send to Kindle

1. Browse to book in CWA web interface
2. Click the paper airplane icon
3. Book is automatically:
   - Fixed for Kindle compatibility (if needed)
   - Converted to optimal format
   - Emailed to your Kindle

## Integration Script

LazyLibrarian uses a custom script to copy books to CWA ingest folder:

**Location**: `/scripts/copy-to-calibre.sh` (mounted from ConfigMap)

**Usage**: Automatically called by LazyLibrarian after download

**What it does**:
- Copies downloaded ebook to `/cwa-ingest`
- CWA watches this folder and auto-imports

## Storage Layout

```
NFS Server:
├── /books/                     # LazyLibrarian output & CWA ingest
│   └── (incoming books)
├── /downloads/                 # LazyLibrarian downloads
│   └── (temporary downloads)
└── (Calibre library managed by CWA)

Local PVCs:
├── lazylibrarian-config (2Gi)
└── calibre-web-automated-config (5Gi)
```

## Authentication

Both services are protected by Ory Oathkeeper using the `ory-auth` middleware. Access requires:
- Valid Kratos session (cookie-based)
- Google OAuth or username/password authentication

## Troubleshooting

### Books not appearing in CWA

1. Check LazyLibrarian logs for copy errors
2. Verify `/cwa-ingest` is writable (NFS permissions)
3. Check CWA logs for import errors
4. Ensure NETWORK_SHARE_MODE=true in CWA (enabled by default)

### Kindle email not working

1. Verify SMTP configuration in CWA
2. Check Kindle email is whitelisted in Amazon settings
3. Check Amazon's spam filters (may silently drop emails)
4. Verify book format is compatible (EPUB/MOBI/AZW3/PDF)

### Permission errors

1. Verify NFS export allows read/write for PUID/PGID
2. Check PUID/PGID match in both containers (set via Terraform)
3. Verify NFS paths are correct in `terraform.tfvars`

## Files

### Helm Charts
- `charts/lazylibrarian/`
- `charts/calibre-web-automated/`

### Values
- `values/lazylibrarian.yaml`
- `values/calibre-web-automated.yaml`

### Terraform
- `media.tf` - Helm release definitions
- `variables.tf` - Variable definitions (includes `nfs.books_path`)

### Scripts
- `charts/lazylibrarian/templates/configmap.yaml` - Integration script

## References

- [LazyLibrarian Documentation](https://lazylibrarian.gitlab.io/)
- [Calibre-Web-Automated GitHub](https://github.com/crocodilestick/Calibre-Web-Automated)
- [Amazon Send to Kindle](https://www.amazon.com/sendtokindle)
