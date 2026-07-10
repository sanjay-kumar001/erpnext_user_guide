# Automating ERPNext Backups to Personal Google Drive

This guide outlines the process for configuring automatic ERPNext database backups to a personal Google Drive account and implementing a reliable, server-side automated cleanup routine to manage storage space.

---

## Index
1. [Introduction](#introduction)
2. [1: Setting up Google Drive for ERPNext](#1-setting-up-google-drive-for-erpnext)
3. [2: Configuring ERPNext Integration](#2-configuring-erpnext-integration)
4. [3: Automated Backup Management (Retention Policy)](#3-automated-backup-management-retention-policy)
5. [Considerations & Limitations](#considerations--limitations)

---

## Introduction
Users often seek to utilize the 15GB of free storage provided by personal Google accounts for ERPNext backups. This configuration is possible by leveraging Google Cloud's "Testing" mode for OAuth authentication and using Google Apps Script to manage file retention.

---

## 1: Setting up Google Drive for ERPNext

### 1.1 Create a Google Cloud Project
*   Navigate to the [Google Cloud Console](https://console.cloud.google.com/).
*   Create a new project (e.g., "ERPNext Backups").
*   Enable the **Google Drive API** in the API Library.

### 1.2 Configure OAuth Consent Screen
*   Select **External** as the User Type.
*   Keep the **Publishing Status** as **Testing**.
*   **Critical:** Add your personal Gmail address to the **Test Users** list. This bypasses the need for official Google App verification.

### 1.3 Create Credentials
*   Navigate to **Credentials** -> **Create Credentials** -> **OAuth Client ID**.
*   Select **Web Application**.
*   **Authorized JavaScript origins:** `https://your-erpnext-domain.com`
*   **Authorized redirect URIs:** `https://your-erpnext-domain.com?cmd=frappe.integrations.doctype.google_drive.google_drive.google_callback`
*   Save/Copy the generated **Client ID** and **Client Secret**.

---

## 2: Configuring ERPNext Integration

Once you have the keys, you need to save them in your ERPNext instance and authorize access.

* In the Awesomebar, search for **Google Settings**.
* Paste your **Client ID** and **Client Secret**, check **Enable**, and click **Save**.
* Next, search for the **Google Drive** DocType (or go to *Integrations > Google Drive*).
* Click **New** to create a backup profile:
* Give it a name (e.g., "Personal Drive Backup").
* Specify a **Backup Frequency** (Daily, Weekly, etc.).
* Provide a notification email if you want to track failures/successes.
* Click **Save**.


* After saving, a button labeled **Authorize Drive Access** will appear at the top right.
* Click it, log in with your personal Google account, accept the warning screen (since it's a self-created test app), and grant permissions.

**Test:** Click **Take Backup** to confirm connectivity.

---

## 3: Automated Backup Management (Retention Policy)

To avoid consuming your free 15GB space, use **Google Apps Script** to delete backups older than 7 days. This runs independently of ERPNext, ensuring no server-side overhead.

### 3.1 The Cleanup Script
1.  Go to [script.google.com](https://script.google.com/).
2.  Create a new project and paste the following code:

```javascript
function deleteOldERPNextBackups() {
  // Use your Folder ID from the URL: drive.google.com/drive/folders/[FOLDER_ID]
  var folderId = "YOUR_FOLDER_ID_HERE"; 
  var retentionDays = 7;
  var thresholdDate = new Date();
  thresholdDate.setDate(thresholdDate.getDate() - retentionDays);
  
  try {
    var folder = DriveApp.getFolderById(folderId);
    var files = folder.getFiles();
    
    while (files.hasNext()) {
      var file = files.next();
      if (file.getDateCreated() < thresholdDate) {
        file.setTrashed(true); // Moves to Trash
      }
    }
  } catch (error) {
    Logger.log("Error: " + error.toString());
  }
}
```

### 3.2 Automated Daily Trigger
To make this script run automatically every day without you touching it:

1. On the left sidebar of the Apps Script page, click the **Triggers** icon (it looks like a clock).
2. Click the **+ Add Trigger** button in the bottom right corner.
3. Configure the settings exactly like this:
* **Choose which function to run:** `deleteOldERPNextBackups`
* **Choose which deployment should run:** `Head`
* **Select event source:** `Time-driven`
* **Select type of time based trigger:** `Day timer`
* **Select time of day:** Choose a window (e.g., *Midnight to 1 AM* or *4 AM to 5 AM*)—ideally a few hours after your ERPNext backup usually drops.


4. Click **Save**.
5. Google will show a popup asking you to authorize the script to manage your Drive. Click your account, click **Advanced**, and select **Go to ERPNext Backup Cleaner (unsafe)** to grant access.

### 3.3 How to get your Folder ID

1. Open your **Google Drive** in a web browser.
2. Go inside the specific folder where ERPNext uploads your backups.
3. Look at your browser's address bar. The URL will look like this:
`[https://drive.google.com/drive/folders/1A2b3C4d5E6f7G8h9I0j_klmNoPqRstUv](https://drive.google.com/drive/folders/1A2b3C4d5E6f7G8h9I0j_klmNoPqRstUv)`
4. Copy everything **after** the last forward slash (`/`). That long string of letters and numbers (e.g., `1A2b3C4d5E6f7G8h9I0j_klmNoPqRstUv`) is your unique **Folder ID**.
5. Replace `"YOUR_FOLDER_ID_HERE"` in the script with that ID (keeping the quotation marks).

Now, even if you rename the folder in Google Drive later on, the script will still find it perfectly and safely clean out only the files older than 7 days inside it.

---

## Considerations & Limitations
*   **Token Expiry:** Because this uses "Testing" mode, if you do not use the API frequently, the token might expire. If backups stop, re-authorize in the Google Drive DocType.
*   **Size Limit:** Frappe's native integration handles files up to 1GB smoothly. If your site grows beyond this, consider external S3-compatible storage (e.g., Cloudflare R2 or Backblaze B2).
*   **Security:** By using `file.setTrashed(true)`, backups are moved to the Trash for 30 days before permanent deletion, providing a safety buffer.
