# DECIBEL — Privacy Policy & Data Collection Practices

**Last Updated:** October 2026  
**Application:** DECIBEL Music Player (Android & iOS)

---

## 1. Overview
DECIBEL is an indie, high-fidelity music streaming application. We are committed to absolute user privacy. DECIBEL does **not** sell data, run advertisements, or build personal identity profiles. 

During our beta phase, we collect minimal, strictly anonymized playback telemetry solely to train our on-device and algorithmic music recommendation engine (discovering personalized tracks matching your taste).

---

## 2. What We Collect (Anonymous Only)
When you opt in to our beta improvement program, we collect:
* **Playback Interaction Metrics:** 
  * Track completion percentage, listening duration (`listened_ms`), and skips.
  * Like/favorite actions and whether a track was added to a local playlist or downloaded for offline listening.
  * Audio buffer stall events (used solely to diagnose playback reliability).
* **Playback Origin:** 
  * Categorical tag indicating whether the song was played from Search, Recommended mixes, Top Pick Playlists, or Radio queue.
* **Taste Preferences:** 
  * The music languages and favorite artist tags you selected during onboarding or in Settings.
* **Device Telemetry:** 
  * Device model (e.g. *Samsung Galaxy S23*) and Operating System version (e.g. *Android 14*), used strictly to optimize lossless DSP audio engine compatibility.
* **Anonymous Installation Identifier:** 
  * A client-generated random UUID tied to anonymous authentication. It is never linked to an email, Google account, or hardware IMEI.

---

## 3. What We NEVER Collect
We adhere strictly to data minimization. DECIBEL **never** collects, transmits, or accesses:
* **No Personal Identifiers:** No names, email addresses, phone numbers, passwords, or social media accounts.
* **No Search Queries:** We never collect the text queries you type into the search bar.
* **No Audio or Microphone Data:** The app does not request microphone permissions or record ambient sound.
* **No Location Data:** No GPS coordinates, Wi-Fi networks, or IP geolocation tracking.
* **No Contacts or Media Files:** We do not read your device contact list, photo gallery, or personal files.

---

## 4. How Your Data is Used & Stored
* **Local Offline-First Buffer:** All telemetry is buffered locally on your device in an encrypted SQLite database. If you are offline, nothing is transmitted.
* **Secure Cloud Storage:** When connected, metrics are synced over encrypted HTTPS (TLS 1.3) to our backend Postgres database hosted on Supabase.
* **Row Level Security (RLS):** Every database row is secured with Postgres Row Level Security. Each install can only write and read its own anonymous events.
* **Data Retention:** Synced event records on your local device are automatically purged after 7 days.

---

## 5. Your Rights & The Right to Be Forgotten
You have complete control over your data:
1. **Opt-Out Anytime:** You can decline the consent dialog on first launch. If declined, no telemetry is ever uploaded.
2. **Instant Deletion ("Right to be Forgotten"):**
   * Open **Your Library** $\rightarrow$ Tap the developer/telemetry icon in the top header.
   * Tap **"Delete My Data"**.
   * This immediately triggers a Postgres RPC function (`delete_my_data()`) that permanently cascades and deletes all records associated with your install UUID from our servers, and wipes your local database history.

---

## 6. Contact & Open Source Transparency
If you have questions regarding DECIBEL's privacy practices or wish to review the source code and database schemas:
* **Architecture Documentation:** Review [`DECIBEL_DATA_COLLECTION.md`](./DECIBEL_DATA_COLLECTION.md) in the repository.
* **Developer Contact:** Support inquiries can be directed through our beta testing channel.
