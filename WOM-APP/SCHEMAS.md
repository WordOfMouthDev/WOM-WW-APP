# WOM Data Schemas

## Relationship Overview
- `UserProfile` documents centralize user identity, onboarding status, service interests, and last known location. Other schemas either embed into the profile (e.g. `OnboardingProgress`, `UserLocation`) or derive from it (`Friend`, chat participants).
- Businesses synchronize between Google Places results and the app's Firestore collections via `BusinessResolver`, enabling feedback, bookmarking, and detail views to share the same `Business` schema.
- Social features reuse profile slices: `Friend` mirrors `UserProfile` fields for quick lookup, while `FriendRequest` tracks pending relationships. Messaging builds on these identities through `ChatParticipant`, `Chat`, and `Message` records stored per chat.
- Firestore collections (`users`, `businesses`, `friendRequests`, `chats`, nested `messages`, and per-user subcollections such as `mySpots` and `businessFeedback`) provide persistence layers for the schemas below.

## Domain Schemas

### UserProfile (`Models/UserProfile.swift`)
**Fields**
- `email: String`, `displayName: String`, `username: String`, `profileImageURL: String`, `uid: String`
- `dateOfBirth: Date?`, `phoneNumber: String?`
- `selectedServices: [String]?` — stores `Service.id` values selected during onboarding
- `location: UserLocation?`
- `onboardingProgress: OnboardingProgress`

**Usage**
- Created and updated through `AuthViewModel` for registration/profile edits and stored at `users/{uid}`.
- Read and mutated by `OnboardingViewModel` to track step completion, service choices, and persisted business picks.
- Dereferenced by `FriendsManager` (search, requests, friend lists) and `MessagingManager` (chat participant identity refresh).

### OnboardingStep & OnboardingProgress (`Models/OnboardingStep.swift`)
**Fields**
- `OnboardingStep`: `id`, `title`, `isCompleted`, `order`
- `OnboardingProgress`: `steps: [OnboardingStep]`, `currentStepIndex`, `isCompleted`

**Usage**
- Default steps define required onboarding flow. `OnboardingViewModel` loads/saves them in `users/{uid}` documents and orchestrates completion, allowing features to detect the next required step.

### UserLocation (`Models/UserLocation.swift`)
**Fields**
- `latitude`, `longitude`, optional `city`, `state`, `country`
- `isPermissionGranted: Bool`, `timestamp: Date`

**Usage**
- Embedded within `UserProfile` for onboarding and location-aware recommendations.
- Converted from Core Location results by onboarding and search flows to drive `BusinessSearchManager` queries.

### Service (`Models/Service.swift`)
**Fields**
- `id: String`, `name: String`, `category: ServiceCategory`
- `ServiceCategory` enumerates high-level groupings (`beauty`, `fitness`, `wellness`).

**Usage**
- Provides the catalog rendered during onboarding service selection; IDs are persisted in `UserProfile.selectedServices`.

### Business & Supporting Types (`Models/Business.swift`)
**Fields**
- `womId: String` (stable app-wide identifier)
- `externalIds: BusinessExternalIds` (Google/Yelp IDs, phone numbers, website hosts)
- Core attributes: `name`, `address`, `coordinate`, `category`, optional `rating`, `reviewCount`, `imageURL`, `phoneNumber`, `website`
- Verification and engagement metrics: `isVerified`, `likeCount`, `dislikeCount`

**Supporting Schemas**
- `BusinessExternalIds`: arrays of provider IDs and contact fingerprints. Enables resolver lookups and deduplication.
- `BusinessCategory`: static catalog mapping slugs and labels to search keywords for Google Places queries.

**Usage**
- Populated from Google Places results in `BusinessSearchManager`, then normalized via `BusinessResolver` to maintain consistent `womId` assignments.
- Persisted to Firestore `businesses/{womId}` and referenced in user-specific subcollections (`users/{uid}/mySpots`) during onboarding business selection.
- Rendered in detail screens (`BusinessDetailViewModel`) and feeds (home/profile views).

### Business Feedback (`Core/Repositories/BusinessFeedbackRepository.swift`)
**Fields**
- `BusinessFeedbackValue`: enum with `like` / `dislike` sentiment.
- `BusinessFeedbackCounts`: aggregate `likeCount` and `dislikeCount` snapshot returned from transactions.

