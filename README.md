# Salah Times

A small website showing today's prayer **start times from London Prayer Times** (the official East London Mosque timetable) next to the **jamā'ah times** of mosques you choose (Markaz us-Sunnah to begin with). It works on any phone, installs like an app, loads instantly from its cache, and works offline.

Everything runs for free on GitHub, with no dependence on Claude or any particular computer:

| Part | What it does |
|---|---|
| `index.html` | The whole app: Today and Month, plus an Admin page reached from the small **Admin** link at the bottom of the Today screen (or by adding `#admin` to the address). |
| `data/timetables.json` | All the times, in one small file. |
| `sw.js`, `manifest.webmanifest`, `icons/` | Offline support and "Add to Home screen" / APK support. |
| `scripts/update-lpt.mjs` + `.github/workflows/update-start-times.yml` | Every Monday, GitHub fetches the start times from the London Prayer Times API (this month and up to 12 ahead). |
| `AI-PROMPT.md` | The prompt to give any AI with a timetable JPG or PDF (also on the Admin page, with a Copy button). |
| `serve.ps1` | Optional: preview the site on a Windows PC at http://localhost:8080. |

---

## One-time setup (about 15 minutes)

### 1. Put the files on GitHub
1. Create a free account at https://github.com (if you don't have one).
2. Click **+ → New repository**. Name it e.g. `salah-times`, choose **Public**, and click **Create repository**.
3. On the new repository page click **uploading an existing file**, then drag in **everything inside this folder** (including the `data`, `icons`, `scripts` and `.github` folders). Click **Commit changes**.
   - If the `.github` folder doesn't upload (some computers hide folders starting with a dot): click **Add file → Create new file**, type the name `.github/workflows/update-start-times.yml`, paste in the contents of that file, and commit.

### 2. Turn on the website
1. In the repository go to **Settings → Pages**.
2. Under **Build and deployment**, choose **Deploy from a branch**, branch **main**, folder **/ (root)**, and **Save**.
3. After a minute or two the page shows your address, e.g. `https://yourname.github.io/salah-times/`. That is the website anyone can open.

### 3. Let the weekly start-time update run
1. Go to **Settings → Secrets and variables → Actions → New repository secret**. Name it `LPT_KEY` and paste your London Prayer Times API key as the value. GitHub keeps it hidden; it never appears in the website or the files.
2. Go to **Settings → Actions → General → Workflow permissions**, choose **Read and write permissions**, and **Save**.
3. Go to the **Actions** tab → **Update start times** → **Run workflow** once to check it works. It then runs every Monday by itself. London Prayer Times usually publishes the next year's times in late October; the job picks them up automatically.

### 4. Let your phone publish timetables
So that timetables you paste on your phone go live for everyone:
1. On GitHub: your photo (top right) → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
2. Name it "Salah Times", set an expiry (up to a year; you'll need to make a new one when it expires), **Repository access → Only select repositories →** `salah-times`.
3. Under **Permissions → Repository permissions**, set **Contents** to **Read and write**. Generate it and copy the token.
4. On your phone, open the website → **Admin** (bottom of the Today screen) **→ Publishing**. Enter your GitHub user name, the repository name and the token, then tap **Save and test**.

The token is stored only on that phone. Don't share it. Anyone else who finds the Admin page can try things out, but nothing they do reaches the website without a token.

---

## Adding a new month (each month, or whenever a mosque publishes a timetable)

1. Open the website → **Admin → AI prompt → Copy prompt**.
2. Paste it into any AI (ChatGPT, Gemini, Claude…), attach the timetable JPG or PDF, and send.
3. Copy the AI's answer, paste it into **Add timetables**, tap **Check**. Wrong-looking times are highlighted; fix the AI's answer and Check again if needed.
4. Tap **Save timetables**. With publishing set up it goes live straight away; other phones pick it up within a few hours, or straight away if they tap **Refresh**.

You don't need to do this for start times; they arrive automatically every Monday. A timetable for a mosque that isn't on the list yet adds that mosque automatically (you choose its short column name). Each phone can tick or untick which mosques appear on its Today screen.

If publishing isn't set up, you can still tap **Publishing → Download data file** and upload that file to the `data` folder on GitHub (**Add file → Upload files**, replacing `timetables.json`).

---

## Turning it into an Android app (APK)

The site is already an installable web app. On Android, open it in Chrome → menu → **Add to Home screen / Install app**.

For a real APK to share or put on the Play Store:
1. Go to https://www.pwabuilder.com and enter your website address.
2. Choose **Package for stores → Android**, then **Download**. You get an APK to install directly (and an AAB for the Play Store).
3. The app shows the same website, so anything you publish appears in the app too. No rebuild needed.

---

## Notes
- Times are shown as a 12-hour clock with a small am/pm.
- The file keeps last month onwards; older months are dropped automatically.
- If the London Prayer Times API is down or the key stops working, the weekly update fails (you'd see a red cross in the Actions tab) and the site keeps the times it already has. You can always paste East London Mosque's PDF through the AI prompt instead.
- Keep the API key out of the website's files. It belongs only in the `LPT_KEY` secret.
- London Prayer Times asks to be credited; the site's footer does this.
- Please let the mosques know you're republishing their timetables.
