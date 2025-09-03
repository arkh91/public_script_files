// File: generateDNSKey.js

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

// Hardcoded domain for key URLs
const DOMAIN = 'your-dns-server.example.com';

// File to store keys
const KEYS_FILE = path.join(__dirname, 'dns_keys.json');

// Key settings
const KEY_LENGTH_BYTES = 32; // 32 bytes => 64 hex chars
const DEFAULT_EXPIRATION_DAYS = 7; // Key valid for 7 days
const DEFAULT_USAGE_LIMIT = 1; // Max 1 usage per key

// Generate a random key
function generateKey() {
    return crypto.randomBytes(KEY_LENGTH_BYTES).toString('hex');
}

// Generate the URL for the key
function generateKeyURL(key) {
    return `https://${DOMAIN}/access/${key}`;
}

// Save the key object to file
function saveKey(keyObj) {
    let keys = [];
    if (fs.existsSync(KEYS_FILE)) {
        keys = JSON.parse(fs.readFileSync(KEYS_FILE, 'utf8'));
    }
    keys.push(keyObj);
    fs.writeFileSync(KEYS_FILE, JSON.stringify(keys, null, 2));
}

// Generate expiration timestamp
function getExpirationDate(days) {
    const now = new Date();
    now.setDate(now.getDate() + days);
    return now.toISOString();
}

// Main function
function main() {
    const key = generateKey();
    const url = generateKeyURL(key);
    const keyObj = {
        key,
        url,
        createdAt: new Date().toISOString(),
        expiresAt: getExpirationDate(DEFAULT_EXPIRATION_DAYS),
        usageLimit: DEFAULT_USAGE_LIMIT,
        usageCount: 0
    };

    saveKey(keyObj);
    console.log(`[+] Key generated successfully:`);
    console.log(`URL: ${url}`);
    console.log(`Expires at: ${keyObj.expiresAt}`);
    console.log(`Usage limit: ${keyObj.usageLimit}`);
}

main();
