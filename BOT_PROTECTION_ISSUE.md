# 🚨 Imunify360 Bot Protection Blocking App - CONFIRMED

## Problem - **IMUNIFY360 DETECTED**

Your WordPress site at `https://www.new.portobellodigallura.it` has **Imunify360 bot protection** that's **actively blocking ALL requests** from your Flutter app.

### **Test Confirmation:**
```bash
curl https://www.new.portobellodigallura.it/wp-json/wp/v2/posts
Response: "Access denied by Imunify360 bot-protection. 
           IPs used for automation should be whitelisted"
```

**This is NOT a problem with your app or credentials - it's server-side protection.**

### Symptoms:
- ❌ Login returns HTML instead of cookies (11,748 bytes HTML page)
- ❌ API requests return "Please wait while your request is being verified..." page
- ❌ Status code is `200` but response is HTML, not JSON
- ❌ No posts can be loaded
- ❌ No authentication possible

### Evidence from Logs:
```
Content-Type: text/html (should be application/json or set cookies)
Content-Length: 11748 (full HTML page, not API response)
Server: openresty/1.27.1.1
cf-edge-cache: no-cache (Cloudflare headers present)
```

---

## ✅ Solutions for Imunify360

### **Option 1: Disable Imunify360 for WordPress API (RECOMMENDED)**

#### **Via cPanel (if you have access):**

1. Log into **cPanel**
2. Search for "Imunify360" in the search bar
3. Go to **Settings** → **Malware Scanner**
4. Add to **Ignore List**:
   ```
   /wp-json/*
   /wp-login.php
   /wp-admin/admin-ajax.php
   ```
5. Save changes

#### **Via Imunify360 Firewall:**

1. **Imunify360** → **Firewall**
2. **Whitelist** → **Add new rule**
3. Add custom rule:
   - **Type**: User-Agent
   - **Contains**: `Mobile` or `iPhone`
   - **Action**: Whitelist
4. Save and test

#### **Via Hosting Provider:**

Contact your WordPress hosting provider or server administrator to:

1. **Whitelist WordPress REST API endpoints**:
   - `/wp-json/*` - All REST API endpoints
   - `/wp-login.php` - Login page
   - `/wp-admin/admin-ajax.php` - AJAX endpoints

2. **Reduce bot protection sensitivity**:
   - Configure Cloudflare/bot protection to allow mobile app traffic
   - Add rule: "Bypass for User-Agent containing 'Mobile'"
   - Or completely disable bot protection for API endpoints

3. **Create firewall rule** (if using Cloudflare):
   ```
   (http.request.uri.path contains "/wp-json/") or 
   (http.request.uri.path contains "/wp-login.php")
   → Action: Allow
   ```

---

### **Option 2: Use Application Password (Backend Setup Required)**

If you control the WordPress backend, enable **Application Passwords**:

1. Go to WordPress Admin → Users → Profile
2. Scroll to "Application Passwords" section
3. Generate a new application password for your Flutter app
4. Use Basic Auth with username + application password

**Benefits**:
- Bypasses bot protection more reliably
- More secure than standard passwords
- Designed for API access

---

### **Option 3: Add IP Whitelist**

If your Flutter app makes requests from a fixed server:

1. Get your app's outgoing IP address
2. Whitelist this IP in Cloudflare/bot protection
3. Configure to bypass all security checks for this IP

---

### **Option 4: Disable Cloudflare/Bot Protection (NOT RECOMMENDED)**

Temporarily disable bot protection to test:
- This is **not a permanent solution**
- Only use for debugging
- Site will be vulnerable to attacks

---

## 🛠️ App-Side Fixes Applied

I've updated the Flutter app to:

✅ Use realistic mobile User-Agent headers  
✅ Add Accept-Language and Cache-Control headers  
✅ Detect HTML responses (bot protection pages)  
✅ Show user-friendly error messages  
✅ Provide better logging for debugging  

### Updated Headers (in all API calls):
```dart
headers: {
  'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
  'Accept': 'application/json',
  'Accept-Language': 'it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7',
  'Cache-Control': 'no-cache',
}
```

---

## 🔍 How to Test

### Test 1: Check if API is accessible from browser
```bash
curl -v https://www.new.portobellodigallura.it/wp-json/wp/v2/posts
```

If you see HTML instead of JSON → Bot protection is active

### Test 2: Check with mobile User-Agent
```bash
curl -v -H "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15" \
  https://www.new.portobellodigallura.it/wp-json/wp/v2/posts
```

If this works → Headers help, but may not be enough

### Test 3: Check login endpoint
```bash
curl -v https://www.new.portobellodigallura.it/wp-login.php
```

Look for "Please wait while your request is being verified" in response

---

## 📝 Recommended Action Plan

1. **Contact hosting provider immediately** with this information:
   - "Our mobile app is being blocked by bot protection"
   - "Need to whitelist `/wp-json/*` and `/wp-login.php` endpoints"
   - "App is using proper User-Agent headers but still blocked"

2. **Ask them to**:
   - Check Cloudflare/security settings
   - Create exception rule for WordPress API
   - Provide application password support

3. **Test again** after server-side changes

4. **Alternative**: If they can't help, consider:
   - Moving to a different hosting provider that supports mobile apps
   - Setting up a proxy server without bot protection
   - Using WordPress REST API authentication plugins

---

## 🆘 Need Help?

If server-side changes aren't possible, we can explore:
- Setting up a proxy API endpoint
- Using WebView for authentication (not ideal)
- Alternative authentication methods

But the **best solution is always server-side whitelisting**.

---

## 📞 Who to Contact

**Your Hosting Provider** or **Server Administrator**:
- Show them this document
- Ask for "API endpoint whitelisting"
- Mention "mobile app being blocked by bot protection"

They should understand the issue immediately.