**Usage**
- `BusinessDetailViewModel` toggles feedback, delegating to `FirestoreBusinessFeedbackRepository` which writes to `users/{uid}/businessFeedback/{businessId}` and updates counters on `businesses/{businessId}`.

### Social Graph (`Models/Friend.swift`)
**Fields**
- `Friend`: `id`/`uid`, `username`, `displayName`, `email`, `profileImageURL`, `dateAdded`
- `FriendRequest`: composite ID `from_to`, source user metadata, `status: FriendRequestStatus`, `createdAt`, `updatedAt`

**Usage**
- `FriendsManager` surfaces search results using `UserProfile`, issues `FriendRequest` records in `friendRequests/{from_to}`, and mirrors accepted relationships into `users/{uid}/friends` collections as `Friend` documents for fast list rendering.
- Accepted friends are promoted to chat participants when creating direct or group chats.

### Messaging (`Models/Chat.swift`, `Models/Message.swift`)
**Fields**
- `ChatType`: `direct` or `group`.
- `ChatParticipant`: per-user metadata (`uid`, `username`, `displayName`, avatars, joined/read timestamps, admin flag).
- `Chat`: chat document with `id`, `type`, optional `name`/`description`/`imageURL`, `participants`, `createdBy`, timestamps, `lastMessage`, `lastActivity`, `isArchived`, `unreadCount` map.
- `Message`: message record with `id`, `chatId`, sender identity fields, `content`, `type`, `timestamp`, delivery `status`, optional `replyToMessageId`, `imageURL`.

**Usage**
- `MessagingManager` listens to `chats` collection filtered by participant UID, hydrates into `Chat`, and syncs `Message` documents from `chats/{chatId}/messages` (real-time listeners, pagination, typing indicators).
- View layer (`ChatView`) binds to these schemas for rendering conversation timelines and metadata.

## External API Models (`Core/Services/BusinessSearchManager.swift`)
- `GooglePlacesNearbyResponse`, `GooglePlaceNearby`, `GoogleGeometry`, `GoogleLocation` capture Google Places nearby search payloads.
- `GooglePlaceDetailsResponse`, `GooglePlaceDetails`, `GoogleOpeningHours`, `GooglePhoto` map detailed place responses for enrichment (addresses, phone numbers, photos).
- `GooglePlacesResponse`, `GooglePlace` maintain compatibility with legacy text search flows.

**Usage**
- Parsed within `BusinessSearchManager` to create `Business` instances and populate resolver caches before persisting to Firestore.

## Firestore Collection Map
- `users/{uid}` → `UserProfile` root document containing onboarding progress, services, and `UserLocation` embeds.
  - `friends/{friendUid}` → `Friend` snapshots for accepted connections.
  - `businessFeedback/{businessId}` → individual `BusinessFeedbackValue` documents per user.
  - `mySpots/{businessId}` → references to curated `Business` records selected during onboarding.
- `friendRequests/{from_to}` → `FriendRequest` workflow records.
- `businesses/{womId}` → canonical `Business` documents with aggregated feedback counts.
- `businessResolvers/{resolverId}` → resolver mappings maintained by `BusinessResolver` for external ID reconciliation.
- `chats/{chatId}` → `Chat` documents, storing participant metadata and unread counters.
  - `messages/{messageId}` → `Message` documents per chat, managed by `MessagingManager` listeners.

## Key Interactions Between Schemas
- Onboarding flow (service selection, business selection, location permissions) feeds `UserProfile`, `Business`, and `UserLocation` data, which later powers search, recommendations, and profile displays.
- Social graph (`Friend`, `FriendRequest`) not only drives friend lists but also seeds `ChatParticipant` arrays when creating direct or group conversations; profile updates propagate through `MessagingManager.syncProfileReferences` to keep chat metadata fresh.
- Business feedback loops couple `BusinessDetailViewModel`, per-user feedback documents, and aggregated counts on the `Business` record to surface community sentiment across the app.
- Business search uses external API schemas to ingest data, normalizes identities through `BusinessExternalIds` and `BusinessResolver`, and stores results for reuse by profile and home experiences.
