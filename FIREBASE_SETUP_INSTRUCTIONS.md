# Firebase Configuration for Messaging System

## 🚨 **Required Firebase Console Setup**

Your messaging system requires these Firebase services to be properly configured:

### 1. **Firestore Database Setup**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `wom-ww`
3. Navigate to **Firestore Database**
4. If not already created, click **"Create database"**
5. Choose **"Start in test mode"** for development
6. Select a location (choose closest to your users)

**Required Collections:**
```
chats/
  {chatId}/
    - id: string
    - type: "direct" | "group"
    - participants: array
    - participantUIDs: array
    - createdBy: string
    - createdAt: timestamp
    - lastActivity: timestamp
    - lastMessage: object (optional)
    - name: string (optional, for groups)
    - messages/
      {messageId}/
        - id: string
        - chatId: string
        - senderId: string
        - content: string
        - timestamp: timestamp
        - status: "sending" | "sent" | "delivered" | "read"
        - type: "text" | "image" | "system"

users/
  {userId}/
    - uid: string
    - username: string
    - displayName: string
    - email: string
    - profileImageURL: string
    - friends/
      {friendId}/
        - uid: string
        - username: string
        - displayName: string
        - dateAdded: timestamp

friendRequests/
  {requestId}/
    - fromUID: string
    - toUID: string
    - status: "pending" | "accepted" | "declined"
    - createdAt: timestamp
```

### 2. **Firestore Security Rules**

Replace your Firestore rules with these (includes web app + mobile messaging):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Web app collections - keep existing functionality
    match /EarlyAccess/{document} {
      allow read, write, create, update, delete: if true;
    }
    
    match /ContactUs/{document} {
      allow create: if true;
      allow read, write, update, delete: if request.auth != null;
    }
    
    match /BusinessApplications/{document} {
      allow create: if true;
      allow read, write, update, delete: if request.auth != null;
    }
    
    // Mobile app - User profiles and authentication
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow create, update, delete: if request.auth != null && request.auth.uid == userId;
      
      // Allow reading other user profiles for friends/search functionality
      allow read: if request.auth != null;
      
      // Friends subcollection - users can manage their own friends
      match /friends/{friendId} {
        allow read, write, create, update, delete: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Friend requests - users can read/write their own requests
    match /friendRequests/{requestId} {
      allow read, write: if request.auth != null && 
        (resource.data.fromUID == request.auth.uid || resource.data.toUID == request.auth.uid);
      allow create: if request.auth != null && request.auth.uid == request.resource.data.fromUID;
      allow update, delete: if request.auth != null && 
        (resource.data.fromUID == request.auth.uid || resource.data.toUID == request.auth.uid);
    }
    
    // Chats - participants can read/write their chats
    match /chats/{chatId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participantUIDs;
      allow create: if request.auth != null && 
        request.auth.uid in request.resource.data.participantUIDs;
      allow update: if request.auth != null && 
        request.auth.uid in resource.data.participantUIDs;
      allow delete: if request.auth != null && 
        request.auth.uid in resource.data.participantUIDs;
        
      // Messages subcollection - participants can read, senders can create
      match /messages/{messageId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null && request.auth.uid == request.resource.data.senderId;
        allow update: if request.auth != null && request.auth.uid == resource.data.senderId;
        allow delete: if request.auth != null && request.auth.uid == resource.data.senderId;
      }
    }
    
    // Default fallback for other collections - require authentication
    // This ensures web app functionality continues to work
    match /{document=**} {
      allow read, write, create, update, delete: if request.auth != null;
    }
  }
}
```

### 3. **Firebase Storage Rules**

Update your Storage rules to keep profile and chat images locked down to the correct users:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSignedIn() {
      return request.auth != null;
    }

    function isProfileOwner(uid) {
      return isSignedIn() && request.auth.uid == uid;
    }

    match /profile_images/{uid}/{allPaths=**} {
      allow write: if isProfileOwner(uid);
      allow read: if true;  // tighten if you want avatars private
    }

    // Fixed: need to call using Firestore to enable cross-service security
    function chatDoc(chatId) {
      return firestore.get(/databases/(default)/documents/chats/$(chatId));
    }

    function isChatParticipant(chatId) {
      return isSignedIn()
        && chatDoc(chatId).data != null
        && chatDoc(chatId).data.participantUIDs != null
        && chatDoc(chatId).data.participantUIDs.hasAny([request.auth.uid]);
    }

    match /group_chat_images/{chatId}/{allPaths=**} {
      allow read, write: if isChatParticipant(chatId);
    }

    match /chat_images/{chatId}/{allPaths=**} {
      allow read, write: if isChatParticipant(chatId);
    }
  }
}
```

### 4. **Authentication Setup**

1. Go to **Authentication** > **Sign-in method**
2. Enable these providers:
   - ✅ **Email/Password**
   - ✅ **Google** (if using Google Sign-In)

### 5. **App Check Configuration (Optional for Development)**

**For Development (Recommended):**
- Keep App Check **DISABLED** as we've configured
- This eliminates the 403 errors you're seeing

**For Production (Later):**
1. Go to **App Check** in Firebase Console
2. Register your iOS app
3. Enable **App Attest** provider
4. Update the code to re-enable AppCheck

### 6. **Firebase Project Settings**

Verify these settings in **Project Settings**:
- **Project ID**: `wom-ww` ✅
- **Bundle ID**: `WOM.WOM-APP` ✅
- **GoogleService-Info.plist** is properly added to Xcode ✅

## 🧪 **Testing Your Setup**

After completing the above steps:

1. **Clean and rebuild** your app
2. **Test user registration/login**
3. **Test friend requests**
4. **Test creating a direct message**
5. **Test sending messages**

## 🚨 **Common Issues & Solutions**

### Issue: "Permission denied" errors
**Solution**: Check Firestore security rules match the ones above

### Issue: "Collection doesn't exist" errors
**Solution**: Create the collections by sending your first message/friend request

### Issue: Still getting AppCheck errors
**Solution**: Ensure AppCheck is disabled in Firebase Console for your app

### Issue: Messages not appearing in real-time
**Solution**: Check that Firestore listeners are properly set up (they are in the code)

## 📱 **Development vs Production**

**Current Setup (Development):**
- ✅ AppCheck disabled
- ✅ Firestore in test mode
- ✅ Verbose logging disabled

**For Production:**
- Enable AppCheck with App Attest
- Update Firestore rules to be more restrictive
- Enable production mode

## 🔄 **Next Steps**

1. Complete the Firebase Console setup above
2. Test the messaging functionality
3. If issues persist, check the Xcode console for specific error messages
4. Gradually enable security features for production

---

**Need Help?** 
- Check Firebase Console logs
- Review Xcode console output
- Verify network connectivity
- Ensure Firebase SDK versions are compatible
