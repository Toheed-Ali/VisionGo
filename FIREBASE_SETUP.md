# Firebase Realtime Database Rules Setup

## Step 1: Open Firebase Console
1. Go to https://console.firebase.google.com/
2. Select your project: **VisionGo**
3. Click **Realtime Database** in the left menu
4. Click the **Rules** tab

## Step 2: Copy & Paste These Rules

Replace all existing rules with:

```json
{
  "rules": {
    "pairings": {
      "$pairingCode": {
        ".read": "auth != null",
        ".write": "auth != null",
        "selectedObjects": {
          ".validate": "newData.isString() || newData.hasChildren()"
        },
        "timestamp": {
          ".validate": "newData.isNumber()"
        },
        "devices": {
          "camera": {
            ".validate": "newData.hasChildren(['userId', 'timestamp'])"
          },
          "monitor": {
            ".validate": "newData.hasChildren(['userId', 'timestamp'])"
          }
        },
        "alerts": {
          "$alertId": {
            ".validate": "newData.hasChildren(['objectLabel', 'timestamp'])"
          }
        }
      }
    },
    "users": {
      "$userId": {
        ".read": "$userId === auth.uid",
        ".write": "$userId === auth.uid",
        "pairingCodes": {
          ".validate": "newData.hasChildren()"
        },
        "devices": {
          "$deviceId": {
            ".validate": "newData.hasChildren(['pairingCode', 'role', 'timestamp'])"
          }
        }
      }
    }
  }
}
```

## Step 3: Publish Rules
Click **Publish** button

## What These Rules Do

### Security Features:
✅ **Authentication Required** - Only logged-in users can read/write data  
✅ **User Isolation** - Users can only access their own data under `/users/{userId}/`  
✅ **Data Validation** - Ensures data has required fields before saving  
✅ **Pairing Protection** - Authenticated users can access pairing data

### Data Structure Protected:
- `/pairings/{code}/` - Camera-monitor pairing data
- `/pairings/{code}/alerts/` - Security alerts
- `/users/{userId}/` - User-specific data
- `/users/{userId}/pairingCodes/` - User's pairing codes
- `/users/{userId}/devices/` - User's device info

## Testing Rules
After publishing, test by:
1. Run your app
2. Try to pair devices
3. Check Firebase console → Realtime Database → Data tab
4. Verify data exists under correct paths

## Troubleshooting
- **"Permission denied"** → Make sure user is logged in
- **Data not saving** → Check validation rules match your data structure
- **Can't read data** → Verify authentication is working
